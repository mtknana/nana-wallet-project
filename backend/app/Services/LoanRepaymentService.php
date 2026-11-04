<?php

namespace App\Services;

use App\Models\Currency;
use App\Models\Loan;
use App\Models\LoanRepayment;
use App\Models\Transaction;
use App\Models\Wallet;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class LoanRepaymentService
{
    /**
     * Automatically attempt repayment once when each loan reaches its due date.
     */
    public function processDueLoans(): int
    {
        $processed = 0;

        Loan::whereIn('status', ['active', 'partially_paid', 'overdue'])
            ->where('due_at', '<=', now())
            ->whereNull('auto_repayment_attempted_at')
            ->orderBy('id')
            ->select('id')
            ->chunkById(100, function ($loans) use (&$processed) {
                foreach ($loans as $item) {
                    if ($this->processAutomaticRepayment((int) $item->id)) {
                        $processed++;
                    }
                }
            });

        return $processed;
    }

    /**
     * Manually repay a loan at any time, including before or after its due date.
     */
    public function repayManually(
        int $loanId,
        int $userId,
        string|int|float $amount,
        string $requestKey
    ): Loan {
        return DB::transaction(function () use ($loanId, $userId, $amount, $requestKey) {
            $loan = Loan::whereKey($loanId)
                ->where('user_id', $userId)
                ->lockForUpdate()
                ->first();

            if (!$loan) {
                throw ValidationException::withMessages([
                    'loan' => ['Loan not found.'],
                ]);
            }

            $requestKey = trim($requestKey);
            if ($requestKey === '' || strlen($requestKey) > 100) {
                throw ValidationException::withMessages([
                    'idempotency_key' => ['A valid repayment request key is required.'],
                ]);
            }
            $idempotencyKey = $this->manualRepaymentKey($loan->id, $requestKey);
            $priorTransaction = Transaction::where('idempotency_key', $idempotencyKey)->first();
            if ($priorTransaction) {
                $currency = Currency::where('code', $loan->currency)->first();
                $decimals = (int) ($currency?->decimal_places ?? -1);
                $requestedUnits = $decimals >= 0 && $decimals <= 2
                    ? $this->amountToUnits($amount, $decimals)
                    : -1;
                $priorUnits = $decimals >= 0 && $decimals <= 2
                    ? $this->amountToUnits(number_format((float) $priorTransaction->amount, $decimals, '.', ''), $decimals)
                    : -2;
                if (
                    (int) $priorTransaction->user_id !== $userId ||
                    $priorTransaction->type !== 'loan_repayment' ||
                    $priorTransaction->currency !== $loan->currency ||
                    $requestedUnits !== $priorUnits
                ) {
                    throw ValidationException::withMessages([
                        'idempotency_key' => ['This request key was already used for a different repayment.'],
                    ]);
                }
                return $loan->fresh(['repayments']);
            }

            if (!in_array(
                $loan->status,
                ['active', 'partially_paid', 'overdue'],
                true
            )) {
                throw ValidationException::withMessages([
                    'loan' => ['This loan cannot receive further repayments.'],
                ]);
            }

            if ((float) $loan->outstanding_principal <= 0) {
                throw ValidationException::withMessages([
                    'loan' => ['This loan has already been fully repaid.'],
                ]);
            }

            $currency = Currency::where('code', $loan->currency)->first();

            if (!$currency || !$currency->is_active) {
                throw ValidationException::withMessages([
                    'currency' => ['This loan currency is unavailable.'],
                ]);
            }

            $decimals = (int) $currency->decimal_places;
            if ($decimals < 0 || $decimals > 2) {
                throw ValidationException::withMessages([
                    'currency' => ['This currency precision is not supported by the wallet ledger.'],
                ]);
            }
            $factor = 10 ** $decimals;

            $paymentUnits = $this->amountToUnits($amount, $decimals);

            $outstandingUnits = (int) round(
                (float) $loan->outstanding_principal * $factor
            );

            if (
                $paymentUnits <= 0 ||
                $paymentUnits > $outstandingUnits
            ) {
                throw ValidationException::withMessages([
                    'amount' => [
                        'Enter a valid repayment amount not exceeding the outstanding balance.',
                    ],
                ]);
            }

            $this->collectRepayment($loan, $paymentUnits, $factor, $idempotencyKey);

            return $loan->fresh(['repayments']);
        }, 3);
    }

    /**
     * Process the one-time automatic repayment attempt.
     */
    private function processAutomaticRepayment(int $loanId): bool
    {
        return DB::transaction(function () use ($loanId) {
            $loan = Loan::whereKey($loanId)
                ->lockForUpdate()
                ->first();

            if (
                !$loan ||
                !in_array(
                    $loan->status,
                    ['active', 'partially_paid', 'overdue'],
                    true
                ) ||
                $loan->due_at->isFuture() ||
                $loan->auto_repayment_attempted_at !== null
            ) {
                return false;
            }

            $currency = Currency::where('code', $loan->currency)->first();

            $repayment = LoanRepayment::where('loan_id', $loan->id)
                ->lockForUpdate()
                ->first();

            $customerWallet = Wallet::where('user_id', $loan->user_id)
                ->where('currency', $loan->currency)
                ->lockForUpdate()
                ->first();

            $adminWallet = Wallet::where(
                'user_id',
                $loan->funded_by_user_id
            )
                ->where('currency', $loan->currency)
                ->lockForUpdate()
                ->first();

            /*
             * Record one attempt even when a business condition prevents
             * collection. This prevents repeated deductions on later runs.
             */
            $loan->auto_repayment_attempted_at = now();

            if (
                !$currency ||
                !$currency->is_active ||
                !$repayment ||
                !$customerWallet ||
                $customerWallet->status !== 'active' ||
                !$adminWallet ||
                $adminWallet->status !== 'active'
            ) {
                $loan->status = 'overdue';
                $loan->save();

                return true;
            }

            $factor = 10 ** (int) $currency->decimal_places;

            $outstandingUnits = (int) round(
                (float) $loan->outstanding_principal * $factor
            );

            $availableUnits = max(
                0,
                (int) round((float) $customerWallet->balance * $factor)
            );

            $collectedUnits = min(
                $availableUnits,
                $outstandingUnits
            );

            if ($collectedUnits <= 0) {
                $loan->status = 'overdue';
                $loan->save();

                return true;
            }

            /*
             * Save the attempt timestamp together with the repayment.
             * Unexpected database errors roll back both operations.
             */
            $loan->save();

            $this->collectRepayment(
                $loan,
                $collectedUnits,
                $factor
            );

            if ((float) $loan->fresh()->outstanding_principal > 0) {
                $loan->status = 'overdue';
                $loan->save();
            }

            return true;
        }, 3);
    }

    /**
     * Perform the actual wallet transfer and create ledger records.
     * The caller must already hold a lock on the loan.
     */
    private function collectRepayment(
        Loan $loan,
        int $collectedUnits,
        int $factor,
        ?string $manualIdempotencyKey = null
    ): void {
        $repayment = LoanRepayment::where('loan_id', $loan->id)
            ->lockForUpdate()
            ->first();

        if (!$repayment) {
            throw ValidationException::withMessages([
                'repayment' => ['The repayment record could not be found.'],
            ]);
        }

        $customerWallet = Wallet::where('user_id', $loan->user_id)
            ->where('currency', $loan->currency)
            ->lockForUpdate()
            ->first();

        $adminWallet = Wallet::where(
            'user_id',
            $loan->funded_by_user_id
        )
            ->where('currency', $loan->currency)
            ->lockForUpdate()
            ->first();

        if (
            !$customerWallet ||
            $customerWallet->status !== 'active' ||
            !$adminWallet ||
            $adminWallet->status !== 'active'
        ) {
            throw ValidationException::withMessages([
                'wallet' => [
                    'Both borrower and funder wallets must be active.',
                ],
            ]);
        }

        $availableUnits = max(
            0,
            (int) round((float) $customerWallet->balance * $factor)
        );

        $outstandingUnits = (int) round(
            (float) $loan->outstanding_principal * $factor
        );

        if (
            $collectedUnits <= 0 ||
            $collectedUnits > $availableUnits ||
            $collectedUnits > $outstandingUnits
        ) {
            throw ValidationException::withMessages([
                'amount' => [
                    'The repayment amount is no longer available. Please refresh and try again.',
                ],
            ]);
        }

        $remainingUnits = $outstandingUnits - $collectedUnits;

        $collected = $collectedUnits / $factor;

        $remainingAmount = number_format(
            $remainingUnits / $factor,
            (int) round(log10($factor)),
            '.',
            ''
        );

        $adminBalanceUnits = (int) round(
            (float) $adminWallet->balance * $factor
        );

        // Transfer money between the two wallets.
        $customerWallet->setAttribute(
            'balance',
            ($availableUnits - $collectedUnits) / $factor
        );

        $adminWallet->setAttribute(
            'balance',
            ($adminBalanceUnits + $collectedUnits) / $factor
        );

        $customerWallet->save();
        $adminWallet->save();

        // Create borrower transaction.
        $reference = (string) Str::uuid();

        $idempotencyKey = $manualIdempotencyKey
            ?? "loan-{$loan->id}-repayment-{$reference}";

        Transaction::create([
            'user_id' => $loan->user_id,
            'type' => 'loan_repayment',
            'amount' => $collected,
            'fee_charged' => 0,
            'currency' => $loan->currency,
            'description' => "Repayment for NaNa Quick Loan #{$loan->id}",
            'reference_id' => $reference,
            'idempotency_key' => $idempotencyKey,
            'status' => 'completed',
        ]);

        // Create funder transaction.
        Transaction::create([
            'user_id' => $loan->funded_by_user_id,
            'type' => 'loan_repayment_received',
            'amount' => $collected,
            'fee_charged' => 0,
            'currency' => $loan->currency,
            'description' => "Repayment received for loan #{$loan->id}",
            'reference_id' => (string) Str::uuid(),
            'idempotency_key' => "{$idempotencyKey}-received",
            'status' => 'completed',
        ]);

        // Update repayment history.
        $previousCollectedUnits = (int) round(
            (float) $repayment->amount_collected * $factor
        );

        $repayment->setAttribute(
            'amount_collected',
            ($previousCollectedUnits + $collectedUnits) / $factor
        );

        $repayment->setAttribute(
            'remaining_amount',
            $remainingAmount
        );

        $repayment->status = $remainingUnits === 0
            ? 'paid'
            : 'partial';

        $repayment->processed_at = now();
        $repayment->save();

        // Update loan balance and status.
        $loan->setAttribute(
            'outstanding_principal',
            $remainingAmount
        );

        if ($remainingUnits === 0) {
            $loan->status = 'repaid';
            $loan->repaid_at = \Illuminate\Support\Carbon::now();
        } elseif ($loan->auto_repayment_attempted_at !== null) {
            $loan->status = 'overdue';
        } else {
            $loan->status = 'partially_paid';
        }

        $loan->save();
    }

    private function manualRepaymentKey(int $loanId, string $requestKey): string
    {
        return "loan-{$loanId}-manual-" . hash('sha256', $requestKey);
    }

    /** Convert a plain decimal amount to minor units without float rounding. */
    private function amountToUnits(string|int|float $amount, int $decimals): int
    {
        $value = trim((string) $amount);
        if (!preg_match('/^(0|[1-9][0-9]*)(?:\.([0-9]+))?$/', $value, $matches)) {
            throw ValidationException::withMessages([
                'amount' => ['Enter a plain decimal amount using the currency precision.'],
            ]);
        }
        if (strlen($matches[1]) > 13) {
            throw ValidationException::withMessages([
                'amount' => ['The amount exceeds the supported currency range.'],
            ]);
        }
        $fraction = $matches[2] ?? '';
        if (strlen($fraction) > $decimals || $decimals < 0 || $decimals > 2) {
            throw ValidationException::withMessages([
                'amount' => ["This currency accepts up to {$decimals} decimal places."],
            ]);
        }
        $factor = 10 ** $decimals;
        $minor = $decimals === 0 ? 0 : (int) str_pad($fraction, $decimals, '0');
        return ((int) $matches[1] * $factor) + $minor;
    }
}

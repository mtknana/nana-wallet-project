<?php

namespace App\Services;

use App\Models\Currency;
use App\Models\Loan;
use App\Models\LoanRepayment;
use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class LoanService
{
    private const INTEREST_RATE = 5.00;
    private const MAX_USD_EQUIVALENT = 100.00;

    public function apply(User $customer, array $data): Loan
    {
        return DB::transaction(function () use ($customer, $data) {

            $key = $data['idempotency_key'];

            // Return the existing loan if this request was already processed.
            $existing = Loan::where('idempotency_key', $key)->first();

            if ($existing) {
                if ((int) $existing->user_id !== (int) $customer->id) {
                    throw ValidationException::withMessages([
                        'idempotency_key' => 'This request key is already in use.',
                    ]);
                }

                return $existing;
            }

            if ($customer->role === 'admin') {
                throw ValidationException::withMessages([
                    'loan' => 'Administrator accounts cannot apply for customer loans.',
                ]);
            }

            $currency = Currency::where('code', strtoupper($data['currency']))
                ->where('is_active', true)
                ->first();

            if (!$currency || (float) $currency->exchange_rate <= 0) {
                throw ValidationException::withMessages([
                    'currency' => 'This currency is unavailable.',
                ]);
            }

            $code = strtoupper($currency->code);
            $decimals = (int) $currency->decimal_places;
            if ($decimals < 0 || $decimals > 2) {
                throw ValidationException::withMessages([
                    'currency' => 'This currency precision is not supported by the wallet ledger.',
                ]);
            }
            $factor = 10 ** $decimals;
            $principalUnits = $this->amountToUnits($data['amount'], $decimals);
            $principal = $principalUnits / $factor;

            if ($principalUnits <= 0) {
                throw ValidationException::withMessages([
                    'amount' => 'Enter a valid loan amount.',
                ]);
            }

            // Exchange rate means units of this currency per 1 USD.
            $usdEquivalent = $principal / (float) $currency->exchange_rate;

            if ($usdEquivalent > self::MAX_USD_EQUIVALENT) {
                throw ValidationException::withMessages([
                    'amount' => 'The maximum loan is equivalent to $100 USD.',
                ]);
            }

            $termDays = (int) $data['term_days'];

            if (!in_array($termDays, [7, 14, 30], true)) {
                throw ValidationException::withMessages([
                    'term_days' => 'Choose 7, 14, or 30 days.',
                ]);
            }

            $interestUnits = (int) round(
                $principalUnits * self::INTEREST_RATE / 100
            );

            $netUnits = $principalUnits - $interestUnits;

            if ($netUnits <= 0) {
                throw ValidationException::withMessages([
                    'amount' => 'The loan amount is too small after interest.',
                ]);
            }

            $interest = $interestUnits / $factor;
            $disbursed = $netUnits / $factor;

            // Lock the customer's existing active wallet.
            $customerWallet = Wallet::where('user_id', $customer->id)
                ->where('currency', $code)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            if (!$customerWallet) {
                throw ValidationException::withMessages([
                    'wallet' => 'You do not have an active wallet in this currency.',
                ]);
            }

            // Recheck after acquiring the per-customer wallet lock to close the race.
            $existing = Loan::where('idempotency_key', $key)->first();
            if ($existing) {
                if ((int) $existing->user_id !== (int) $customer->id) {
                    throw ValidationException::withMessages([
                        'idempotency_key' => 'This request key is already in use.',
                    ]);
                }
                return $existing;
            }

            // Find an administrator who can fully fund the principal.
            $adminWallet = null;

            $adminIds = User::where('role', 'admin')
                ->orderBy('id')
                ->pluck('id');

            foreach ($adminIds as $adminId) {
                $candidate = Wallet::where('user_id', $adminId)
                    ->where('currency', $code)
                    ->where('status', 'active')
                    ->lockForUpdate()
                    ->first();

                if (
                    $candidate &&
                    (int) round((float) $candidate->balance * $factor)
                    >= $principalUnits
                ) {
                    $adminWallet = $candidate;
                    break;
                }
            }

            if (!$adminWallet) {
                throw ValidationException::withMessages([
                    'loan' => 'There are insufficient administrator funds for this loan.',
                ]);
            }

            // Create the loan record.
            $loan = Loan::create([
                'user_id' => $customer->id,
                'funded_by_user_id' => $adminWallet->user_id,
                'principal' => $principal,
                'interest_rate' => self::INTEREST_RATE,
                'upfront_interest' => $interest,
                'disbursed_amount' => $disbursed,
                'outstanding_principal' => $principal,
                'currency' => $code,
                'term_days' => $termDays,
                'due_at' => now()->addDays($termDays),
                'status' => 'active',
                'idempotency_key' => $key,
                'disbursed_at' => now(),
            ]);

            // Administrator pays the full principal.
            $adminWallet->balance = (
                (int) round((float) $adminWallet->balance * $factor)
                - $principalUnits
            ) / $factor;

            // Customer receives principal minus upfront interest.
            $customerWallet->balance = (
                (int) round((float) $customerWallet->balance * $factor)
                + $netUnits
            ) / $factor;

            // Upfront interest is credited to the administrator.
            $adminWallet->balance = (
                (int) round((float) $adminWallet->balance * $factor)
                + $interestUnits
            ) / $factor;

            $adminWallet->save();
            $customerWallet->save();

            // Record administrator's principal funding.
            Transaction::create([
                'user_id' => $adminWallet->user_id,
                'type' => 'loan_funding',
                'amount' => $principal,
                'fee_charged' => 0,
                'currency' => $code,
                'description' => "Principal funding for loan #{$loan->id}",
                'reference_id' => (string) Str::uuid(),
                'idempotency_key' => "loan-{$loan->id}-funding",
                'status' => 'completed',
            ]);

            // Record customer's net loan disbursement.
            Transaction::create([
                'user_id' => $customer->id,
                'type' => 'loan_disbursement',
                'amount' => $disbursed,
                'fee_charged' => $interest,
                'currency' => $code,
                'description' => "NaNa Quick Loan #{$loan->id} disbursement",
                'reference_id' => (string) Str::uuid(),
                'idempotency_key' => "loan-{$loan->id}-disbursement",
                'status' => 'completed',
            ]);

            // Record the administrator's upfront interest income.
            Transaction::create([
                'user_id' => $adminWallet->user_id,
                'type' => 'loan_interest',
                'amount' => $interest,
                'fee_charged' => 0,
                'currency' => $code,
                'description' => "Upfront interest for loan #{$loan->id}",
                'reference_id' => (string) Str::uuid(),
                'idempotency_key' => "loan-{$loan->id}-interest",
                'status' => 'completed',
            ]);

            // Create the repayment record for the full principal.
            LoanRepayment::create([
                'loan_id' => $loan->id,
                'amount_due' => $principal,
                'amount_collected' => 0,
                'remaining_amount' => $principal,
                'currency' => $code,
                'status' => 'pending',
                'reference_id' => (string) Str::uuid(),
            ]);

            return $loan->fresh(['repayments']);
        });
    }

    /** Convert a decimal amount to minor units without silently rounding. */
    private function amountToUnits(string|int|float $amount, int $decimals): int
    {
        $value = trim((string) $amount);
        if (!preg_match('/^(0|[1-9][0-9]*)(?:\.([0-9]+))?$/', $value, $matches)) {
            throw ValidationException::withMessages([
                'amount' => 'Enter a plain decimal amount using the currency precision.',
            ]);
        }
        if (strlen($matches[1]) > 13) {
            throw ValidationException::withMessages([
                'amount' => ['The amount exceeds the supported currency range.'],
            ]);
        }
        $fraction = $matches[2] ?? '';
        if (strlen($fraction) > $decimals) {
            throw ValidationException::withMessages([
                'amount' => "This currency accepts up to {$decimals} decimal places.",
            ]);
        }
        $factor = 10 ** $decimals;
        $minor = $decimals === 0 ? 0 : (int) str_pad($fraction, $decimals, '0');
        return ((int) $matches[1] * $factor) + $minor;
    }
}
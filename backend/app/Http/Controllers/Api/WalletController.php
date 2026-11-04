<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Wallet;
use App\Models\Currency;
use App\Models\Device;
use App\Models\Transaction;
use App\Models\CalendarEvent;
use App\Models\SystemFeeSetting;
use App\Models\P2pTransfer;
use App\Models\QrPayment;
use App\Models\SplitBill;
use App\Models\SplitBillMember;
use App\Models\ScheduledPayment;
use App\Mail\TransactionReceiptMail;
use App\Models\Merchant;
use App\Services\FraudDetectionService;
use App\Services\SecurityEventLogger;
use App\Services\WalletNotificationService;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;

class WalletController extends Controller
{
    // ============================================================
    // WALLET HELPERS
    // ============================================================

    /**
     * Make sure the user has both USD and KHR wallets.
     */
    private function ensureBothCurrencyWallets(User $user): void
    {
        foreach (['USD', 'KHR'] as $currency) {
            Wallet::firstOrCreate(
                [
                    'user_id' => $user->id,
                    'currency' => $currency,
                ],
                [
                    'balance' => '0.00',
                    'status' => 'active',
                ]
            );
        }
    }

    /**
     * Get a wallet by currency.
     */
    private function getCurrencyWallet(
        User $user,
        string $currency,
        bool $lock = false
    ): ?Wallet {
        $query = Wallet::where(
            'user_id',
            $user->id
        )
            ->where(
                'currency',
                $currency
            );

        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first();
    }

    /**
     * Get or create a currency wallet.
     */
    private function getOrCreateCurrencyWallet(
        User $user,
        string $currency,
        bool $lock = false
    ): Wallet {
        $wallet = $this->getCurrencyWallet(
            $user,
            $currency,
            $lock
        );

        if (!$wallet) {
            $wallet = Wallet::create([
                'user_id' => $user->id,
                'balance' => '0.00',
                'currency' => $currency,
                'status' => 'active',
            ]);

            if ($lock) {
                $wallet = Wallet::whereKey(
                    $wallet->id
                )
                    ->lockForUpdate()
                    ->firstOrFail();
            }
        }

        return $wallet;
    }

    /**
     * Resolve supported wallet currency.
     */
    private function resolveCurrency(
        ?string $currency
    ): string {
        $currency = strtoupper(
            trim((string) $currency)
        );

        return in_array(
            $currency,
            ['USD', 'KHR'],
            true
        )
            ? $currency
            : 'USD';
    }

    /**
     * Convert numeric value to database-safe decimal.
     */
    private function decimal(
        float|int|string $value
    ): string {
        return number_format(
            (float) $value,
            2,
            '.',
            ''
        );
    }

    /**
     * Format money for notification messages.
     */
    private static function formatMoney(
        float $amount,
        string $currency
    ): string {
        $currency = strtoupper(
            $currency
        );

        if ($currency === 'KHR') {
            return '៛' .
                number_format(
                    $amount,
                    0
                );
        }

        return '$' .
            number_format(
                $amount,
                2
            );
    }

    // ============================================================
    // GET BALANCE
    // ============================================================

    public function getBalance(
        Request $request
    ) {
        $user = $request->user();

        $this->ensureBothCurrencyWallets(
            $user
        );

        $wallets = Wallet::where(
            'user_id',
            $user->id
        )
            ->whereIn(
                'currency',
                ['USD', 'KHR']
            )
            ->get();

        return response()->json([
            'status' => 'success',
            'wallets' => $wallets->map(
                function ($wallet) use ($user) {
                    return [
                        'id' =>
                            $wallet->id,

                        'balance' =>
                            (float) $wallet->balance,

                        'currency' =>
                            $wallet->currency,

                        'status' =>
                            $wallet->status,

                        'name' =>
                            $user->name,
                    ];
                }
            ),
        ], 200);
    }

    // ============================================================
    // WITHDRAW
    // US-058: Withdrawal Notifications
    // ============================================================

    public function withdraw(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'amount' =>
                'required|numeric|min:0.01',

            'idempotency_key' =>
                'required|string|max:255',

            'currency' =>
                'nullable|string|in:USD,KHR',
        ]);

        $amount =
            (float) $validated['amount'];

        $currency =
            $this->resolveCurrency(
                $validated['currency']
                ?? 'USD'
            );

        $idempotencyKey =
            $validated['idempotency_key'];

        try {

            $result = DB::transaction(
                function () use ($user, $amount, $currency, $idempotencyKey) {

                    $existingTransaction =
                        Transaction::where(
                            'idempotency_key',
                            $idempotencyKey
                        )->first();

                    if ($existingTransaction) {
                        return [
                            'duplicate' => true,
                            'transaction' =>
                                $existingTransaction,
                        ];
                    }

                    $wallet =
                        $this->getOrCreateCurrencyWallet(
                            $user,
                            $currency,
                            true
                        );

                    $admin =
                        User::where(
                            'role',
                            'admin'
                        )->first();

                    if (!$admin) {
                        throw new \Exception(
                            'Admin account not found.'
                        );
                    }

                    $adminWallet =
                        $this->getOrCreateCurrencyWallet(
                            $admin,
                            $currency,
                            true
                        );

                    $feeSetting =
                        SystemFeeSetting::where(
                            'fee_type',
                            'withdrawal'
                        )->first();

                    $feeRate =
                        $feeSetting
                        ? (float) $feeSetting->fee_rate
                        : 2.00;

                    $fee = round(
                        $amount *
                        ($feeRate / 100),
                        2
                    );

                    $totalDeducted =
                        round(
                            $amount + $fee,
                            2
                        );

                    if (
                        (float) $wallet->balance
                        < $totalDeducted
                    ) {
                        throw new \Exception(
                            'Insufficient balance. You need ' .
                            number_format(
                                $totalDeducted,
                                2
                            ) .
                            ' ' .
                            $currency .
                            ' including the withdrawal fee.'
                        );
                    }

                    $todayWithdrawals =
                        Transaction::where(
                            'user_id',
                            $user->id
                        )
                            ->where(
                                'type',
                                'withdrawal'
                            )
                            ->whereDate(
                                'created_at',
                                today()
                            )
                            ->sum('amount');

                    $dailyLimit =
                        10000.00;

                    if (
                        (
                            (float) $todayWithdrawals
                            + $amount
                        ) > $dailyLimit
                    ) {
                        throw new \Exception(
                            'Daily withdrawal limit exceeded.'
                        );
                    }

                    $wallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $wallet->balance
                            - $totalDeducted
                        )
                    );

                    $wallet->save();

                    $adminWallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $adminWallet->balance
                            + $fee
                        )
                    );

                    $adminWallet->save();

                    $reference =
                        'TXW-' .
                        strtoupper(
                            Str::random(10)
                        );

                    $withdrawalTransaction =
                        Transaction::create([
                            'user_id' =>
                                $user->id,

                            'wallet_id' =>
                                $wallet->id,

                            'type' =>
                                'withdrawal',

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $currency,

                            'fee_charged' =>
                                $this->decimal(
                                    $fee
                                ),

                            'description' =>
                                'Account Liquidity Outflow Cash-out',

                            'reference_id' =>
                                $reference,

                            'status' =>
                                'completed',

                            'idempotency_key' =>
                                $idempotencyKey,
                        ]);

                    Transaction::create([
                        'user_id' =>
                            $admin->id,

                        'wallet_id' =>
                            $adminWallet->id,

                        'type' =>
                            'fee_income',

                        'amount' =>
                            $this->decimal(
                                $fee
                            ),

                        'currency' =>
                            $currency,

                        'fee_charged' =>
                            '0.00',

                        'description' =>
                            'Withdrawal Service Fee Income',

                        'reference_id' =>
                            'FEE-' .
                            strtoupper(
                                Str::random(10)
                            ),

                        'status' =>
                            'completed',
                    ]);

                    return [
                        'duplicate' =>
                            false,

                        'transaction' =>
                            $withdrawalTransaction,

                        'reference' =>
                            $reference,

                        'fee' =>
                            $fee,

                        'total_deducted' =>
                            $totalDeducted,

                        'remaining_balance' =>
                            (float) $wallet->balance,

                        'admin_fee_balance' =>
                            (float) $adminWallet->balance,
                    ];
                }
            );

            if ($result['duplicate']) {
                return response()->json([
                    'status' => 'error',
                    'message' =>
                        'Duplicate withdrawal request.',
                    'transaction' =>
                        $result['transaction'],
                ], 409);
            }

            SecurityEventLogger::log(
                $user,
                'withdrawal_completed',
                'Withdrawal Completed',
                'User completed a ' .
                $currency .
                ' withdrawal of ' .
                number_format(
                    $amount,
                    2
                ) .
                '.',
                'info',
                'Transaction',
                $result['transaction']->id,
                $request
            );

            // --------------------------------------------------------
            // US-058: WITHDRAWAL NOTIFICATION
            // --------------------------------------------------------

            try {
                WalletNotificationService::withdrawal(
                    $user,
                    $amount,
                    $currency,
                    true,
                    $result['fee'],
                    $result['transaction']->id
                );
            } catch (\Throwable $notificationError) {
                // Notification failure must not affect withdrawal.
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Withdrawal completed successfully.',

                'reference' =>
                    $result['reference'],

                'transaction_id' =>
                    $result['transaction']->id,

                'amount' =>
                    $amount,

                'currency' =>
                    $currency,

                'fee' =>
                    $result['fee'],

                'total_deducted' =>
                    $result['total_deducted'],

                'remaining_balance' =>
                    $result['remaining_balance'],

                'admin_fee_balance' =>
                    $result['admin_fee_balance'],
            ], 200);

        } catch (\Throwable $e) {

            SecurityEventLogger::log(
                $user,
                'withdrawal_failed',
                'Withdrawal Failed',
                'A ' .
                $currency .
                ' withdrawal attempt failed.',
                'warning',
                null,
                null,
                $request
            );

            // --------------------------------------------------------
            // US-058: WITHDRAWAL FAILED NOTIFICATION
            // --------------------------------------------------------

            try {
                WalletNotificationService::withdrawal(
                    $user,
                    $amount,
                    $currency,
                    false,
                    null,
                    null
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // TRANSACTION HISTORY
    // ============================================================

    public function getHistory(
        Request $request
    ) {
        $user = $request->user();

        $transactions =
            Transaction::where(
                'user_id',
                $user->id
            )
                ->orderByDesc(
                    'created_at'
                )
                ->get();

        return response()->json([
            'status' =>
                'success',

            'transactions' =>
                $transactions,
        ], 200);
    }

    // ============================================================
    // CALENDAR EVENT
    // ============================================================

    public function createCalendarEvent(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'title' =>
                'required|string|max:255',

            'description' =>
                'nullable|string',

            'event_date' =>
                'required|date',

            'event_type' =>
                'nullable|string|max:100',
        ]);

        $event =
            CalendarEvent::create([
                'user_id' =>
                    $user->id,

                'title' =>
                    $validated['title'],

                'description' =>
                    $validated['description']
                    ?? null,

                'event_date' =>
                    $validated['event_date'],

                'event_type' =>
                    $validated['event_type']
                    ?? null,
            ]);

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Calendar event created successfully.',

            'event' =>
                $event,
        ], 201);
    }

    // ============================================================
    // P2P TRANSFER
    // US-051 Fraud Detection
    // US-058 Unified Wallet Notifications
    // ============================================================

    public function transferP2p(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'receiver_email' =>
                'nullable|email|required_without:receiver_user_id',

            'receiver_user_id' =>
                'nullable|integer|exists:users,id|required_without:receiver_email',

            'amount' =>
                'required|numeric|min:0.01',

            'currency' =>
                'required|string|in:USD,KHR',

            'idempotency_key' =>
                'required|string|max:255',

            'description' =>
                'nullable|string|max:255',
        ]);

        $amount =
            (float) $validated['amount'];

        $currency =
            strtoupper(
                $validated['currency']
            );

        $idempotencyKey =
            $validated['idempotency_key'];

        $receiverEmail =
            $validated['receiver_email'] ?? null;

        $receiverUserId =
            $validated['receiver_user_id'] ?? null;

        $receiverLabel =
            $receiverEmail ?? ('account ' . $receiverUserId);

        $description =
            $validated['description']
            ?? null;

        // ------------------------------------------------------------
        // US-051: FRAUD DETECTION
        // ------------------------------------------------------------

        try {

            $existingTransaction =
                Transaction::where(
                    'idempotency_key',
                    $idempotencyKey
                )->first();

            if ($existingTransaction) {
                return response()->json([
                    'status' =>
                        'error',

                    'message' =>
                        'Duplicate transfer request.',

                    'transaction' =>
                        $existingTransaction,
                ], 409);
            }

            $fraudCheck =
                FraudDetectionService::checkTransaction(
                    $user,
                    $amount,
                    $currency,
                    'transfer',
                    $request
                );

            if ($fraudCheck['detected']) {

                FraudDetectionService::logFraudDetection(
                    $user,
                    $amount,
                    $currency,
                    'transfer',
                    $fraudCheck['reasons'],
                    $request
                );

                try {
                    WalletNotificationService::security(
                        $user,
                        'Suspicious Transfer Detected',
                        'Your ' .
                        $currency .
                        ' transfer of ' .
                        number_format(
                            $amount,
                            2
                        ) .
                        ' was flagged for security review.',
                        'danger'
                    );
                } catch (\Throwable $notificationError) {
                    // Ignore notification failure.
                }

                return response()->json([
                    'status' =>
                        'fraud_detected',

                    'message' =>
                        'This transaction was flagged for security review.',

                    'reasons' =>
                        $fraudCheck['reasons'],
                ], 403);
            }

        } catch (\Throwable $e) {

            SecurityEventLogger::log(
                $user,
                'fraud_detection_failed',
                'Fraud Detection Check Failed',
                'The fraud detection check could not be completed before the P2P transfer.',
                'warning',
                null,
                null,
                $request
            );

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    'Security verification could not be completed. Please try again.',
            ], 500);
        }

        // ------------------------------------------------------------
        // COMPLETE P2P TRANSFER
        // ------------------------------------------------------------

        try {

            $result = DB::transaction(
                function () use ($user, $amount, $currency, $idempotencyKey, $receiverEmail, $receiverUserId, $description) {

                    $existingTransaction =
                        Transaction::where(
                            'idempotency_key',
                            $idempotencyKey
                        )->first();

                    if ($existingTransaction) {
                        return [
                            'duplicate' =>
                                true,

                            'transaction' =>
                                $existingTransaction,
                        ];
                    }

                    $receiver = $receiverUserId !== null
                        ? User::find($receiverUserId)
                        : User::where('email', $receiverEmail)->first();

                    if (!$receiver) {
                        throw new \Exception(
                            'Receiver account not found.'
                        );
                    }

                    if (
                        $receiver->id ===
                        $user->id
                    ) {
                        throw new \Exception(
                            'You cannot transfer money to yourself.'
                        );
                    }

                    $admin =
                        User::where(
                            'role',
                            'admin'
                        )->first();

                    if (!$admin) {
                        throw new \Exception(
                            'Admin account not found.'
                        );
                    }

                    $senderWallet =
                        $this->getOrCreateCurrencyWallet(
                            $user,
                            $currency,
                            true
                        );

                    $receiverWallet =
                        $this->getOrCreateCurrencyWallet(
                            $receiver,
                            $currency,
                            true
                        );

                    $adminWallet =
                        $this->getOrCreateCurrencyWallet(
                            $admin,
                            $currency,
                            true
                        );

                    $feeSetting = SystemFeeSetting::where(
                        'transaction_type',
                        'p2p'
                    )->first();

                    $feeRate =
                        $feeSetting
                        ? (float) $feeSetting->fee_rate
                        : 1.50;

                    $fee =
                        round(
                            $amount *
                            ($feeRate / 100),
                            2
                        );

                    $totalDebit =
                        round(
                            $amount + $fee,
                            2
                        );

                    if (
                        (float) $senderWallet->balance
                        < $totalDebit
                    ) {
                        throw new \Exception(
                            'Insufficient balance for this transfer including the service fee.'
                        );
                    }

                    $senderWallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $senderWallet->balance
                            - $totalDebit
                        )
                    );

                    $senderWallet->save();

                    $receiverWallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $receiverWallet->balance
                            + $amount
                        )
                    );

                    $receiverWallet->save();

                    $adminWallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $adminWallet->balance
                            + $fee
                        )
                    );

                    $adminWallet->save();

                    $p2pReference =
                        'P2P-' .
                        strtoupper(
                            Str::random(10)
                        );

                    $p2pTransfer =
                        P2pTransfer::create([
                            'sender_id' =>
                                $user->id,

                            'receiver_id' =>
                                $receiver->id,

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $currency,

                            'fee_applied' =>
                                $this->decimal(
                                    $fee
                                ),

                            'reference_id' =>
                                $p2pReference,

                            'description' =>
                                $description,

                            'status' =>
                                'completed',

                            'idempotency_key' =>
                                $idempotencyKey,
                        ]);

                    $senderTransaction =
                        Transaction::create([
                            'user_id' =>
                                $user->id,

                            'wallet_id' =>
                                $senderWallet->id,

                            'type' =>
                                'withdrawal',

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $currency,

                            'fee_charged' =>
                                $this->decimal(
                                    $fee
                                ),

                            'description' =>
                                $description ??
                                'P2P Transfer to ' .
                                $receiver->email,

                            'reference_id' =>
                                $p2pReference,

                            'status' =>
                                'completed',

                            'idempotency_key' =>
                                $idempotencyKey,
                        ]);

                    $receiverTransaction =
                        Transaction::create([
                            'user_id' =>
                                $receiver->id,

                            'wallet_id' =>
                                $receiverWallet->id,

                            'type' =>
                                'deposit',

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $currency,

                            'fee_charged' =>
                                '0.00',

                            'description' =>
                                $description ??
                                'P2P Transfer from ' .
                                $user->email,

                            'reference_id' =>
                                'P2P-RCV-' .
                                strtoupper(
                                    Str::random(10)
                                ),

                            'status' =>
                                'completed',
                        ]);

                    Transaction::create([
                        'user_id' =>
                            $admin->id,

                        'wallet_id' =>
                            $adminWallet->id,

                        'type' =>
                            'fee_income',

                        'amount' =>
                            $this->decimal(
                                $fee
                            ),

                        'currency' =>
                            $currency,

                        'fee_charged' =>
                            '0.00',

                        'description' =>
                            'P2P Transfer Service Fee Income',

                        'reference_id' =>
                            'FEE-' .
                            strtoupper(
                                Str::random(10)
                            ),

                        'status' =>
                            'completed',
                    ]);

                    return [
                        'duplicate' =>
                            false,

                        'p2p_transfer' =>
                            $p2pTransfer,

                        'transaction' =>
                            $senderTransaction,

                        'receiver_transaction' =>
                            $receiverTransaction,

                        'receiver' =>
                            $receiver,

                        'reference' =>
                            $p2pReference,

                        'fee' =>
                            $fee,

                        'total_debit' =>
                            $totalDebit,

                        'remaining_balance' =>
                            (float) $senderWallet->balance,
                    ];
                }
            );

            if ($result['duplicate']) {
                return response()->json([
                    'status' =>
                        'error',

                    'message' =>
                        'Duplicate transfer request.',

                    'transaction' =>
                        $result['transaction'],
                ], 409);
            }

            SecurityEventLogger::log(
                $user,
                'p2p_transfer_completed',
                'P2P Transfer Completed',
                'User sent ' .
                number_format(
                    $amount,
                    2
                ) .
                ' ' .
                $currency .
                ' to ' .
                $result['receiver']->email .
                '.',
                'info',
                'Transaction',
                $result['transaction']->id,
                $request
            );

            // --------------------------------------------------------
            // US-058: SENDER NOTIFICATION
            // --------------------------------------------------------

            try {
                WalletNotificationService::moneySent(
                    $user,
                    $amount,
                    $currency,
                    $result['receiver']->email,
                    $result['p2p_transfer']->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            // --------------------------------------------------------
            // US-058: RECEIVER NOTIFICATION
            // --------------------------------------------------------

            try {
                WalletNotificationService::moneyReceived(
                    $result['receiver'],
                    $amount,
                    $currency,
                    $user->email,
                    $result['p2p_transfer']->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            // --------------------------------------------------------
            // US-058: SERVICE FEE NOTIFICATION
            // --------------------------------------------------------

            if ($result['fee'] > 0) {
                try {
                    WalletNotificationService::transaction(
                        $user,
                        'Transfer Service Fee',
                        'A service fee of ' .
                        self::formatMoney(
                            $result['fee'],
                            $currency
                        ) .
                        ' was charged for your P2P transfer.',
                        'info',
                        $result['fee'],
                        $currency,
                        $result['p2p_transfer']->id
                    );
                } catch (\Throwable $notificationError) {
                    // Ignore notification failure.
                }
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Transfer completed successfully.',

                'reference' =>
                    $result['reference'],

                'transaction_id' =>
                    $result['transaction']->id,

                'amount' =>
                    $amount,

                'currency' =>
                    $currency,

                'fee' =>
                    $result['fee'],

                'total_debit' =>
                    $result['total_debit'],

                'remaining_balance' =>
                    $result['remaining_balance'],
            ], 200);

        } catch (\Throwable $e) {

            // --------------------------------------------------------
            // US-058: TRANSFER FAILED NOTIFICATION
            // --------------------------------------------------------

            try {
                WalletNotificationService::transaction(
                    $user,
                    'Transfer Failed',
                    'Your transfer of ' .
                    self::formatMoney(
                        $amount,
                        $currency
                    ) .
                    ' to ' .
                    $receiverLabel .
                    ' could not be completed.',
                    'danger',
                    $amount,
                    $currency
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            SecurityEventLogger::log(
                $user,
                'p2p_transfer_failed',
                'P2P Transfer Failed',
                'A P2P transfer attempt failed.',
                'warning',
                null,
                null,
                $request
            );

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // TRANSFER BETWEEN USD / KHR
    // US-058: Currency Conversion Notification
    // ============================================================

    public function transferBetweenWallets(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'from_currency' =>
                'required|string|in:USD,KHR',

            'to_currency' =>
                'required|string|in:USD,KHR',

            'amount' =>
                'required|numeric|min:0.01',

            'idempotency_key' =>
                'required|string|max:255',
        ]);

        $fromCurrency =
            strtoupper(
                $validated['from_currency']
            );

        $toCurrency =
            strtoupper(
                $validated['to_currency']
            );

        $amount =
            (float) $validated['amount'];

        $idempotencyKey =
            $validated['idempotency_key'];

        if (
            $fromCurrency ===
            $toCurrency
        ) {
            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    'Source and destination currencies must be different.',
            ], 422);
        }

        try {

            $result = DB::transaction(
                function () use ($user, $fromCurrency, $toCurrency, $amount, $idempotencyKey) {

                    $existingTransaction =
                        Transaction::where(
                            'idempotency_key',
                            $idempotencyKey
                        )->first();

                    if ($existingTransaction) {
                        return [
                            'duplicate' =>
                                true,

                            'transaction' =>
                                $existingTransaction,
                        ];
                    }

                    $exchangeRate =
                        4050.00;

                    if (
                        $fromCurrency ===
                        'USD'
                    ) {
                        $convertedAmount =
                            round(
                                $amount *
                                $exchangeRate,
                                2
                            );
                    } else {
                        $convertedAmount =
                            round(
                                $amount /
                                $exchangeRate,
                                2
                            );
                    }

                    $sourceWallet =
                        $this->getOrCreateCurrencyWallet(
                            $user,
                            $fromCurrency,
                            true
                        );

                    $destinationWallet =
                        $this->getOrCreateCurrencyWallet(
                            $user,
                            $toCurrency,
                            true
                        );

                    if (
                        (float) $sourceWallet->balance
                        < $amount
                    ) {
                        throw new \Exception(
                            'Insufficient balance.'
                        );
                    }

                    $sourceWallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $sourceWallet->balance
                            - $amount
                        )
                    );

                    $sourceWallet->save();

                    $destinationWallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $destinationWallet->balance
                            + $convertedAmount
                        )
                    );

                    $destinationWallet->save();

                    $reference =
                        'WLT-' .
                        strtoupper(
                            Str::random(10)
                        );

                    $transferOut =
                        Transaction::create([
                            'user_id' =>
                                $user->id,

                            'wallet_id' =>
                                $sourceWallet->id,

                            'type' =>
                                'transfer_out',

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $fromCurrency,

                            'fee_charged' =>
                                '0.00',

                            'description' =>
                                'Wallet Currency Conversion',

                            'reference_id' =>
                                $reference,

                            'status' =>
                                'completed',

                            'idempotency_key' =>
                                $idempotencyKey,
                        ]);

                    // IMPORTANT:
                    // transactions.reference_id is UNIQUE.
                    // The transfer-out transaction keeps the main
                    // WLT reference, while the transfer-in transaction
                    // receives its own unique reference.
                    Transaction::create([
                        'user_id' =>
                            $user->id,

                        'wallet_id' =>
                            $destinationWallet->id,

                        'type' =>
                            'transfer_in',

                        'amount' =>
                            $this->decimal(
                                $convertedAmount
                            ),

                        'currency' =>
                            $toCurrency,

                        'fee_charged' =>
                            '0.00',

                        'description' =>
                            'Wallet Currency Conversion',

                        'reference_id' =>
                            'WLT-IN-' .
                            strtoupper(
                                Str::random(10)
                            ),

                        'status' =>
                            'completed',
                    ]);

                    return [
                        'duplicate' =>
                            false,

                        'transaction' =>
                            $transferOut,

                        'reference' =>
                            $reference,

                        'converted_amount' =>
                            $convertedAmount,

                        'exchange_rate' =>
                            $exchangeRate,

                        'remaining_balance' =>
                            (float) $sourceWallet->balance,
                    ];
                }
            );

            if ($result['duplicate']) {
                return response()->json([
                    'status' =>
                        'error',

                    'message' =>
                        'Duplicate wallet transfer request.',

                    'transaction' =>
                        $result['transaction'],
                ], 409);
            }

            SecurityEventLogger::log(
                $user,
                'wallet_transfer_completed',
                'Currency Transfer Completed',
                'User converted ' .
                number_format(
                    $amount,
                    2
                ) .
                ' ' .
                $fromCurrency .
                ' to ' .
                number_format(
                    $result['converted_amount'],
                    2
                ) .
                ' ' .
                $toCurrency .
                '.',
                'info',
                'Transaction',
                $result['transaction']->id,
                $request
            );

            // --------------------------------------------------------
            // US-058: CURRENCY CONVERSION NOTIFICATION
            // --------------------------------------------------------

            try {
                WalletNotificationService::transaction(
                    $user,
                    'Currency Conversion Completed',
                    'You converted ' .
                    self::formatMoney(
                        $amount,
                        $fromCurrency
                    ) .
                    ' to ' .
                    self::formatMoney(
                        $result['converted_amount'],
                        $toCurrency
                    ) .
                    ' at the exchange rate of 1 USD = 4,050 KHR.',
                    'success',
                    $result['converted_amount'],
                    $toCurrency,
                    $result['transaction']->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Wallet transfer completed successfully.',

                'reference' =>
                    $result['reference'],

                'transaction_id' =>
                    $result['transaction']->id,

                'from_currency' =>
                    $fromCurrency,

                'to_currency' =>
                    $toCurrency,

                'amount' =>
                    $amount,

                'converted_amount' =>
                    $result['converted_amount'],

                'exchange_rate' =>
                    $result['exchange_rate'],

                'remaining_balance' =>
                    $result['remaining_balance'],
            ], 200);

        } catch (\Throwable $e) {

            SecurityEventLogger::log(
                $user,
                'wallet_transfer_failed',
                'Currency Transfer Failed',
                'A wallet currency transfer attempt failed.',
                'warning',
                null,
                null,
                $request
            );

            try {
                WalletNotificationService::transaction(
                    $user,
                    'Currency Conversion Failed',
                    'Your conversion of ' .
                    self::formatMoney(
                        $amount,
                        $fromCurrency
                    ) .
                    ' to ' .
                    $toCurrency .
                    ' could not be completed.',
                    'danger',
                    $amount,
                    $fromCurrency
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // QR PAYMENT
    // US-058: QR Payment Notifications
    // ============================================================

    public function payMerchantQr(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'merchant_id' =>
                'required',

            'amount' =>
                'required|numeric|min:0.01',

            'currency' =>
                'required|string|in:USD,KHR',

            'idempotency_key' =>
                'required|string|max:255',

            'qr_payload' =>
                'nullable|string',
        ]);

        $amount =
            (float) $validated['amount'];

        $currency =
            strtoupper(
                $validated['currency']
            );

        try {

            $result = DB::transaction(
                function () use ($user, $validated, $amount, $currency) {

                    $existingTransaction =
                        Transaction::where(
                            'idempotency_key',
                            $validated['idempotency_key']
                        )->first();

                    if ($existingTransaction) {
                        return [
                            'duplicate' =>
                                true,

                            'transaction' =>
                                $existingTransaction,
                        ];
                    }

                    $wallet =
                        $this->getOrCreateCurrencyWallet(
                            $user,
                            $currency,
                            true
                        );

                    if (
                        (float) $wallet->balance
                        < $amount
                    ) {
                        throw new \Exception(
                            'Insufficient balance.'
                        );
                    }

                    $wallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $wallet->balance
                            - $amount
                        )
                    );

                    $wallet->save();

                    $reference =
                        'QRP-' .
                        strtoupper(
                            Str::random(10)
                        );

                    $qrPayment =
                        QrPayment::create([
                            'user_id' =>
                                $user->id,

                            'merchant_id' =>
                                $validated['merchant_id'],

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $currency,

                            'reference' =>
                                $reference,

                            'qr_payload' =>
                                $validated['qr_payload']
                                ?? null,

                            'status' =>
                                'completed',

                            'idempotency_key' =>
                                $validated['idempotency_key'],
                        ]);

                    $transaction =
                        Transaction::create([
                            'user_id' =>
                                $user->id,

                            'wallet_id' =>
                                $wallet->id,

                            'type' =>
                                'payment',

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $currency,

                            'fee_charged' =>
                                '0.00',

                            'description' =>
                                'QR Merchant Payment',

                            'reference_id' =>
                                $reference,

                            'status' =>
                                'completed',

                            'idempotency_key' =>
                                $validated['idempotency_key'],
                        ]);

                    return [
                        'duplicate' =>
                            false,

                        'qr_payment' =>
                            $qrPayment,

                        'transaction' =>
                            $transaction,

                        'reference' =>
                            $reference,

                        'remaining_balance' =>
                            (float) $wallet->balance,
                    ];
                }
            );

            if ($result['duplicate']) {
                return response()->json([
                    'status' =>
                        'error',

                    'message' =>
                        'Duplicate QR payment request.',

                    'transaction' =>
                        $result['transaction'],
                ], 409);
            }

            SecurityEventLogger::log(
                $user,
                'qr_payment_completed',
                'QR Payment Completed',
                'User completed a QR payment of ' .
                number_format(
                    $amount,
                    2
                ) .
                ' ' .
                $currency .
                '.',
                'info',
                'QrPayment',
                $result['qr_payment']->id,
                $request
            );

            try {
                $merchant =
                    Merchant::find(
                        $validated['merchant_id']
                    );

                WalletNotificationService::qrPayment(
                    $user,
                    $amount,
                    $currency,
                    true,
                    $merchant?->merchant_name,
                    $result['transaction']->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'QR payment completed successfully.',

                'reference' =>
                    $result['reference'],

                'transaction_id' =>
                    $result['transaction']->id,

                'qr_payment_id' =>
                    $result['qr_payment']->id,

                'amount' =>
                    $amount,

                'currency' =>
                    $currency,

                'remaining_balance' =>
                    $result['remaining_balance'],
            ], 200);

        } catch (\Throwable $e) {

            SecurityEventLogger::log(
                $user,
                'qr_payment_failed',
                'QR Payment Failed',
                'A QR payment attempt failed.',
                'warning',
                null,
                null,
                $request
            );

            try {
                WalletNotificationService::qrPayment(
                    $user,
                    $amount,
                    $currency,
                    false,
                    null,
                    null
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // SPLIT BILL
    // US-058: Split Bill Notifications
    // ============================================================

    public function createSplitBill(
        Request $request
    ) {
        $user = $request->user();

        $membersInput = $request->input('members');
        if (is_array($membersInput)) {
            foreach ($membersInput as $index => $member) {
                if (is_array($member) && isset($member['email']) && is_string($member['email'])) {
                    $membersInput[$index]['email'] = Str::lower(trim($member['email']));
                }
            }
            $request->merge(['members' => $membersInput]);
        }

        $validated = $request->validate([
            'title' =>
                'required|string|max:255',

            'total_amount' =>
                'required|numeric|min:0.01',

            'currency' =>
                'nullable|string|in:USD,KHR',

            'members' =>
                'required|array|min:1',

            'members.*.email' =>
                'required|email|distinct',
        ]);

        $currency = strtoupper($validated['currency'] ?? 'USD');
        $memberEmails = collect($validated['members'])
            ->pluck('email')
            ->values()
            ->all();

        $membersByEmail = User::query()
            ->where(function ($query) use ($memberEmails): void {
                foreach ($memberEmails as $email) {
                    $query->orWhereRaw('LOWER(email) = ?', [$email]);
                }
            })
            ->get()
            ->keyBy(static fn (User $member): string => Str::lower($member->email));

        $missingEmails = array_values(array_filter(
            $memberEmails,
            static fn (string $email): bool => !$membersByEmail->has($email)
        ));

        if ($missingEmails !== []) {
            throw ValidationException::withMessages([
                'members' => [
                    'No NaNa Wallet account was found for: ' . implode(', ', $missingEmails),
                ],
            ]);
        }

        $members = collect($memberEmails)
            ->map(static fn (string $email): User => $membersByEmail->get($email))
            ->values();

        if ($members->contains(static fn (User $member): bool => (int) $member->id === (int) $user->id)) {
            throw ValidationException::withMessages([
                'members' => ['Do not add your own email; the creator share is included automatically.'],
            ]);
        }

        $currencySettings = Currency::query()->where('code', $currency)->first();
        $decimalPlaces = (int) ($currencySettings?->decimal_places ?? ($currency === 'KHR' ? 0 : 2));
        $factor = 10 ** $decimalPlaces;
        $totalScaled = (float) $validated['total_amount'] * $factor;
        $totalMinor = (int) round($totalScaled);

        if (abs($totalScaled - $totalMinor) > 0.00001) {
            throw ValidationException::withMessages([
                'total_amount' => ["The amount supports at most {$decimalPlaces} decimal places for {$currency}."],
            ]);
        }

        $participantCount = $members->count() + 1;
        if ($totalMinor < $participantCount) {
            throw ValidationException::withMessages([
                'total_amount' => ['The total must cover at least one smallest currency unit per participant, including you.'],
            ]);
        }

        $memberShare = number_format(
            intdiv($totalMinor, $participantCount) / $factor,
            $decimalPlaces,
            '.',
            ''
        );
        $totalAmount = number_format($totalMinor / $factor, $decimalPlaces, '.', '');

        try {

            $created = DB::transaction(function () use ($user, $validated, $currency, $totalAmount, $memberShare, $members): array {
                $splitBill = SplitBill::create([
                    'creator_id' => $user->id,
                    'title' => $validated['title'],
                    'total_amount' => $totalAmount,
                    'currency' => $currency,
                    'status' => 'pending',
                ]);

                $memberNotifications = [];
                foreach ($members as $memberUser) {
                    SplitBillMember::create([
                        'split_bill_id' => $splitBill->id,
                        'user_id' => $memberUser->id,
                        'owed_amount' => $memberShare,
                        'is_paid' => false,
                    ]);
                    $memberNotifications[] = [
                        'user' => $memberUser,
                        'amount' => $memberShare,
                    ];
                }

                return [
                    'split_bill' => $splitBill,
                    'members' => $memberNotifications,
                ];
            });
            $splitBill = $created['split_bill'];

            SecurityEventLogger::log(
                $user,
                'split_bill_created',
                'Split Bill Created',
                'A split bill named "' .
                $splitBill->title .
                '" was created.',
                'info',
                'SplitBill',
                $splitBill->id,
                $request
            );

            // Creator notification
            try {
                WalletNotificationService::splitBill(
                    $user,
                    'Split Bill Created',
                    'Your split bill "' .
                    $splitBill->title .
                    '" has been created successfully.',
                    'info',
                    (float) $splitBill->total_amount,
                    $splitBill->currency,
                    $splitBill->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            // Notify split-bill members
            foreach (
                $created['members']
                as $member
            ) {
                try {
                    $memberUser = $member['user'];
                    $memberAmount = (float) $member['amount'];

                    if ($memberUser) {
                        WalletNotificationService::splitBill(
                            $memberUser,
                            'Split Bill Request',
                            'You have been added to the split bill "' .
                            $splitBill->title .
                            '". Your contribution is ' .
                            self::formatMoney(
                                $memberAmount,
                                $splitBill->currency
                            ) .
                            '.',
                            'warning',
                            $memberAmount,
                            $splitBill->currency,
                            $splitBill->id
                        );
                    }
                } catch (\Throwable $notificationError) {
                    // Ignore individual member notification failure.
                }
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Split bill created successfully.',

                'split_bill' =>
                    $splitBill,
            ], 201);

        } catch (\Throwable $e) {

            SecurityEventLogger::log(
                $user,
                'split_bill_failed',
                'Split Bill Failed',
                'A split bill creation attempt failed.',
                'warning',
                null,
                null,
                $request
            );

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // GET ACTIVE MERCHANTS
    // ============================================================

    public function getMerchants(
        Request $request
    ) {
        $validated = $request->validate([
            'category' =>
                'nullable|string|in:water,electricity,mobile,internet,education,government,retail,food,other',
        ]);

        $query =
            Merchant::query()
                ->where(
                    'is_active',
                    true
                )
                ->orderBy(
                    'merchant_name'
                );

        if (
            !empty(
            $validated['category']
        )
        ) {
            $query->where(
                'category',
                $validated['category']
            );
        }

        $merchants =
            $query->get([
                'id',
                'merchant_name',
                'merchant_code',
                'category',
                'email',
                'phone',
                'description',
                'is_active',
            ]);

        return response()->json([
            'status' =>
                'success',

            'merchants' =>
                $merchants,
        ], 200);
    }

    // ============================================================
    // UTILITY BILL PAYMENT
    // US-058: Bill Payment Notifications
    // ============================================================

    public function payUtilityBill(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'merchant_id' =>
                'required|integer|exists:merchants,id',

            'consumer_number' =>
                'required|string|max:255',

            'amount' =>
                'required|numeric|min:0.01',

            'idempotency_key' =>
                'required|string|max:255',

            'currency' =>
                'required|string|in:USD,KHR',
        ]);

        $amount =
            (float) $validated['amount'];

        $currency =
            strtoupper(
                $validated['currency']
            );

        $merchantId =
            (int) $validated['merchant_id'];

        try {

            $result = DB::transaction(
                function () use ($user, $validated, $amount, $currency, $merchantId) {

                    $existingTransaction =
                        Transaction::where(
                            'idempotency_key',
                            $validated['idempotency_key']
                        )->first();

                    if ($existingTransaction) {
                        return [
                            'duplicate' =>
                                true,

                            'transaction' =>
                                $existingTransaction,
                        ];
                    }

                    $merchant =
                        Merchant::where(
                            'id',
                            $merchantId
                        )
                            ->where(
                                'is_active',
                                true
                            )
                            ->first();

                    if (!$merchant) {
                        throw new \Exception(
                            'Merchant is not available.'
                        );
                    }

                    $wallet =
                        $this->getOrCreateCurrencyWallet(
                            $user,
                            $currency,
                            true
                        );

                    if (
                        strtolower(
                            (string) $wallet->status
                        ) !== 'active'
                    ) {
                        throw new \Exception(
                            'Your wallet is not active.'
                        );
                    }

                    if (
                        (float) $wallet->balance
                        < $amount
                    ) {
                        throw new \Exception(
                            'Insufficient balance.'
                        );
                    }

                    $merchantWallet =
                        $merchant->wallets()
                            ->where(
                                'currency',
                                $currency
                            )
                            ->where(
                                'status',
                                'active'
                            )
                            ->lockForUpdate()
                            ->first();

                    if (!$merchantWallet) {
                        throw new \Exception(
                            'Merchant wallet for ' .
                            $currency .
                            ' is not available.'
                        );
                    }

                    $wallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $wallet->balance
                            - $amount
                        )
                    );

                    $wallet->save();

                    $merchantWallet->balance = self::decimal(
                        (float) $merchantWallet->balance + $amount
                    );

                    $merchantWallet->save();

                    $reference =
                        'BIL-' .
                        strtoupper(
                            Str::random(10)
                        );

                    $transaction =
                        Transaction::create([
                            'user_id' =>
                                $user->id,

                            'wallet_id' =>
                                $wallet->id,

                            'type' =>
                                'bill_payment',

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $currency,

                            'fee_charged' =>
                                '0.00',

                            'description' =>
                                'Bill Payment - ' .
                                $merchant->merchant_name .
                                ' / ' .
                                $validated[
                                    'consumer_number'
                                ],

                            'reference_id' =>
                                $reference,

                            'status' =>
                                'completed',

                            'idempotency_key' =>
                                $validated[
                                    'idempotency_key'
                                ],
                        ]);

                    return [
                        'duplicate' =>
                            false,

                        'transaction' =>
                            $transaction,

                        'reference' =>
                            $reference,

                        'merchant' =>
                            $merchant,

                        'remaining_balance' =>
                            (float) $wallet->balance,

                        'merchant_balance' =>
                            (float) $merchantWallet->balance,
                    ];
                }
            );

            if ($result['duplicate']) {
                return response()->json([
                    'status' =>
                        'error',

                    'message' =>
                        'Duplicate bill payment request.',

                    'transaction' =>
                        $result['transaction'],
                ], 409);
            }

            SecurityEventLogger::log(
                $user,
                'bill_payment_completed',
                'Bill Payment Completed',
                'User paid ' .
                number_format(
                    $amount,
                    2
                ) .
                ' ' .
                $currency .
                ' to ' .
                $result['merchant']->merchant_name .
                '.',
                'info',
                'Transaction',
                $result['transaction']->id,
                $request
            );

            try {
                WalletNotificationService::billPayment(
                    $user,
                    $amount,
                    $currency,
                    true,
                    $result['merchant']->merchant_name,
                    $result['transaction']->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Bill payment completed successfully.',

                'reference' =>
                    $result['reference'],

                'transaction_id' =>
                    $result['transaction']->id,

                'merchant_id' =>
                    $result['merchant']->id,

                'merchant_name' =>
                    $result['merchant']->merchant_name,

                'merchant_code' =>
                    $result['merchant']->merchant_code,

                'category' =>
                    $result['merchant']->category,

                'consumer_number' =>
                    $validated['consumer_number'],

                'amount' =>
                    $amount,

                'currency' =>
                    $currency,

                'remaining_balance' =>
                    $result['remaining_balance'],

                'merchant_balance' =>
                    $result['merchant_balance'],
            ], 200);

        } catch (\Throwable $e) {

            SecurityEventLogger::log(
                $user,
                'bill_payment_failed',
                'Bill Payment Failed',
                'A bill payment attempt failed.',
                'warning',
                null,
                null,
                $request
            );

            try {
                WalletNotificationService::billPayment(
                    $user,
                    $amount,
                    $currency,
                    false,
                    null,
                    null
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // MOBILE TOP-UP
    // US-058: Mobile Top-up Notifications
    // ============================================================

    public function mobileTopUp(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'phone' =>
                'required|string|max:30',

            'amount' =>
                'required|numeric|in:1,2,5,10,20',

            'idempotency_key' =>
                'required|string|max:255',

            'currency' =>
                'required|string|in:USD,KHR',
        ]);

        $amount =
            (float) $validated['amount'];

        $currency =
            strtoupper(
                $validated['currency']
            );

        try {

            $result = DB::transaction(
                function () use ($user, $validated, $amount, $currency) {

                    $existingTransaction =
                        Transaction::where(
                            'idempotency_key',
                            $validated['idempotency_key']
                        )->first();

                    if ($existingTransaction) {
                        return [
                            'duplicate' =>
                                true,

                            'transaction' =>
                                $existingTransaction,
                        ];
                    }

                    $wallet =
                        $this->getOrCreateCurrencyWallet(
                            $user,
                            $currency,
                            true
                        );

                    if (
                        (float) $wallet->balance
                        < $amount
                    ) {
                        throw new \Exception(
                            'Insufficient balance.'
                        );
                    }

                    $wallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $wallet->balance
                            - $amount
                        )
                    );

                    $wallet->save();

                    $reference =
                        'TOP-' .
                        strtoupper(
                            Str::random(10)
                        );

                    $transaction =
                        Transaction::create([
                            'user_id' =>
                                $user->id,

                            'wallet_id' =>
                                $wallet->id,

                            'type' =>
                                'mobile_topup',

                            'amount' =>
                                $this->decimal(
                                    $amount
                                ),

                            'currency' =>
                                $currency,

                            'fee_charged' =>
                                '0.00',

                            'description' =>
                                'Mobile Top-up - ' .
                                $validated['phone'],

                            'reference_id' =>
                                $reference,

                            'status' =>
                                'completed',

                            'idempotency_key' =>
                                $validated['idempotency_key'],
                        ]);

                    return [
                        'duplicate' =>
                            false,

                        'transaction' =>
                            $transaction,

                        'reference' =>
                            $reference,

                        'remaining_balance' =>
                            (float) $wallet->balance,
                    ];
                }
            );

            if ($result['duplicate']) {
                return response()->json([
                    'status' =>
                        'error',

                    'message' =>
                        'Duplicate mobile top-up request.',

                    'transaction' =>
                        $result['transaction'],
                ], 409);
            }

            SecurityEventLogger::log(
                $user,
                'mobile_topup_completed',
                'Mobile Top-up Completed',
                'User completed a mobile top-up of ' .
                number_format(
                    $amount,
                    2
                ) .
                ' ' .
                $currency .
                '.',
                'info',
                'Transaction',
                $result['transaction']->id,
                $request
            );

            try {
                WalletNotificationService::mobileTopup(
                    $user,
                    $amount,
                    $currency,
                    true,
                    $result['transaction']->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Mobile top-up completed successfully.',

                'reference' =>
                    $result['reference'],

                'transaction_id' =>
                    $result['transaction']->id,

                'amount' =>
                    $amount,

                'currency' =>
                    $currency,

                'remaining_balance' =>
                    $result['remaining_balance'],
            ], 200);

        } catch (\Throwable $e) {

            SecurityEventLogger::log(
                $user,
                'mobile_topup_failed',
                'Mobile Top-up Failed',
                'A mobile top-up attempt failed.',
                'warning',
                null,
                null,
                $request
            );

            try {
                WalletNotificationService::mobileTopup(
                    $user,
                    $amount,
                    $currency,
                    false,
                    null
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // CANCEL / REVERSE TRANSACTION
    // US-058: Reversal Notification
    // ============================================================

    public function cancelTransaction(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'reference_id' =>
                'required|string|max:255',
        ]);

        try {

            $result = DB::transaction(
                function () use ($user, $validated) {

                    $transaction =
                        Transaction::where(
                            'user_id',
                            $user->id
                        )
                            ->where(
                                'reference_id',
                                $validated['reference_id']
                            )
                            ->lockForUpdate()
                            ->first();

                    if (!$transaction) {
                        throw new \Exception(
                            'Transaction not found.'
                        );
                    }

                    if (
                        strtolower(
                            (string) $transaction->status
                        ) === 'cancelled'
                    ) {
                        throw new \Exception(
                            'Transaction has already been cancelled.'
                        );
                    }

                    $reversibleTypes = [
                        'withdrawal',
                        'payment',
                        'bill_payment',
                        'mobile_topup',
                        'transfer_out',
                        'deposit',
                    ];

                    if (
                        !in_array(
                            $transaction->type,
                            $reversibleTypes,
                            true
                        )
                    ) {
                        throw new \Exception(
                            'This transaction cannot be reversed.'
                        );
                    }

                    $wallet =
                        Wallet::where(
                            'id',
                            $transaction->wallet_id
                        )
                            ->lockForUpdate()
                            ->first();

                    if (!$wallet) {
                        throw new \Exception(
                            'Wallet not found.'
                        );
                    }

                    $originalAmount =
                        (float) $transaction->amount;

                    $originalFee =
                        (float) (
                            $transaction->fee_charged
                            ?? 0
                        );

                    $refundAmount =
                        round(
                            $originalAmount +
                            $originalFee,
                            2
                        );

                    $wallet->setAttribute(
                        'balance',
                        $this->decimal(
                            (float) $wallet->balance
                            + $refundAmount
                        )
                    );

                    $wallet->save();

                    if (
                        $transaction->type ===
                        'withdrawal'
                        && $originalFee > 0
                    ) {

                        $admin =
                            User::where(
                                'role',
                                'admin'
                            )->first();

                        if ($admin) {

                            $adminWallet =
                                $this->getOrCreateCurrencyWallet(
                                    $admin,
                                    $transaction->currency,
                                    true
                                );

                            $newAdminBalance =
                                max(
                                    0,
                                    (float) $adminWallet->balance
                                    - $originalFee
                                );

                            $adminWallet->setAttribute(
                                'balance',
                                $this->decimal(
                                    $newAdminBalance
                                )
                            );

                            $adminWallet->save();

                            Transaction::create([
                                'user_id' =>
                                    $admin->id,

                                'wallet_id' =>
                                    $adminWallet->id,

                                'type' =>
                                    'fee_reversal',

                                'amount' =>
                                    $this->decimal(
                                        $originalFee
                                    ),

                                'currency' =>
                                    $transaction->currency,

                                'fee_charged' =>
                                    '0.00',

                                'description' =>
                                    'Withdrawal Service Fee Reversal',

                                'reference_id' =>
                                    'REV-FEE-' .
                                    strtoupper(
                                        Str::random(10)
                                    ),

                                'status' =>
                                    'completed',
                            ]);
                        }
                    }

                    $oldReference =
                        $transaction->reference_id;

                    $newReference =
                        'REV-' .
                        strtoupper(
                            Str::random(10)
                        );

                    $transaction->reference_id =
                        $newReference;

                    $transaction->status =
                        'cancelled';

                    $transaction->save();

                    $refundTransaction =
                        Transaction::create([
                            'user_id' =>
                                $user->id,

                            'wallet_id' =>
                                $wallet->id,

                            'type' =>
                                'refund',

                            'amount' =>
                                $this->decimal(
                                    $refundAmount
                                ),

                            'currency' =>
                                $transaction->currency,

                            'fee_charged' =>
                                '0.00',

                            'description' =>
                                'Reversal of transaction ' .
                                $oldReference,

                            'reference_id' =>
                                $newReference,

                            'status' =>
                                'completed',
                        ]);

                    return [
                        'transaction' =>
                            $transaction,

                        'refund_transaction' =>
                            $refundTransaction,

                        'old_reference' =>
                            $oldReference,

                        'new_reference' =>
                            $newReference,

                        'refund_amount' =>
                            $refundAmount,

                        'remaining_balance' =>
                            (float) $wallet->balance,
                    ];
                }
            );

            SecurityEventLogger::log(
                $user,
                'transaction_reversed',
                'Transaction Reversed',
                'Transaction ' .
                $result['old_reference'] .
                ' was reversed and ' .
                number_format(
                    $result['refund_amount'],
                    2
                ) .
                ' ' .
                $result['transaction']->currency .
                ' was restored.',
                'warning',
                'Transaction',
                $result['refund_transaction']->id,
                $request
            );

            try {
                WalletNotificationService::transaction(
                    $user,
                    'Transaction Reversed',
                    'Transaction ' .
                    $result['old_reference'] .
                    ' was reversed. ' .
                    self::formatMoney(
                        $result['refund_amount'],
                        $result['transaction']->currency
                    ) .
                    ' has been restored to your wallet.',
                    'success',
                    $result['refund_amount'],
                    $result['transaction']->currency,
                    $result['refund_transaction']->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Transaction cancelled and reversed successfully.',

                'old_reference' =>
                    $result['old_reference'],

                'new_reference' =>
                    $result['new_reference'],

                'refund_amount' =>
                    $result['refund_amount'],

                'remaining_balance' =>
                    $result['remaining_balance'],
            ], 200);

        } catch (\Throwable $e) {

            SecurityEventLogger::log(
                $user,
                'transaction_reversal_failed',
                'Transaction Reversal Failed',
                'A transaction reversal attempt failed.',
                'warning',
                null,
                null,
                $request
            );

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // SCHEDULED PAYMENTS
    // US-058: Scheduled Payment Notifications
    // ============================================================

    public function createScheduledPayment(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'title' =>
                'required|string|max:255',

            'amount' =>
                'required|numeric|min:0.01',

            'currency' =>
                'required|string|in:USD,KHR',

            'scheduled_at' =>
                'required|date',

            'payment_type' =>
                'nullable|string|max:100',

            'recipient' =>
                'nullable|string|max:255',
        ]);

        try {

            $scheduledPayment =
                ScheduledPayment::create([
                    'user_id' =>
                        $user->id,

                    'title' =>
                        $validated['title'],

                    'amount' =>
                        $this->decimal(
                            $validated['amount']
                        ),

                    'currency' =>
                        strtoupper(
                            $validated['currency']
                        ),

                    'scheduled_at' =>
                        $validated['scheduled_at'],

                    'payment_type' =>
                        $validated['payment_type']
                        ?? null,

                    'recipient' =>
                        $validated['recipient']
                        ?? null,

                    'status' =>
                        'scheduled',
                ]);

            try {
                WalletNotificationService::scheduledPayment(
                    $user,
                    'Payment Scheduled',
                    'Your payment "' .
                    $scheduledPayment->title .
                    '" has been scheduled for ' .
                    $scheduledPayment->scheduled_at .
                    '.',
                    'info',
                    (float) $scheduledPayment->amount,
                    $scheduledPayment->currency,
                    $scheduledPayment->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Scheduled payment created successfully.',

                'scheduled_payment' =>
                    $scheduledPayment,
            ], 201);

        } catch (\Throwable $e) {

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // GET SCHEDULED PAYMENTS
    // ============================================================

    public function getScheduledPayments(
        Request $request
    ) {
        $user = $request->user();

        $payments =
            ScheduledPayment::where(
                'user_id',
                $user->id
            )
                ->orderBy(
                    'scheduled_at'
                )
                ->get();

        return response()->json([
            'status' =>
                'success',

            'scheduled_payments' =>
                $payments,
        ], 200);
    }

    // ============================================================
    // CANCEL SCHEDULED PAYMENT
    // US-058: Scheduled Payment Cancellation Notification
    // ============================================================

    public function cancelScheduledPayment(
        Request $request,
        $id
    ) {
        $user = $request->user();

        try {

            $payment =
                ScheduledPayment::where(
                    'user_id',
                    $user->id
                )
                    ->where(
                        'id',
                        $id
                    )
                    ->first();

            if (!$payment) {
                return response()->json([
                    'status' =>
                        'error',

                    'message' =>
                        'Scheduled payment not found.',
                ], 404);
            }

            $payment->status =
                'cancelled';

            $payment->save();

            try {
                WalletNotificationService::scheduledPayment(
                    $user,
                    'Scheduled Payment Cancelled',
                    'Your scheduled payment "' .
                    $payment->title .
                    '" has been cancelled.',
                    'warning',
                    (float) $payment->amount,
                    $payment->currency,
                    $payment->id
                );
            } catch (\Throwable $notificationError) {
                // Ignore notification failure.
            }

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Scheduled payment cancelled successfully.',

                'scheduled_payment' =>
                    $payment,
            ], 200);

        } catch (\Throwable $e) {

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // TRANSACTION NOTIFICATIONS
    // US-050
    // ============================================================

    public function transactionNotifications(
        Request $request
    ) {
        $user = $request->user();

        $transactions =
            $user->transactions()
                ->orderByDesc(
                    'created_at'
                )
                ->limit(20)
                ->get([
                    'id',
                    'type',
                    'amount',
                    'description',
                    'reference_id',
                    'status',
                    'currency',
                    'created_at',
                ]);

        return response()->json([
            'status' =>
                'success',

            'transactions' =>
                $transactions,
        ], 200);
    }

    // ============================================================
    // EMAIL TRANSACTION RECEIPT
    // ============================================================

    public function emailTransactionReceipt(
        Request $request
    ) {
        $user = $request->user();

        $validated = $request->validate([
            'reference_id' =>
                'required|string|max:255',
        ]);

        try {

            $transaction =
                Transaction::where(
                    'user_id',
                    $user->id
                )
                    ->where(
                        'reference_id',
                        $validated['reference_id']
                    )
                    ->first();

            if (!$transaction) {
                return response()->json([
                    'status' =>
                        'error',

                    'message' =>
                        'Transaction not found.',
                ], 404);
            }

            Mail::to(
                $user->email
            )->send(
                    new TransactionReceiptMail(
                        $user->name,
                        $transaction
                    )
                );

            return response()->json([
                'status' =>
                    'success',

                'message' =>
                    'Transaction receipt sent successfully.',
            ], 200);

        } catch (\Throwable $e) {

            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    $e->getMessage(),
            ], 400);
        }
    }

    // ============================================================
    // US-052 — SECURITY NOTIFICATIONS
    // ============================================================

    public function securityNotifications(
        Request $request
    ) {
        $user = $request->user();

        $events =
            $user->securityEvents()
                ->orderByDesc(
                    'occurred_at'
                )
                ->limit(20)
                ->get([
                    'id',
                    'event_type',
                    'severity',
                    'title',
                    'description',
                    'ip_address',
                    'reference_type',
                    'reference_id',
                    'is_reviewed',
                    'occurred_at',
                ]);

        return response()->json([
            'status' =>
                'success',

            'events' =>
                $events,
        ], 200);
    }
    public function reviewSecurityNotification(
        Request $request,
        $id
    ) {
        $user = $request->user();

        $event =
            $user->securityEvents()
                ->where('id', $id)
                ->first();

        if (!$event) {
            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    'Security notification not found.',
            ], 404);
        }

        $event->is_reviewed = true;
        $event->save();

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Security notification marked as reviewed.',

            'event' => [
                'id' =>
                    $event->id,

                'is_reviewed' =>
                    true,
            ],
        ], 200);
    }
    // ============================================================
    // US-053 — DEVICE MANAGEMENT
    // ============================================================

    public function devices(
        Request $request
    ) {
        $user = $request->user();

        $devices =
            $user->devices()
                ->where(
                    'is_active',
                    true
                )
                ->orderByDesc(
                    'last_active_at'
                )
                ->get([
                    'id',
                    'device_id',
                    'device_name',
                    'platform',
                    'ip_address',
                    'user_agent',
                    'last_active_at',
                    'is_active',
                    'created_at',
                ]);

        return response()->json([
            'status' =>
                'success',

            'devices' =>
                $devices,
        ], 200);
    }

    // ============================================================
    // US-053 — REVOKE DEVICE
    // ============================================================

    public function revokeDevice(
        Request $request,
        int $deviceId
    ) {
        $user = $request->user();

        $device =
            $user->devices()
                ->where(
                    'id',
                    $deviceId
                )
                ->where(
                    'is_active',
                    true
                )
                ->first();

        if (!$device) {
            return response()->json([
                'status' =>
                    'error',

                'message' =>
                    'Device not found or already revoked.',
            ], 404);
        }

        $device->update([
            'is_active' =>
                false,
        ]);

        SecurityEventLogger::log(
            $user,
            'device_revoked',
            'Device Revoked',
            sprintf(
                'A device was removed from your NaNa Wallet account. Device: %s.',
                $device->device_name
                ?? 'Unknown Device'
            ),
            'warning',
            'Device',
            $device->id,
            $request
        );

        try {
            WalletNotificationService::security(
                $user,
                'Device Removed',
                'A device has been removed from your NaNa Wallet account. Device: ' .
                ($device->device_name
                    ?? 'Unknown Device') .
                '.',
                'warning'
            );
        } catch (\Throwable $notificationError) {
            // Ignore notification failure.
        }

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Device has been revoked successfully.',
        ], 200);
    }

    // ============================================================
    // US-056 — ACTIVITY HISTORY
    // ============================================================

    public function activityHistory(
        Request $request
    ) {
        $user = $request->user();

        $transactions =
            $user->transactions()
                ->orderByDesc(
                    'created_at'
                )
                ->limit(100)
                ->get([
                    'id',
                    'type',
                    'amount',
                    'description',
                    'reference_id',
                    'status',
                    'currency',
                    'fee_charged',
                    'created_at',
                ]);

        return response()->json([
            'status' =>
                'success',

            'activities' =>
                $transactions,
        ], 200);
    }
}

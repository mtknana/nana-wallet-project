<?php

namespace App\Services;

use App\Models\SecurityEvent;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class FraudDetectionService
{
    /*
    |--------------------------------------------------------------------------
    | NaNa Wallet Fraud Detection Rules
    |--------------------------------------------------------------------------
    |
    | These thresholds are intentionally simple for the school project.
    | They are NOT real banking fraud thresholds.
    |
    */

    private const LARGE_TRANSACTION_USD = 5000.00;

    private const RAPID_TRANSFER_LIMIT = 3;

    private const RAPID_TRANSFER_MINUTES = 5;

    /**
     * Check whether a transaction should be flagged.
     *
     * @return array{
     *     detected: bool,
     *     reasons: array<int, string>
     * }
     */
    public static function checkTransaction(
        User $user,
        float $amount,
        string $currency,
        string $transactionType,
        ?Request $request = null
    ): array {
        $reasons = [];

        /*
        |--------------------------------------------------------------------------
        | Rule 1: Large Transaction
        |--------------------------------------------------------------------------
        */

        $usdAmount = self::convertToUsd(
            $amount,
            $currency
        );

        if ($usdAmount >= self::LARGE_TRANSACTION_USD) {
            $reasons[] =
                'Large transaction amount detected.';
        }

        /*
        |--------------------------------------------------------------------------
        | Rule 2: Rapid Transactions
        |--------------------------------------------------------------------------
        */

        if (
            self::hasRapidTransactions(
                $user,
                $transactionType
            )
        ) {
            $reasons[] =
                'Multiple transactions detected within a short period.';
        }

        return [
            'detected' => !empty($reasons),
            'reasons' => $reasons,
        ];
    }

    /**
     * Check whether the user has made too many transactions
     * within the configured time window.
     */
    /**
     * Check whether the user has made too many transactions
     * of the same type within the configured time window.
     */
    private static function hasRapidTransactions(
        User $user,
        string $transactionType
    ): bool {
        $since = Carbon::now()->subMinutes(
            self::RAPID_TRANSFER_MINUTES
        );

        $query = $user->transactions()
            ->where('created_at', '>=', $since);

        /*
        |--------------------------------------------------------------
        | Only count the transaction type being checked.
        | For P2P transfers, the sender transaction is recorded
        | as "withdrawal", so check that type.
        |--------------------------------------------------------------
        */

        if ($transactionType === 'transfer') {
            $query->where('type', 'withdrawal');
        } else {
            $query->where(
                'type',
                $transactionType
            );
        }

        $count = $query->count();

        return $count >= self::RAPID_TRANSFER_LIMIT;
    }

    /**
     * Convert KHR to USD using the same project exchange rate.
     *
     * NaNa Wallet:
     * 1 USD = 4,050 KHR
     */
    private static function convertToUsd(
        float $amount,
        string $currency
    ): float {
        $currency = strtoupper($currency);

        if ($currency === 'KHR') {
            return $amount / 4050.00;
        }

        return $amount;
    }

    /**
     * Log a fraud detection security event.
     */
    public static function logFraudDetection(
        User $user,
        float $amount,
        string $currency,
        string $transactionType,
        array $reasons,
        ?Request $request = null
    ): SecurityEvent {
        $reasonText = implode(' ', $reasons);

        /*
        |--------------------------------------------------------------------------
        | US-051 — Fraud Detection
        |--------------------------------------------------------------------------
        */

        $fraudEvent = SecurityEventLogger::log(
            $user,
            'fraud_detected',
            'Fraud Detection Alert',
            sprintf(
                'A potentially suspicious %s transaction was detected. Amount: %s %s. Reason: %s',
                strtoupper($transactionType),
                number_format($amount, 2),
                strtoupper($currency),
                $reasonText
            ),
            'danger',
            null,
            null,
            $request
        );

        /*
        |--------------------------------------------------------------------------
        | US-052 — Suspicious Activity Alert
        |--------------------------------------------------------------------------
        */

        SecurityEventLogger::log(
            $user,
            'suspicious_activity',
            'Suspicious Activity Alert',
            sprintf(
                'Suspicious activity was detected on your NaNa Wallet account. %s',
                $reasonText
            ),
            'warning',
            'SecurityEvent',
            $fraudEvent->id,
            $request
        );

        return $fraudEvent;
    }

}
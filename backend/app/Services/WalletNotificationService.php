<?php

namespace App\Services;

use App\Models\User;
use App\Models\WalletNotification;

class WalletNotificationService
{
    // ==========================================================
    // CREATE NOTIFICATION
    // ==========================================================

    public static function create(
        User $user,
        string $type,
        string $title,
        string $message,
        string $severity = 'info',
        ?float $amount = null,
        ?string $currency = null,
        ?string $referenceType = null,
        ?int $referenceId = null
    ): WalletNotification {
        return WalletNotification::create([
            'user_id' => $user->id,

            'type' => $type,

            'severity' => $severity,

            'title' => $title,

            'message' => $message,

            'amount' => $amount,

            'currency' =>
                $currency !== null
                ? strtoupper($currency)
                : null,

            'reference_type' =>
                $referenceType,

            'reference_id' =>
                $referenceId,

            'is_read' => false,

            'read_at' => null,

            'occurred_at' => now(),
        ]);
    }

    // ==========================================================
    // MONEY SENT
    // ==========================================================

    public static function moneySent(
        User $user,
        float $amount,
        string $currency,
        ?string $recipient = null,
        ?int $referenceId = null
    ): WalletNotification {
        $message =
            'You sent ' .
            self::money($amount, $currency) .
            ($recipient
                ? ' to ' . $recipient . '.'
                : '.');

        return self::create(
            $user,
            'money_sent',
            'Money Sent',
            $message,
            'success',
            $amount,
            $currency,
            'P2pTransfer',
            $referenceId
        );
    }

    // ==========================================================
    // MONEY RECEIVED
    // ==========================================================

    public static function moneyReceived(
        User $user,
        float $amount,
        string $currency,
        ?string $sender = null,
        ?int $referenceId = null
    ): WalletNotification {
        $message =
            'You received ' .
            self::money($amount, $currency) .
            ($sender
                ? ' from ' . $sender . '.'
                : '.');

        return self::create(
            $user,
            'money_received',
            'Money Received',
            $message,
            'success',
            $amount,
            $currency,
            'P2pTransfer',
            $referenceId
        );
    }

    // ==========================================================
    // WITHDRAWAL
    // ==========================================================

    public static function withdrawal(
        User $user,
        float $amount,
        string $currency,
        bool $success = true,
        ?float $fee = null,
        ?int $referenceId = null
    ): WalletNotification {
        if ($success) {
            $message =
                'Your withdrawal of ' .
                self::money($amount, $currency) .
                ' was completed successfully.';

            if ($fee !== null && $fee > 0) {
                $message .=
                    ' Service fee: ' .
                    self::money($fee, $currency) .
                    '.';
            }

            return self::create(
                $user,
                'withdrawal_completed',
                'Withdrawal Completed',
                $message,
                'success',
                $amount,
                $currency,
                'Transaction',
                $referenceId
            );
        }

        return self::create(
            $user,
            'withdrawal_failed',
            'Withdrawal Failed',
            'Your withdrawal of ' .
            self::money($amount, $currency) .
            ' could not be completed.',
            'danger',
            $amount,
            $currency,
            'Transaction',
            $referenceId
        );
    }

    // ==========================================================
    // BILL PAYMENT
    // ==========================================================

    public static function billPayment(
        User $user,
        float $amount,
        string $currency,
        bool $success = true,
        ?string $billName = null,
        ?int $referenceId = null
    ): WalletNotification {
        $name = $billName
            ? $billName
            : 'bill';

        if ($success) {
            return self::create(
                $user,
                'bill_payment_completed',
                'Bill Payment Successful',
                'Your ' .
                $name .
                ' payment of ' .
                self::money(
                    $amount,
                    $currency
                ) .
                ' was completed successfully.',
                'success',
                $amount,
                $currency,
                'Transaction',
                $referenceId
            );
        }

        return self::create(
            $user,
            'bill_payment_failed',
            'Bill Payment Failed',
            'Your ' .
            $name .
            ' payment of ' .
            self::money(
                $amount,
                $currency
            ) .
            ' could not be completed.',
            'danger',
            $amount,
            $currency,
            'Transaction',
            $referenceId
        );
    }

    // ==========================================================
    // MOBILE TOP-UP
    // ==========================================================

    public static function mobileTopup(
        User $user,
        float $amount,
        string $currency,
        bool $success = true,
        ?int $referenceId = null
    ): WalletNotification {
        return self::create(
            $user,
            $success
            ? 'mobile_topup_completed'
            : 'mobile_topup_failed',
            $success
            ? 'Mobile Top-up Successful'
            : 'Mobile Top-up Failed',
            $success
            ? 'Your mobile top-up of ' .
            self::money(
                $amount,
                $currency
            ) .
            ' was completed successfully.'
            : 'Your mobile top-up of ' .
            self::money(
                $amount,
                $currency
            ) .
            ' failed.',
            $success
            ? 'success'
            : 'danger',
            $amount,
            $currency,
            'Transaction',
            $referenceId
        );
    }

    // ==========================================================
    // QR PAYMENT
    // ==========================================================

    public static function qrPayment(
        User $user,
        float $amount,
        string $currency,
        bool $success = true,
        ?string $merchantName = null,
        ?int $referenceId = null
    ): WalletNotification {
        $merchant =
            $merchantName
            ? ' at ' . $merchantName
            : '';

        return self::create(
            $user,
            $success
            ? 'qr_payment_completed'
            : 'qr_payment_failed',
            $success
            ? 'QR Payment Successful'
            : 'QR Payment Failed',
            $success
            ? 'Your QR payment of ' .
            self::money(
                $amount,
                $currency
            ) .
            $merchant .
            ' was completed successfully.'
            : 'Your QR payment of ' .
            self::money(
                $amount,
                $currency
            ) .
            $merchant .
            ' failed.',
            $success
            ? 'success'
            : 'danger',
            $amount,
            $currency,
            'Transaction',
            $referenceId
        );
    }

    // ==========================================================
    // SPLIT BILL
    // ==========================================================

    public static function splitBill(
        User $user,
        string $title,
        string $message,
        string $severity = 'info',
        ?float $amount = null,
        ?string $currency = null,
        ?int $referenceId = null
    ): WalletNotification {
        return self::create(
            $user,
            'split_bill',
            $title,
            $message,
            $severity,
            $amount,
            $currency,
            'SplitBill',
            $referenceId
        );
    }

    // ==========================================================
    // SCHEDULED PAYMENT
    // ==========================================================

    public static function scheduledPayment(
        User $user,
        string $title,
        string $message,
        string $severity = 'info',
        ?float $amount = null,
        ?string $currency = null,
        ?int $referenceId = null
    ): WalletNotification {
        return self::create(
            $user,
            'scheduled_payment',
            $title,
            $message,
            $severity,
            $amount,
            $currency,
            'ScheduledPayment',
            $referenceId
        );
    }

    // ==========================================================
    // PAYROLL
    // ==========================================================

    public static function payrollReceived(
        User $user,
        float $amount,
        string $currency,
        ?int $referenceId = null
    ): WalletNotification {
        return self::create(
            $user,
            'payroll_received',
            'Payroll Received',
            'You received payroll of ' .
            self::money(
                $amount,
                $currency
            ) .
            '.',
            'success',
            $amount,
            $currency,
            'Transaction',
            $referenceId
        );
    }

    // ==========================================================
    // SCHOOL FEE
    // ==========================================================

    public static function schoolFee(
        User $user,
        string $title,
        string $message,
        string $severity = 'warning',
        ?float $amount = null,
        ?string $currency = null,
        ?int $referenceId = null
    ): WalletNotification {
        return self::create(
            $user,
            'school_fee',
            $title,
            $message,
            $severity,
            $amount,
            $currency,
            'CalendarEvent',
            $referenceId
        );
    }

    // ==========================================================
    // GENERAL TRANSACTION
    // ==========================================================

    public static function transaction(
        User $user,
        string $title,
        string $message,
        string $severity = 'info',
        ?float $amount = null,
        ?string $currency = null,
        ?int $referenceId = null
    ): WalletNotification {
        return self::create(
            $user,
            'transaction',
            $title,
            $message,
            $severity,
            $amount,
            $currency,
            'Transaction',
            $referenceId
        );
    }

    // ==========================================================
    // SECURITY
    // ==========================================================

    public static function security(
        User $user,
        string $title,
        string $message,
        string $severity = 'warning'
    ): WalletNotification {
        return self::create(
            $user,
            'security',
            $title,
            $message,
            $severity
        );
    }

    // ==========================================================
    // SYSTEM
    // ==========================================================

    public static function system(
        User $user,
        string $title,
        string $message,
        string $severity = 'info'
    ): WalletNotification {
        return self::create(
            $user,
            'system',
            $title,
            $message,
            $severity
        );
    }

    // ==========================================================
    // FORMAT MONEY
    // ==========================================================

    private static function money(
        float $amount,
        string $currency
    ): string {
        $currency = strtoupper($currency);

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
}
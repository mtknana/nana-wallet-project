<?php

namespace App\Services;

use App\Models\Currency;
use Illuminate\Validation\ValidationException;

class CurrencyService
{
    /**
     * Rates represent currency units per 1 USD.
     * Example: USD = 1, KHR = 4050.
     */
    public function convert(
        string $fromCode,
        string $toCode,
        float $amount
    ): array {
        if (!is_finite($amount) || $amount < 0) {
            throw ValidationException::withMessages([
                'amount' => 'Amount must be a valid non-negative number.',
            ]);
        }

        $from = Currency::query()
            ->where('code', strtoupper($fromCode))
            ->where('is_active', true)
            ->first();

        $to = Currency::query()
            ->where('code', strtoupper($toCode))
            ->where('is_active', true)
            ->first();

        if (!$from || !$to) {
            throw ValidationException::withMessages([
                'currency' => 'The source or target currency is unavailable.',
            ]);
        }

        $fromRate = (float) $from->exchange_rate;
        $toRate = (float) $to->exchange_rate;

        if ($fromRate <= 0 || $toRate <= 0) {
            throw ValidationException::withMessages([
                'currency' => 'Currency exchange rates must be greater than zero.',
            ]);
        }

        $convertedAmount = ($amount / $fromRate) * $toRate;

        return [
            'amount' => $amount,
            'from' => $from->code,
            'to' => $to->code,
            'converted_amount' => round(
                $convertedAmount,
                $to->decimal_places
            ),
            'exchange_rate' => $toRate / $fromRate,
        ];
    }

    public function activeCurrencies()
    {
        return Currency::query()
            ->where('is_active', true)
            ->orderByDesc('is_default')
            ->orderBy('code')
            ->get();
    }

    public function defaultCurrency(): ?Currency
    {
        return Currency::query()
            ->where('is_active', true)
            ->where('is_default', true)
            ->first();
    }
}
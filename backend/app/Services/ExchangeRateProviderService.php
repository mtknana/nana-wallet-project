<?php

namespace App\Services;

use App\Models\Currency;
use App\Models\ExchangeRateHistory;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

class ExchangeRateProviderService
{
    private const API_URL = 'https://open.er-api.com/v6/latest/USD';

    /**
     * Fetch provider rates and update only currencies configured
     * for automatic updates.
     *
     * Rates are currency units per 1 USD.
     */
    public function refreshAutomaticRates(): array
    {
        try {
            $response = Http::acceptJson()
                ->connectTimeout(5)
                ->timeout(15)
                ->retry(2, 300, throw: false)
                ->get(self::API_URL);

            if (!$response->successful()) {
                throw new \RuntimeException(
                    'Exchange-rate provider returned HTTP ' .
                    $response->status()
                );
            }

            $data = $response->json();

            if (
                !is_array($data) ||
                ($data['result'] ?? null) !== 'success' ||
                ($data['base_code'] ?? null) !== 'USD' ||
                !is_array($data['rates'] ?? null)
            ) {
                throw new \RuntimeException(
                    'Exchange-rate provider returned an invalid response.'
                );
            }

            $providerRates = $data['rates'];
            $updated = [];
            $skipped = [];
            $unchanged = [];

            $currencies = Currency::query()
                ->where('is_active', true)
                ->where('rate_update_mode', 'automatic')
                ->orderBy('id')
                ->get();

            foreach ($currencies as $currency) {
                $code = strtoupper($currency->code);

                if (!array_key_exists($code, $providerRates)) {
                    $skipped[] = $code . ': provider rate unavailable';
                    continue;
                }

                $newRate = $providerRates[$code];

                if (
                    !is_numeric($newRate) ||
                    !is_finite((float) $newRate) ||
                    (float) $newRate <= 0
                ) {
                    $skipped[] = $code . ': invalid provider rate';
                    continue;
                }

                $newRate = (float) $newRate;
                $oldRate = (float) $currency->exchange_rate;

                // Avoid unnecessary history entries for unchanged rates.
                if (abs($newRate - $oldRate) < 0.000000005) {
                    $unchanged[] = $code;
                    continue;
                }

                DB::transaction(function () use ($currency, $newRate, $data): void {
                    $lockedCurrency = Currency::query()
                        ->whereKey($currency->id)
                        ->lockForUpdate()
                        ->first();

                    if (
                        !$lockedCurrency ||
                        !$lockedCurrency->is_active ||
                        $lockedCurrency->rate_update_mode !== 'automatic'
                    ) {
                        return;
                    }

                    $lockedCurrency->update([
                        'exchange_rate' => $newRate,
                    ]);

                    ExchangeRateHistory::create([
                        'currency_id' => $lockedCurrency->id,
                        'exchange_rate' => $newRate,
                        'source' => 'automatic',
                        'recorded_at' => now(),
                        'changed_by' => null,
                        'metadata' => [
                            'provider' => 'ExchangeRate-API Open Access',
                            'base_code' => 'USD',
                            'provider_updated_at' =>
                                $data['time_last_update_utc'] ?? null,
                            'provider_next_update_at' =>
                                $data['time_next_update_utc'] ?? null,
                        ],
                    ]);
                });

                $updated[] = $code;
            }

            Log::info('Automatic exchange-rate refresh completed.', [
                'updated' => $updated,
                'unchanged' => $unchanged,
                'skipped' => $skipped,
            ]);

            return [
                'success' => true,
                'updated' => $updated,
                'unchanged' => $unchanged,
                'skipped' => $skipped,
                'provider_updated_at' =>
                    $data['time_last_update_utc'] ?? null,
                'message' => 'Exchange-rate refresh completed.',
            ];
        } catch (Throwable $exception) {
            Log::error('Automatic exchange-rate refresh failed.', [
                'message' => $exception->getMessage(),
            ]);

            return [
                'success' => false,
                'updated' => [],
                'unchanged' => [],
                'skipped' => [],
                'message' =>
                    'Provider refresh failed. Existing rates were preserved.',
            ];
        }
    }
}
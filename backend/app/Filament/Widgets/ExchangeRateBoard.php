<?php

namespace App\Filament\Widgets;

use App\Models\Currency;
use App\Models\ExchangeRateHistory;
use App\Services\ExchangeRateProviderService;
use Filament\Notifications\Notification;
use Filament\Widgets\Widget;
use Illuminate\Support\Facades\Auth;

class ExchangeRateBoard extends Widget
{
    protected static string $view =
        'filament.widgets.exchange-rate-board';

    protected int|string|array $columnSpan = 'full';

    public function refreshRates(): void
    {
        abort_unless(
            Auth::check() && Auth::user()->role === 'admin',
            403
        );

        $result = app(ExchangeRateProviderService::class)
            ->refreshAutomaticRates();

        if (!$result['success']) {
            Notification::make()
                ->title('Exchange-rate refresh failed')
                ->body($result['message'])
                ->danger()
                ->send();

            return;
        }

        Notification::make()
            ->title('Exchange-rate refresh completed')
            ->body(
                count($result['updated']) .
                ' currency rate(s) updated.'
            )
            ->success()
            ->send();
    }

    protected function getViewData(): array
    {
        $currencies = Currency::query()
            ->orderByDesc('is_default')
            ->orderBy('code')
            ->get();

        $rates = $currencies->map(function (Currency $currency): array {
            $history = ExchangeRateHistory::query()
                ->where('currency_id', $currency->id)
                ->orderByDesc('recorded_at')
                ->orderByDesc('id')
                ->limit(2)
                ->get();

            $latestHistory = $history->first();
            $currentRate = (float) $currency->exchange_rate;
            $previousRate = null;

            if ($latestHistory) {
                $latestRecordedRate =
                    (float) $latestHistory->exchange_rate;

                if (abs($latestRecordedRate - $currentRate) < 0.000000005) {
                    $previousRate = $history->get(1)
                        ? (float) $history->get(1)->exchange_rate
                        : null;
                } else {
                    $previousRate = $latestRecordedRate;
                }
            }

            $changePercent = null;

            if ($previousRate !== null && $previousRate > 0) {
                $changePercent =
                    (($currentRate - $previousRate) / $previousRate) * 100;
            }

            return [
                'currency' => $currency,
                'current_rate' => $currentRate,
                'previous_rate' => $previousRate,
                'change_percent' => $changePercent,
                'last_recorded_at' => $latestHistory?->recorded_at,
            ];
        });

        return [
            'rates' => $rates,
            'activeCount' => $currencies
                ->where('is_active', true)
                ->count(),
            'defaultCurrency' => $currencies
                ->firstWhere('is_default', true),
            'lastUpdated' => ExchangeRateHistory::query()
                ->latest('recorded_at')
                ->value('recorded_at'),
        ];
    }
}
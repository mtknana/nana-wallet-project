<?php

namespace App\Filament\Widgets;

use App\Models\Currency;
use App\Models\ExchangeRateHistory;
use Filament\Widgets\ChartWidget;

class ExchangeRateHistoryChart extends ChartWidget
{
    protected static ?string $heading = 'Exchange Rate History';

    protected static ?int $sort = 9;

    protected int|string|array $columnSpan = 'full';

    protected function getFilters(): ?array
    {
        return Currency::query()
            ->orderBy('code')
            ->pluck('code', 'id')
            ->toArray();
    }

    protected function getData(): array
    {
        $currencyId = $this->filter;

        if (!$currencyId) {
            $currencyId = Currency::query()
                ->where('is_active', true)
                ->orderByDesc('is_default')
                ->value('id');
        }

        if (!$currencyId) {
            return [
                'datasets' => [],
                'labels' => [],
            ];
        }

        $history = ExchangeRateHistory::query()
            ->where('currency_id', $currencyId)
            ->where('recorded_at', '>=', now()->subDays(90))
            ->orderBy('recorded_at')
            ->orderBy('id')
            ->get()
            ->groupBy(fn($entry) => $entry->recorded_at->format('Y-m-d'))
            ->map(fn($entries) => (float) $entries->last()->exchange_rate);

        return [
            'datasets' => [
                [
                    'label' => 'Units per 1 USD',
                    'data' => $history->values()->all(),
                    'fill' => false,
                ],
            ],
            'labels' => $history->keys()->all(),
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }
}
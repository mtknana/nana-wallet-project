<?php

namespace App\Filament\Pages;

use App\Filament\Widgets\ExchangeRateBoard as ExchangeRateBoardWidget;
use App\Filament\Widgets\ExchangeRateHistoryChart;
use App\Filament\Widgets\ExchangeRateHistoryTable;
use Filament\Pages\Page;

class ExchangeRateBoard extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-chart-bar';

    protected static ?string $navigationGroup = 'Currency Management';

    protected static ?string $navigationLabel = 'Exchange Rate Board';

    protected static ?int $navigationSort = 2;

    protected static string $view = 'filament.pages.exchange-rates';

    protected function getHeaderWidgets(): array
    {
        return [
            ExchangeRateBoardWidget::class,
            ExchangeRateHistoryChart::class,
            ExchangeRateHistoryTable::class,
        ];
    }

    public function getHeaderWidgetsColumns(): int|array
    {
        return 2;
    }
}
<?php

namespace App\Filament\Widgets;

use App\Models\Transaction;
use Carbon\Carbon;
use Filament\Widgets\ChartWidget;

class TransactionTrendChart extends ChartWidget
{
    protected static ?string $heading =
        'Transaction Trend — Last 7 Days';

    protected static ?string $maxHeight =
        '300px';

    protected function getData(): array
    {
        $labels = [];
        $counts = [];

        for ($i = 6; $i >= 0; $i--) {
            $date =
                Carbon::today()
                    ->subDays($i);

            $labels[] =
                $date->format('M d');

            $counts[] =
                Transaction::query()
                    ->whereDate(
                        'created_at',
                        $date
                    )
                    ->count();
        }

        return [
            'datasets' => [
                [
                    'label' =>
                        'Transactions',

                    'data' =>
                        $counts,
                ],
            ],

            'labels' =>
                $labels,
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }
}
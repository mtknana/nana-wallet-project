<?php

namespace App\Filament\Widgets;

use App\Models\Loan;
use Carbon\Carbon;
use Filament\Widgets\ChartWidget;

class LoanActivityChart extends ChartWidget
{
    protected static ?string $heading = 'Monthly Loan Activity';

    protected static ?string $description = 'Number of loans created each month over the last 6 months.';

    protected static ?int $sort = 3;

    protected function getData(): array
    {
        $labels = [];
        $loanCounts = [];

        for ($i = 5; $i >= 0; $i--) {
            $month = Carbon::now()->startOfMonth()->subMonths($i);

            $labels[] = $month->format('M Y');

            $loanCounts[] = Loan::query()
                ->whereBetween('created_at', [
                    $month->copy()->startOfMonth(),
                    $month->copy()->endOfMonth(),
                ])
                ->count();
        }

        return [
            'datasets' => [
                [
                    'label' => 'Loans Created',
                    'data' => $loanCounts,
                    'borderColor' => '#10B981',
                    'backgroundColor' => 'rgba(16, 185, 129, 0.15)',
                    'fill' => true,
                    'tension' => 0.3,
                ],
            ],
            'labels' => $labels,
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }
}
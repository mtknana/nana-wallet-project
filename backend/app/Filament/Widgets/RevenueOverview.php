<?php

namespace App\Filament\Widgets;

use App\Models\Transaction;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class RevenueOverview extends BaseWidget
{
    protected function getStats(): array
    {
        $usdRevenue =
            Transaction::query()
                ->where(
                    'type',
                    'fee_income'
                )
                ->where(
                    'currency',
                    'USD'
                )
                ->where(
                    'status',
                    'completed'
                )
                ->sum('amount');

        $khrRevenue =
            Transaction::query()
                ->where(
                    'type',
                    'fee_income'
                )
                ->where(
                    'currency',
                    'KHR'
                )
                ->where(
                    'status',
                    'completed'
                )
                ->sum('amount');

        $totalRevenueTransactions =
            Transaction::query()
                ->where(
                    'type',
                    'fee_income'
                )
                ->where(
                    'status',
                    'completed'
                )
                ->count();

        return [
            Stat::make(
                'USD Revenue',
                '$' .
                number_format(
                    (float) $usdRevenue,
                    2
                )
            )
                ->description(
                    'Recorded fee income'
                )
                ->icon(
                    'heroicon-o-banknotes'
                ),

            Stat::make(
                'KHR Revenue',
                number_format(
                    (float) $khrRevenue,
                    0
                ) . ' KHR'
            )
                ->description(
                    'Recorded fee income'
                )
                ->icon(
                    'heroicon-o-banknotes'
                ),

            Stat::make(
                'Revenue Transactions',
                number_format(
                    $totalRevenueTransactions
                )
            )
                ->description(
                    'Completed fee income'
                )
                ->icon(
                    'heroicon-o-chart-bar'
                ),
        ];
    }
}
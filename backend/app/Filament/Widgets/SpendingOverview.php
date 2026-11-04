<?php

namespace App\Filament\Widgets;

use App\Models\Transaction;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class SpendingOverview extends BaseWidget
{
    protected function getStats(): array
    {
        $expenseTypes = [
            'withdrawal',
            'payment',
            'bill_payment',
            'mobile_topup',
            'transfer_out',
        ];

        $usdSpending =
            Transaction::query()
                ->whereIn(
                    'type',
                    $expenseTypes
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

        $khrSpending =
            Transaction::query()
                ->whereIn(
                    'type',
                    $expenseTypes
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

        $spendingTransactions =
            Transaction::query()
                ->whereIn(
                    'type',
                    $expenseTypes
                )
                ->where(
                    'status',
                    'completed'
                )
                ->count();

        return [
            Stat::make(
                'USD Spending',
                '$' .
                number_format(
                    (float) $usdSpending,
                    2
                )
            )
                ->description(
                    'Completed money-out activity'
                )
                ->icon(
                    'heroicon-o-arrow-trending-down'
                ),

            Stat::make(
                'KHR Spending',
                number_format(
                    (float) $khrSpending,
                    0
                ) . ' KHR'
            )
                ->description(
                    'Completed money-out activity'
                )
                ->icon(
                    'heroicon-o-arrow-trending-down'
                ),

            Stat::make(
                'Spending Transactions',
                number_format(
                    $spendingTransactions
                )
            )
                ->description(
                    'Completed expenses'
                )
                ->icon(
                    'heroicon-o-credit-card'
                ),
        ];
    }
}
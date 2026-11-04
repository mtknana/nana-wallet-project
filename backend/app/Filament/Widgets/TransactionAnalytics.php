<?php

namespace App\Filament\Widgets;

use App\Models\Transaction;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class TransactionAnalytics extends BaseWidget
{
    protected function getStats(): array
    {
        $total =
            Transaction::query()
                ->count();

        $completed =
            Transaction::query()
                ->where(
                    'status',
                    'completed'
                )
                ->count();

        $failed =
            Transaction::query()
                ->where(
                    'status',
                    'failed'
                )
                ->count();

        $cancelled =
            Transaction::query()
                ->where(
                    'status',
                    'cancelled'
                )
                ->count();

        return [
            Stat::make(
                'Total Transactions',
                number_format($total)
            )
                ->description(
                    'All wallet transactions'
                )
                ->icon('heroicon-o-arrows-right-left'),

            Stat::make(
                'Completed',
                number_format($completed)
            )
                ->description(
                    'Successfully completed'
                )
                ->icon('heroicon-o-check-circle'),

            Stat::make(
                'Failed',
                number_format($failed)
            )
                ->description(
                    'Failed transactions'
                )
                ->icon('heroicon-o-x-circle'),

            Stat::make(
                'Cancelled',
                number_format($cancelled)
            )
                ->description(
                    'Cancelled transactions'
                )
                ->icon('heroicon-o-no-symbol'),
        ];
    }
}
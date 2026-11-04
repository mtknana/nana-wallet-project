<?php

namespace App\Filament\Widgets;

use App\Models\Wallet;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class WalletBalanceOverview extends BaseWidget
{
    protected function getStats(): array
    {
        $usdBalance =
            Wallet::query()
                ->where(
                    'currency',
                    'USD'
                )
                ->where(
                    'status',
                    'active'
                )
                ->sum('balance');

        $khrBalance =
            Wallet::query()
                ->where(
                    'currency',
                    'KHR'
                )
                ->where(
                    'status',
                    'active'
                )
                ->sum('balance');

        $activeWallets =
            Wallet::query()
                ->where(
                    'status',
                    'active'
                )
                ->count();

        return [
            Stat::make(
                'Total USD Balance',
                '$' .
                number_format(
                    (float) $usdBalance,
                    2
                )
            )
                ->description(
                    'Across active wallets'
                )
                ->icon(
                    'heroicon-o-wallet'
                ),

            Stat::make(
                'Total KHR Balance',
                number_format(
                    (float) $khrBalance,
                    0
                ) . ' KHR'
            )
                ->description(
                    'Across active wallets'
                )
                ->icon(
                    'heroicon-o-wallet'
                ),

            Stat::make(
                'Active Wallets',
                number_format(
                    $activeWallets
                )
            )
                ->description(
                    'Currently active'
                )
                ->icon(
                    'heroicon-o-check-badge'
                ),
        ];
    }
}
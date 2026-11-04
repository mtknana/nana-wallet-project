<?php

namespace App\Filament\Widgets;

use App\Models\User;
use App\Models\Wallet;
use App\Models\Transaction;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class FinancialOverview extends BaseWidget
{
    protected static ?string $pollingInterval = '5s';

    protected function getStats(): array
    {
        // 1. Aggregate active USD wallet balances
        $totalUsdBalance = Wallet::where('currency', 'USD')
            ->where('status', 'active')
            ->sum('balance');

        // 2. Aggregate active KHR wallet balances
        $totalKhrBalance = Wallet::where('currency', 'KHR')
            ->where('status', 'active')
            ->sum('balance');

        // 3. Count all recorded financial ledger transactions
        $totalTransactionsCount = Transaction::count();

        // 4. Count standard customer accounts
        $totalSystemUsersCount = User::where('role', 'user')->count();

        return [
            Stat::make(
                'Total USD Wallet Balances',
                '$ ' . number_format($totalUsdBalance, 2)
            )
                ->description('Combined balance across active USD wallets')
                ->descriptionIcon('heroicon-m-banknotes')
                ->color('success'),

            Stat::make(
                'Total KHR Wallet Balances',
                '៛ ' . number_format($totalKhrBalance, 0)
            )
                ->description('Combined balance across active KHR wallets')
                ->descriptionIcon('heroicon-m-banknotes')
                ->color('info'),

            Stat::make(
                'Total Ledger Transactions',
                number_format($totalTransactionsCount) . ' Records'
            )
                ->description('All recorded wallet financial transactions')
                ->descriptionIcon('heroicon-m-arrow-path')
                ->color('warning'),

            Stat::make(
                'Registered Customers',
                number_format($totalSystemUsersCount) . ' Customers'
            )
                ->description('Standard customer accounts registered')
                ->descriptionIcon('heroicon-m-users')
                ->color('primary'),
        ];
    }
}
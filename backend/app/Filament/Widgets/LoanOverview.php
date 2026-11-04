<?php

namespace App\Filament\Widgets;

use App\Models\Loan;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class LoanOverview extends StatsOverviewWidget
{
    protected ?string $heading = 'NaNa Quick Loan Overview';

    protected function getStats(): array
    {
        $totalLoans = Loan::count();

        $activeLoans = Loan::whereIn('status', [
            'active',
            'overdue',
            'partially_paid',
        ])->count();

        $completedLoans = Loan::where('status', 'repaid')->count();

        $usdOutstanding = Loan::where('currency', 'USD')
            ->sum('outstanding_principal');

        $khrOutstanding = Loan::where('currency', 'KHR')
            ->sum('outstanding_principal');

        $usdInterest = Loan::where('currency', 'USD')
            ->sum('upfront_interest');

        $khrInterest = Loan::where('currency', 'KHR')
            ->sum('upfront_interest');

        return [
            Stat::make('Total Loans', number_format($totalLoans))
                ->description('All loan applications')
                ->icon('heroicon-o-document-text'),

            Stat::make('Active Loans', number_format($activeLoans))
                ->description('Loans awaiting repayment')
                ->icon('heroicon-o-clock'),

            Stat::make('Completed Loans', number_format($completedLoans))
                ->description('Fully repaid loans')
                ->icon('heroicon-o-check-circle'),

            Stat::make('USD Outstanding', '$' . number_format((float) $usdOutstanding, 2))
                ->description('Outstanding USD principal')
                ->icon('heroicon-o-banknotes'),

            Stat::make('KHR Outstanding', '៛' . number_format((float) $khrOutstanding, 0))
                ->description('Outstanding KHR principal')
                ->icon('heroicon-o-banknotes'),

            Stat::make('USD Interest Earned', '$' . number_format((float) $usdInterest, 2))
                ->description('Upfront interest from USD loans')
                ->icon('heroicon-o-chart-bar'),

            Stat::make('KHR Interest Earned', '៛' . number_format((float) $khrInterest, 0))
                ->description('Upfront interest from KHR loans')
                ->icon('heroicon-o-chart-bar'),
        ];
    }
}
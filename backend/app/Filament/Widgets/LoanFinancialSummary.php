<?php

namespace App\Filament\Widgets;

use App\Models\Loan;
use App\Models\LoanRepayment;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class LoanFinancialSummary extends BaseWidget
{
    protected ?string $heading = 'Loan Financial Summary';

    protected function getStats(): array
    {
        // Principal disbursed
        $usdPrincipal = Loan::where('currency', 'USD')->sum('principal');
        $khrPrincipal = Loan::where('currency', 'KHR')->sum('principal');

        // Upfront interest collected
        $usdInterest = Loan::where('currency', 'USD')->sum('upfront_interest');
        $khrInterest = Loan::where('currency', 'KHR')->sum('upfront_interest');

        // Actual repayments collected
        $usdRepayments = LoanRepayment::where('currency', 'USD')
            ->sum('amount_collected');

        $khrRepayments = LoanRepayment::where('currency', 'KHR')
            ->sum('amount_collected');

        // Outstanding principal
        $usdOutstanding = Loan::where('currency', 'USD')
            ->sum('outstanding_principal');

        $khrOutstanding = Loan::where('currency', 'KHR')
            ->sum('outstanding_principal');

        return [
            Stat::make(
                'USD Principal Disbursed',
                '$' . number_format((float) $usdPrincipal, 2)
            )
                ->description('Total USD loan principal')
                ->icon('heroicon-o-banknotes'),

            Stat::make(
                'KHR Principal Disbursed',
                '៛' . number_format((float) $khrPrincipal, 0)
            )
                ->description('Total KHR loan principal')
                ->icon('heroicon-o-banknotes'),

            Stat::make(
                'USD Interest Earned',
                '$' . number_format((float) $usdInterest, 2)
            )
                ->description('Upfront interest collected')
                ->icon('heroicon-o-chart-bar')
                ->color('success'),

            Stat::make(
                'KHR Interest Earned',
                '៛' . number_format((float) $khrInterest, 0)
            )
                ->description('Upfront interest collected')
                ->icon('heroicon-o-chart-bar')
                ->color('success'),

            Stat::make(
                'USD Repayments Collected',
                '$' . number_format((float) $usdRepayments, 2)
            )
                ->description('Actual USD repayments received')
                ->icon('heroicon-o-arrow-down-circle')
                ->color('success'),

            Stat::make(
                'KHR Repayments Collected',
                '៛' . number_format((float) $khrRepayments, 0)
            )
                ->description('Actual KHR repayments received')
                ->icon('heroicon-o-arrow-down-circle')
                ->color('success'),

            Stat::make(
                'USD Outstanding',
                '$' . number_format((float) $usdOutstanding, 2)
            )
                ->description('Remaining USD principal')
                ->icon('heroicon-o-clock')
                ->color('warning'),

            Stat::make(
                'KHR Outstanding',
                '៛' . number_format((float) $khrOutstanding, 0)
            )
                ->description('Remaining KHR principal')
                ->icon('heroicon-o-clock')
                ->color('warning'),
        ];
    }
}
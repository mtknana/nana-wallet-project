<?php

namespace App\Services;

use App\Models\Transaction;
use App\Models\Wallet;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class FinancialInsightsService
{
    private const OUTGOING_TYPES = [
        'withdrawal',
        'transfer',
        'p2p_transfer',
        'payment',
        'bill_payment',
        'mobile_topup',
        'qr_payment',
    ];

    /**
     * Generate spending summaries and data-driven spending predictions.
     * No external AI API key is required for this forecasting version.
     */
    public function generate(int $userId): array
    {
        $now = Carbon::now();

        $startOfMonth = $now->copy()->startOfMonth();
        $startOfNextMonth = $startOfMonth->copy()->addMonthNoOverflow();
        $historyStart = $startOfMonth->copy()->subMonthsNoOverflow(3);
        $previousMonthStart = $startOfMonth->copy()->subMonthNoOverflow();

        $wallets = Wallet::query()
            ->where('user_id', $userId)
            ->get(['currency', 'balance', 'status']);

        $transactions = Transaction::query()
            ->where('user_id', $userId)
            ->where('status', 'completed')
            ->where('created_at', '>=', $historyStart)
            ->where('created_at', '<', $startOfNextMonth)
            ->orderBy('created_at')
            ->get([
                'type',
                'amount',
                'currency',
                'created_at',
                'status',
            ]);

        $currentMonth = $transactions->filter(
            fn($transaction) =>
                $transaction->created_at >= $startOfMonth
        );

        $previousMonth = $transactions->filter(
            fn($transaction) =>
                $transaction->created_at >= $previousMonthStart
                && $transaction->created_at < $startOfMonth
        );

        $currencies = $wallets->pluck('currency')
            ->merge($transactions->pluck('currency'))
            ->filter()
            ->unique()
            ->values();

        $currencyInsights = [];
        $spendingPredictions = [];
        $insights = [];

        foreach ($currencies as $currency) {
            $current = $this->summarizeCurrency(
                $currentMonth->where('currency', $currency)
            );

            $previous = $this->summarizeCurrency(
                $previousMonth->where('currency', $currency)
            );

            $changePercent = $this->percentageChange(
                $previous['outgoing'],
                $current['outgoing']
            );

            // Build history from the three most recent completed months.
            $monthlyHistory = [];

            for ($monthsAgo = 3; $monthsAgo >= 1; $monthsAgo--) {
                $monthStart = $startOfMonth->copy()
                    ->subMonthsNoOverflow($monthsAgo);

                $monthEnd = $monthStart->copy()
                    ->addMonthNoOverflow();

                $monthTransactions = $transactions->filter(
                    fn($transaction) =>
                        $transaction->currency === $currency
                        && $transaction->created_at >= $monthStart
                        && $transaction->created_at < $monthEnd
                );

                $monthSummary = $this->summarizeCurrency(
                    $monthTransactions
                );

                $monthlyHistory[] = [
                    'month' => $monthStart->format('Y-m'),
                    'outgoing' => $monthSummary['outgoing'],
                    'transaction_count' => $monthSummary['transaction_count'],
                ];
            }

            $prediction = $this->predictNextMonth(
                $monthlyHistory,
                $current['outgoing'],
                $now,
                $startOfNextMonth
            );

            $currencyInsights[$currency] = [
                'current_month' => $current,
                'previous_month' => $previous,
                'spending_change_percent' => $changePercent,
                'monthly_history' => $monthlyHistory,
                'prediction' => $prediction,
            ];

            $spendingPredictions[$currency] = [
                'currency' => $currency,
                'period_start' => $startOfNextMonth->toDateString(),
                'period_end' => $startOfNextMonth->copy()
                    ->endOfMonth()
                    ->toDateString(),
                'projected_spending' => $prediction['projected_spending'],
                'method' => $prediction['method'],
                'confidence' => $prediction['confidence'],
                'historical_months_used' => $prediction['historical_months_used'],
                'message' => $this->predictionMessage(
                    $currency,
                    $prediction
                ),
            ];

            if ($current['outgoing'] > 0) {
                $insights[] = [
                    'type' => 'spending_summary',
                    'currency' => $currency,
                    'message' => sprintf(
                        'Your outgoing transactions this month total %s %s.',
                        number_format($current['outgoing'], 2),
                        $currency
                    ),
                ];
            }

            if ($previous['outgoing'] > 0 && $changePercent !== null) {
                if ($changePercent > 0) {
                    $message = sprintf(
                        'Your outgoing transactions increased by %.1f%% compared with last month.',
                        $changePercent
                    );
                } elseif ($changePercent < 0) {
                    $message = sprintf(
                        'Your outgoing transactions decreased by %.1f%% compared with last month.',
                        abs($changePercent)
                    );
                } else {
                    $message = 'Your outgoing transactions are unchanged compared with last month.';
                }

                $insights[] = [
                    'type' => 'spending_trend',
                    'currency' => $currency,
                    'message' => $message,
                ];
            }

            $insights[] = [
                'type' => 'spending_prediction',
                'currency' => $currency,
                'message' => $spendingPredictions[$currency]['message'],
            ];

            if ($current['transaction_count'] === 0) {
                $insights[] = [
                    'type' => 'activity',
                    'currency' => $currency,
                    'message' => 'No completed transactions were recorded in this currency this month.',
                ];
            }
        }

        if ($insights === []) {
            $insights[] = [
                'type' => 'general',
                'currency' => null,
                'message' => 'Start using your wallet to receive personalized financial summaries and spending predictions.',
            ];
        }

        return [
            'generated_at' => $now->toIso8601String(),

            'period' => [
                'current_month_start' => $startOfMonth->toDateString(),
                'previous_month_start' => $previousMonthStart->toDateString(),
                'prediction_period_start' => $startOfNextMonth->toDateString(),
                'prediction_period_end' => $startOfNextMonth->copy()
                    ->endOfMonth()
                    ->toDateString(),
            ],

            'wallets' => $wallets->map(fn($wallet) => [
                'currency' => $wallet->currency,
                'balance' => (float) $wallet->balance,
                'status' => $wallet->status,
            ])->values(),

            'currency_summaries' => $currencyInsights,
            'spending_predictions' => $spendingPredictions,
            'insights' => $insights,

            'notice' => 'Predictions are estimates based on recorded completed transactions, not guarantees or financial advice.',
        ];
    }

    /**
     * Forecast next month's outgoing transactions.
     *
     * Uses a weighted average of available completed months.
     * If there is no usable history, estimates from the current
     * month's spending pace and labels the prediction low confidence.
     */
    private function predictNextMonth(
        array $monthlyHistory,
        float $currentMonthOutgoing,
        Carbon $now,
        Carbon $nextMonthStart
    ): array {
        $observedMonths = array_values(array_filter(
            $monthlyHistory,
            fn(array $month) => $month['transaction_count'] > 0
        ));

        if ($observedMonths !== []) {
            $weightedTotal = 0.0;
            $totalWeight = 0;

            foreach ($observedMonths as $index => $month) {
                $weight = $index + 1;

                $weightedTotal += $month['outgoing'] * $weight;
                $totalWeight += $weight;
            }

            $projected = $totalWeight > 0
                ? $weightedTotal / $totalWeight
                : 0.0;

            $observedCount = count($observedMonths);

            return [
                'projected_spending' => round($projected, 2),
                'method' => 'weighted_historical_average',
                'confidence' => match (true) {
                    $observedCount >= 3 => 'high',
                    $observedCount === 2 => 'medium',
                    default => 'low',
                },
                'historical_months_used' => $observedCount,
            ];
        }

        if ($currentMonthOutgoing > 0) {
            $daysElapsed = max(1, (int) $now->day);
            $daysInCurrentMonth = (int) $now->daysInMonth;
            $daysInNextMonth = (int) $nextMonthStart->daysInMonth;

            $dailySpendingPace = $currentMonthOutgoing / $daysElapsed;

            return [
                'projected_spending' => round(
                    $dailySpendingPace * $daysInNextMonth,
                    2
                ),
                'method' => 'current_month_spending_pace',
                'confidence' => 'low',
                'historical_months_used' => 0,
            ];
        }

        return [
            'projected_spending' => null,
            'method' => 'insufficient_data',
            'confidence' => 'insufficient_data',
            'historical_months_used' => 0,
        ];
    }

    private function predictionMessage(
        string $currency,
        array $prediction
    ): string {
        if ($prediction['projected_spending'] === null) {
            return 'There is not enough completed transaction history to estimate next month’s spending in '
                . $currency . '.';
        }

        return sprintf(
            'Your estimated outgoing transactions for next month are %s %s. Confidence: %s, based on %d historical month(s).',
            number_format($prediction['projected_spending'], 2),
            $currency,
            $prediction['confidence'],
            $prediction['historical_months_used']
        );
    }

    private function summarizeCurrency(Collection $transactions): array
    {
        $outgoing = $transactions->filter(
            fn($transaction) => in_array(
                strtolower((string) $transaction->type),
                self::OUTGOING_TYPES,
                true
            )
        );

        $incoming = $transactions->reject(
            fn($transaction) => in_array(
                strtolower((string) $transaction->type),
                self::OUTGOING_TYPES,
                true
            )
        );

        return [
            'transaction_count' => $transactions->count(),
            'outgoing' => round((float) $outgoing->sum('amount'), 2),
            'incoming' => round((float) $incoming->sum('amount'), 2),
        ];
    }

    private function percentageChange(
        float $previous,
        float $current
    ): ?float {
        if ($previous <= 0) {
            return null;
        }

        return round((($current - $previous) / $previous) * 100, 1);
    }
}
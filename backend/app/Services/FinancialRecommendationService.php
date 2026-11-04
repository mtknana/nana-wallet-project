<?php

namespace App\Services;

use App\Models\Expense;
use App\Models\SavingsGoal;
use App\Models\Transaction;
use App\Models\Wallet;
use Carbon\Carbon;

class FinancialRecommendationService
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
     * Generate personalized, rule-based financial recommendations.
     */
    public function generate(int $userId): array
    {
        $now = Carbon::now();
        $startOfMonth = $now->copy()->startOfMonth();
        $startOfPreviousMonth = $startOfMonth->copy()
            ->subMonthNoOverflow();

        $transactions = Transaction::query()
            ->where('user_id', $userId)
            ->where('status', 'completed')
            ->where('created_at', '>=', $startOfPreviousMonth)
            ->where('created_at', '<', $now->copy()->addSecond())
            ->orderByDesc('created_at')
            ->get([
                'type',
                'amount',
                'currency',
                'description',
                'created_at',
            ]);

        $wallets = Wallet::query()
            ->where('user_id', $userId)
            ->get(['currency', 'balance', 'status']);

        $recommendations = [];

        $currencies = $wallets->pluck('currency')
            ->merge($transactions->pluck('currency'))
            ->filter()
            ->unique()
            ->values();

        foreach ($currencies as $currency) {
            $currencyTransactions = $transactions->filter(
                fn($transaction) =>
                    strtoupper((string) $transaction->currency)
                    === strtoupper((string) $currency)
            );

            $currentTransactions = $currencyTransactions->filter(
                fn($transaction) =>
                    $transaction->created_at >= $startOfMonth
            );

            $previousTransactions = $currencyTransactions->filter(
                fn($transaction) =>
                    $transaction->created_at < $startOfMonth
            );

            $currentSpending = $this->totalOutgoing(
                $currentTransactions
            );

            $previousSpending = $this->totalOutgoing(
                $previousTransactions
            );

            $wallet = $wallets->first(
                fn($item) =>
                    strtoupper((string) $item->currency)
                    === strtoupper((string) $currency)
            );

            $balance = $wallet
                ? (float) $wallet->balance
                : 0.0;

            // Recommendation: spending trend.
            if ($previousSpending > 0) {
                $change = (
                    ($currentSpending - $previousSpending)
                    / $previousSpending
                ) * 100;

                if ($change >= 20) {
                    $recommendations[] = $this->recommendation(
                        'spending_increase',
                        'high',
                        $currency,
                        'Review your spending',
                        sprintf(
                            'Your outgoing transactions are %.1f%% higher than last month. Review recent purchases and consider setting a spending limit.',
                            $change
                        ),
                        'Review your transactions and set a realistic monthly spending limit.'
                    );
                } elseif ($change <= -10) {
                    $recommendations[] = $this->recommendation(
                        'spending_improvement',
                        'positive',
                        $currency,
                        'Good spending progress',
                        sprintf(
                            'Your outgoing transactions are %.1f%% lower than last month. Keep maintaining the habits that work for you.',
                            abs($change)
                        ),
                        'Continue monitoring your spending and keep your budget realistic.'
                    );
                }
            }

            // Recommendation: spending is large compared with balance.
            if (
                $balance > 0
                && $currentSpending >= ($balance * 0.8)
            ) {
                $recommendations[] = $this->recommendation(
                    'balance_awareness',
                    'medium',
                    $currency,
                    'Keep an eye on your wallet balance',
                    'Your spending this month is at least 80% of your current wallet balance. Review upcoming bills before making non-essential purchases.',
                    'Check upcoming payments and keep enough money available for essentials.'
                );
            }

            // Recommendation: no spending recorded this month.
            if (
                $currentTransactions->isEmpty()
                && $previousTransactions->isNotEmpty()
            ) {
                $recommendations[] = $this->recommendation(
                    'activity_check',
                    'low',
                    $currency,
                    'Review your monthly activity',
                    'No completed transactions are recorded for this currency this month. Check your activity to make sure your records are up to date.',
                    'Review your wallet history and confirm that your recent activity is recorded.'
                );
            }
        }

        // Recommendation: active savings goals.
        $goals = SavingsGoal::query()
            ->where('user_id', $userId)
            ->where('status', 'active')
            ->get();

        foreach ($goals as $goal) {
            $target = (float) ($goal->target_amount ?? 0);
            $saved = (float) ($goal->current_amount ?? 0);

            if ($target <= 0) {
                continue;
            }

            $progress = min(100, max(0, ($saved / $target) * 100));

            if ($progress < 50) {
                $recommendations[] = $this->recommendation(
                    'savings_goal',
                    'medium',
                    isset($goal->currency)
                    ? (string) $goal->currency
                    : null,
                    'Keep working toward your savings goal',
                    sprintf(
                        'Your savings goal "%s" is %.1f%% complete. Consider setting aside a manageable amount regularly.',
                        $goal->name ?? 'Savings goal',
                        $progress
                    ),
                    'Choose a regular contribution that fits your budget.'
                );
            } elseif ($progress >= 100) {
                $recommendations[] = $this->recommendation(
                    'savings_goal_completed',
                    'positive',
                    isset($goal->currency)
                    ? (string) $goal->currency
                    : null,
                    'Congratulations on your savings goal',
                    sprintf(
                        'Your savings goal "%s" has reached its target based on the recorded amounts.',
                        $goal->name ?? 'Savings goal'
                    ),
                    'Review the goal and decide whether to maintain it or create a new one.'
                );
            }
        }

        // General advice when no specific rule has triggered.
        if ($recommendations === []) {
            $recommendations[] = $this->recommendation(
                'general_budgeting',
                'low',
                null,
                'Build a consistent saving habit',
                'Track your spending regularly and consider setting a monthly budget for essential and non-essential expenses.',
                'Review your spending at the end of each week and adjust your budget when needed.'
            );
        }

        return [
            'generated_at' => $now->toIso8601String(),
            'period' => [
                'start' => $startOfMonth->toDateString(),
                'end' => $now->toDateString(),
            ],
            'recommendation_count' => count($recommendations),
            'recommendations' => $recommendations,
            'notice' => 'Recommendations are generated from recorded wallet activity and savings goals. They are general guidance, not guaranteed outcomes or professional financial advice.',
        ];
    }

    private function totalOutgoing(iterable $transactions): float
    {
        $total = 0.0;

        foreach ($transactions as $transaction) {
            $type = strtolower((string) $transaction->type);

            if (in_array($type, self::OUTGOING_TYPES, true)) {
                $total += (float) $transaction->amount;
            }
        }

        return round($total, 2);
    }

    private function recommendation(
        string $type,
        string $priority,
        ?string $currency,
        string $title,
        string $message,
        string $suggestedAction
    ): array {
        return [
            'type' => $type,
            'priority' => $priority,
            'currency' => $currency,
            'title' => $title,
            'message' => $message,
            'suggested_action' => $suggestedAction,
        ];
    }
}
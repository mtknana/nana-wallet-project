<?php

namespace App\Services;

use App\Models\Transaction;
use App\Models\Wallet;
use Illuminate\Support\Str;
use App\Models\ChatbotLog;

class FinancialChatbotService
{
    public function __construct(
        private FinancialInsightsService $insightsService,
        private FinancialRecommendationService $recommendationService
    ) {
    }

    /**
     * Generate a wallet-aware response for the authenticated user.
     */

    public function reply(int $userId, string $message): array
    {
        $question = Str::lower(trim($message));

        if ($question === '') {
            $result = $this->response(
                'Please enter a question about your wallet or finances.',
                'empty_message'
            );
        } elseif (
            $this->containsAny($question, [
                'hello',
                'hi',
                'hey',
                'good morning',
                'good afternoon',
                'good evening',
            ])
        ) {
            $result = $this->response(
                'Hello! I am your NaNa Wallet assistant. You can ask about your wallet balance, spending, predictions, savings goals, or ways to manage your money.',
                'greeting'
            );
        } elseif (
            $this->containsAny($question, [
                'balance',
                'how much money',
                'wallet amount',
                'my wallets',
            ])
        ) {
            $result = $this->walletBalance($userId);
        } elseif (
            $this->containsAny($question, [
                'recommend',
                'recommendation',
                'save more',
                'saving advice',
                'how can i save',
                'financial advice',
                'spend less',
            ])
        ) {
            $result = $this->recommendations($userId);
        } elseif (
            $this->containsAny($question, [
                'predict',
                'prediction',
                'forecast',
                'next month',
                'spending estimate',
            ])
        ) {
            $result = $this->spendingPrediction($userId);
        } elseif (
            $this->containsAny($question, [
                'spending',
                'spent',
                'expenses',
                'expense',
                'transactions',
                'how much did i',
            ])
        ) {
            $result = $this->spendingSummary($userId);
        } elseif (
            $this->containsAny($question, [
                'savings goal',
                'saving goal',
                'savings goals',
                'goal progress',
            ])
        ) {
            $result = $this->savingsGoals($userId);
        } else {
            $result = $this->response(
                'I can help with wallet balances, spending summaries, spending predictions, savings goals, and financial recommendations. Try asking, "How much did I spend this month?"',
                'help'
            );
        }

        try {
            ChatbotLog::create([
                'user_id' => $userId,
                'message' => $this->redactSensitiveText($message),
                'intent' => $result['intent'] ?? 'unknown',
                'status' => 'success',
            ]);
        } catch (\Throwable $exception) {
            // Logging failures should not expose internal details or
            // prevent the user from receiving a chatbot response.
            report($exception);
        }

        return $result;
    }

    private function redactSensitiveText(string $message): string
    {
        $message = preg_replace(
            '/\b(pin|password|passcode|otp|verification code)\s*[:=]?\s*\S+/i',
            '$1: [REDACTED]',
            $message
        ) ?? $message;

        return mb_substr($message, 0, 2000);
    }

    private function walletBalance(int $userId): array
    {
        $wallets = Wallet::query()
            ->where('user_id', $userId)
            ->get(['currency', 'balance', 'status']);

        if ($wallets->isEmpty()) {
            return $this->response(
                'I could not find any wallets for your account.',
                'wallet_balance'
            );
        }

        $lines = $wallets->map(function ($wallet) {
            return sprintf(
                '%s: %s %s (%s)',
                $wallet->currency,
                number_format((float) $wallet->balance, 2),
                $wallet->currency,
                $wallet->status
            );
        })->implode("\n");

        return $this->response(
            "Here are your current wallet balances:\n" . $lines,
            'wallet_balance',
            [
                'wallets' => $wallets->map(fn($wallet) => [
                    'currency' => $wallet->currency,
                    'balance' => (float) $wallet->balance,
                    'status' => $wallet->status,
                ])->values()->all()
            ]
        );
    }

    private function spendingSummary(int $userId): array
    {
        $data = $this->insightsService->generate($userId);
        $summaries = $data['currency_summaries'] ?? [];

        if ($summaries === []) {
            return $this->response(
                'There is not enough transaction information to summarize your spending yet.',
                'spending_summary'
            );
        }

        $lines = [];

        foreach ($summaries as $currency => $summary) {
            $current = $summary['current_month']['outgoing'] ?? 0;
            $previous = $summary['previous_month']['outgoing'] ?? 0;

            $lines[] = sprintf(
                '%s: %s %s spent this month; %s %s last month.',
                $currency,
                number_format((float) $current, 2),
                $currency,
                number_format((float) $previous, 2),
                $currency
            );
        }

        return $this->response(
            "Here is your spending summary:\n" . implode("\n", $lines),
            'spending_summary',
            ['currency_summaries' => $summaries]
        );
    }

    private function spendingPrediction(int $userId): array
    {
        $data = $this->insightsService->generate($userId);
        $predictions = $data['spending_predictions'] ?? [];

        if ($predictions === []) {
            return $this->response(
                'There is not enough transaction history to estimate next month’s spending.',
                'spending_prediction'
            );
        }

        $lines = [];

        foreach ($predictions as $currency => $prediction) {
            $amount = $prediction['projected_spending'] ?? null;

            if ($amount === null) {
                $lines[] = $currency
                    . ': not enough data to make a reliable estimate.';
                continue;
            }

            $lines[] = sprintf(
                '%s: approximately %s %s, with %s confidence.',
                $currency,
                number_format((float) $amount, 2),
                $currency,
                $prediction['confidence'] ?? 'unknown'
            );
        }

        return $this->response(
            "Here is your estimated spending for next month:\n"
            . implode("\n", $lines)
            . "\nThese are estimates, not guarantees.",
            'spending_prediction',
            ['spending_predictions' => $predictions]
        );
    }

    private function recommendations(int $userId): array
    {
        $data = $this->recommendationService->generate($userId);
        $recommendations = $data['recommendations'] ?? [];

        if ($recommendations === []) {
            return $this->response(
                'I do not have enough information to create a personalized recommendation yet. Try recording your wallet activity and savings goals.',
                'recommendations'
            );
        }

        $lines = [];

        foreach (array_slice($recommendations, 0, 5) as $item) {
            $lines[] = ($item['title'] ?? 'Recommendation')
                . ': '
                . ($item['message'] ?? '');
        }

        return $this->response(
            "Here are some recommendations for you:\n"
            . implode("\n", $lines),
            'recommendations',
            ['recommendations' => $recommendations]
        );
    }

    private function savingsGoals(int $userId): array
    {
        $goals = \App\Models\SavingsGoal::query()
            ->where('user_id', $userId)
            ->where('status', 'active')
            ->get();

        if ($goals->isEmpty()) {
            return $this->response(
                'You do not currently have any active savings goals. Consider creating one for something important to you.',
                'savings_goals'
            );
        }

        $lines = $goals->map(function ($goal) {
            $target = (float) ($goal->target_amount ?? 0);
            $saved = (float) ($goal->current_amount ?? 0);

            $progress = $target > 0
                ? min(100, max(0, ($saved / $target) * 100))
                : 0;

            return sprintf(
                '%s: %s of %s saved (%.1f%%).',
                $goal->name ?? 'Savings goal',
                number_format($saved, 2),
                number_format($target, 2),
                $progress
            );
        })->implode("\n");

        return $this->response(
            "Here is your active savings-goal progress:\n" . $lines,
            'savings_goals',
            ['savings_goals' => $goals->values()->toArray()]
        );
    }

    private function containsAny(string $question, array $phrases): bool
    {
        foreach ($phrases as $phrase) {
            if (Str::contains($question, $phrase)) {
                return true;
            }
        }

        return false;
    }

    private function response(
        string $message,
        string $intent,
        array $data = []
    ): array {
        return [
            'message' => $message,
            'intent' => $intent,
            'data' => $data,
        ];
    }
}
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SpendingPredictionController extends Controller
{
    /**
     * US-086 — AI Spending Prediction.
     *
     * Uses recent spending history to estimate
     * the user's spending by the end of this month.
     */
    public function predict(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'currency' => [
                'nullable',
                'in:USD,KHR',
            ],
        ]);

        $user = $request->user();
        $currency = $validated['currency'] ?? 'USD';

        $today = Carbon::today();
        $monthStart = $today->copy()->startOfMonth();
        $monthEnd = $today->copy()->endOfMonth();

        // Use the last 90 days as historical data.
        $historyStart = $today->copy()->subDays(89);

        $expenses = Expense::query()
            ->where('user_id', $user->id)
            ->where('currency', $currency)
            ->whereDate('expense_date', '>=', $historyStart)
            ->whereDate('expense_date', '<=', $today)
            ->get();

        $currentMonthExpenses = $expenses->filter(
            fn($expense) =>
                Carbon::parse($expense->expense_date)
                    ->betweenIncluded($monthStart, $today)
        );

        $spentSoFar = (float) $currentMonthExpenses->sum('amount');

        $daysElapsed = max(1, $today->day);
        $daysInMonth = $monthEnd->day;
        $daysRemaining = max(0, $daysInMonth - $today->day);

        // Average daily spending from this month's recorded expenses.
        $dailyAverage = $spentSoFar / $daysElapsed;

        // Estimate spending by month-end.
        $predictedTotal = $dailyAverage * $daysInMonth;

        // Historical daily average across the previous 90 days.
        $historicalTotal = (float) $expenses->sum('amount');
        $historicalDays = max(
            1,
            $historyStart->diffInDays($today) + 1
        );

        $historicalDailyAverage = $historicalTotal / $historicalDays;

        // Avoid presenting a zero prediction as certain when no
        // expenses have been recorded this month.
        $hasCurrentMonthData = $currentMonthExpenses->isNotEmpty();

        if (!$hasCurrentMonthData && $historicalTotal > 0) {
            $predictedTotal = $historicalDailyAverage * $daysInMonth;
        }

        $byCategory = $currentMonthExpenses
            ->groupBy('category')
            ->map(fn($items) => round(
                (float) $items->sum('amount'),
                2
            ));

        return response()->json([
            'status' => 'success',
            'message' => 'Spending prediction generated successfully.',
            'data' => [
                'currency' => $currency,
                'period' => [
                    'start_date' => $monthStart->toDateString(),
                    'end_date' => $monthEnd->toDateString(),
                    'as_of_date' => $today->toDateString(),
                ],
                'spent_so_far' => round($spentSoFar, 2),
                'predicted_monthly_total' => round(
                    $predictedTotal,
                    2
                ),
                'average_daily_spending' => round(
                    $dailyAverage,
                    2
                ),
                'historical_daily_average' => round(
                    $historicalDailyAverage,
                    2
                ),
                'days_remaining' => $daysRemaining,
                'by_category' => $byCategory,
                'has_current_month_data' => $hasCurrentMonthData,
                'prediction_method' => 'daily_average',
                'disclaimer' => 'This is an estimate based on recorded expenses, not a guarantee of future spending.',
            ],
        ]);
    }
}
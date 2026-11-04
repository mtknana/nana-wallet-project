<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SavingsGoal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SavingsGoalController extends Controller
{
    /**
     * Display the authenticated user's savings goals.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = SavingsGoal::where('user_id', $user->id)
            ->orderByRaw("
                CASE
                    WHEN status = 'active' THEN 1
                    WHEN status = 'completed' THEN 2
                    ELSE 3
                END
            ")
            ->orderBy('target_date');

        if ($request->filled('status')) {
            $query->where(
                'status',
                $request->input('status')
            );
        }

        if ($request->filled('currency')) {
            $query->where(
                'currency',
                $request->input('currency')
            );
        }

        $goals = $query->get();

        return response()->json([
            'success' => true,
            'goals' => $goals->map(
                fn(SavingsGoal $goal) => $this->formatGoal($goal)
            )->values(),
        ]);
    }

    /**
     * Create a new savings goal.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => [
                'required',
                'string',
                'max:255',
            ],

            'description' => [
                'nullable',
                'string',
                'max:255',
            ],

            'target_amount' => [
                'required',
                'numeric',
                'min:0.01',
            ],

            'current_amount' => [
                'nullable',
                'numeric',
                'min:0',
            ],

            'currency' => [
                'required',
                Rule::in(['USD', 'KHR']),
            ],

            'target_date' => [
                'nullable',
                'date',
            ],
        ]);

        $currentAmount = (float) (
            $validated['current_amount'] ?? 0
        );

        $targetAmount = (float) $validated['target_amount'];

        $status = $currentAmount >= $targetAmount
            ? 'completed'
            : 'active';

        $goal = SavingsGoal::create([
            'user_id' => $request->user()->id,
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'target_amount' => $targetAmount,
            'current_amount' => $currentAmount,
            'currency' => $validated['currency'],
            'target_date' => $validated['target_date'] ?? null,
            'status' => $status,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Savings goal created successfully.',
            'goal' => $this->formatGoal($goal),
        ], 201);
    }

    /**
     * Display one savings goal.
     */
    public function show(
        Request $request,
        int $id
    ): JsonResponse {
        $goal = SavingsGoal::where('user_id', $request->user()->id)
            ->findOrFail($id);

        return response()->json([
            'success' => true,
            'goal' => $this->formatGoal($goal),
        ]);
    }

    /**
     * Update a savings goal.
     */
    public function update(
        Request $request,
        int $id
    ): JsonResponse {
        $goal = SavingsGoal::where('user_id', $request->user()->id)
            ->findOrFail($id);

        $validated = $request->validate([
            'name' => [
                'sometimes',
                'required',
                'string',
                'max:255',
            ],

            'description' => [
                'sometimes',
                'nullable',
                'string',
                'max:255',
            ],

            'target_amount' => [
                'sometimes',
                'required',
                'numeric',
                'min:0.01',
            ],

            'current_amount' => [
                'sometimes',
                'required',
                'numeric',
                'min:0',
            ],

            'currency' => [
                'sometimes',
                'required',
                Rule::in(['USD', 'KHR']),
            ],

            'target_date' => [
                'sometimes',
                'nullable',
                'date',
            ],

            'status' => [
                'sometimes',
                'required',
                Rule::in([
                    'active',
                    'completed',
                    'cancelled',
                ]),
            ],
        ]);

        $goal->fill($validated);

        /*
         * Automatically mark the goal as completed
         * when the current amount reaches the target.
         */
        if (
            $goal->status !== 'cancelled' &&
            (float) $goal->current_amount >=
            (float) $goal->target_amount
        ) {
            $goal->status = 'completed';
        } elseif (
            $goal->status === 'completed' &&
            (float) $goal->current_amount <
            (float) $goal->target_amount
        ) {
            $goal->status = 'active';
        }

        $goal->save();

        return response()->json([
            'success' => true,
            'message' => 'Savings goal updated successfully.',
            'goal' => $this->formatGoal($goal),
        ]);
    }

    /**
     * Add money to a savings goal.
     *
     * This only updates the tracking amount.
     * It does NOT deduct money from the wallet.
     */
    public function contribute(
        Request $request,
        int $id
    ): JsonResponse {
        $goal = SavingsGoal::where('user_id', $request->user()->id)
            ->findOrFail($id);

        $validated = $request->validate([
            'amount' => [
                'required',
                'numeric',
                'min:0.01',
            ],
        ]);

        if ($goal->status === 'cancelled') {
            return response()->json([
                'success' => false,
                'message' => 'Cancelled savings goals cannot receive contributions.',
            ], 422);
        }

        $newAmount =
            (float) $goal->current_amount +
            (float) $validated['amount'];

        $goal->current_amount = $newAmount;

        if (
            $newAmount >=
            (float) $goal->target_amount
        ) {
            $goal->status = 'completed';
        } else {
            $goal->status = 'active';
        }

        $goal->save();

        return response()->json([
            'success' => true,
            'message' => 'Savings contribution added successfully.',
            'goal' => $this->formatGoal($goal),
        ]);
    }

    /**
     * Cancel a savings goal.
     */
    public function cancel(
        Request $request,
        int $id
    ): JsonResponse {
        $goal = SavingsGoal::where('user_id', $request->user()->id)
            ->findOrFail($id);

        if ($goal->status === 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'Completed savings goals cannot be cancelled.',
            ], 422);
        }

        $goal->status = 'cancelled';
        $goal->save();

        return response()->json([
            'success' => true,
            'message' => 'Savings goal cancelled successfully.',
            'goal' => $this->formatGoal($goal),
        ]);
    }

    /**
     * Delete a savings goal.
     */
    public function destroy(
        Request $request,
        int $id
    ): JsonResponse {
        $goal = SavingsGoal::where('user_id', $request->user()->id)
            ->findOrFail($id);

        $goal->delete();

        return response()->json([
            'success' => true,
            'message' => 'Savings goal deleted successfully.',
        ]);
    }

    /**
     * Savings goal summary.
     */
    public function summary(Request $request): JsonResponse
    {
        $goals = SavingsGoal::where(
            'user_id',
            $request->user()->id
        )->get();

        $activeGoals = $goals->where('status', 'active');
        $completedGoals = $goals->where('status', 'completed');
        $cancelledGoals = $goals->where('status', 'cancelled');

        $usd = $goals->where('currency', 'USD');
        $khr = $goals->where('currency', 'KHR');

        $usdTarget = $usd->sum(
            fn($goal) => (float) $goal->target_amount
        );

        $usdSaved = $usd->sum(
            fn($goal) => (float) $goal->current_amount
        );

        $khrTarget = $khr->sum(
            fn($goal) => (float) $goal->target_amount
        );

        $khrSaved = $khr->sum(
            fn($goal) => (float) $goal->current_amount
        );

        return response()->json([
            'success' => true,

            'summary' => [
                'total_goals' => $goals->count(),
                'active_goals' => $activeGoals->count(),
                'completed_goals' => $completedGoals->count(),
                'cancelled_goals' => $cancelledGoals->count(),

                'usd' => [
                    'target_amount' => round($usdTarget, 2),
                    'saved_amount' => round($usdSaved, 2),
                    'remaining_amount' => round(
                        max(0, $usdTarget - $usdSaved),
                        2
                    ),
                ],

                'khr' => [
                    'target_amount' => round($khrTarget, 2),
                    'saved_amount' => round($khrSaved, 2),
                    'remaining_amount' => round(
                        max(0, $khrTarget - $khrSaved),
                        2
                    ),
                ],
            ],
        ]);
    }

    /**
     * Format a savings goal for the API.
     */
    private function formatGoal(
        SavingsGoal $goal
    ): array {
        return [
            'id' => $goal->id,
            'user_id' => $goal->user_id,
            'name' => $goal->name,
            'description' => $goal->description,

            'target_amount' =>
                (float) $goal->target_amount,

            'current_amount' =>
                (float) $goal->current_amount,

            'remaining_amount' =>
                $goal->remaining_amount,

            'progress_percentage' =>
                $goal->progress_percentage,

            'currency' => $goal->currency,

            'target_date' =>
                $goal->target_date?->format('Y-m-d'),

            'status' => $goal->status,

            'is_completed' =>
                $goal->is_completed,

            'created_at' =>
                $goal->created_at?->toISOString(),

            'updated_at' =>
                $goal->updated_at?->toISOString(),
        ];
    }
}
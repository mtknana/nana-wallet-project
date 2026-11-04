<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ExpenseController extends Controller
{
    /**
     * Display the user's expenses.
     *
     * US-074 — Daily Expense Tracker
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'category' => [
                'nullable',
                Rule::in([
                    'food',
                    'transport',
                    'study',
                    'other',
                ]),
            ],

            'currency' => [
                'nullable',
                Rule::in([
                    'USD',
                    'KHR',
                ]),
            ],

            'start_date' => [
                'nullable',
                'date',
            ],

            'end_date' => [
                'nullable',
                'date',
                'after_or_equal:start_date',
            ],

            'per_page' => [
                'nullable',
                'integer',
                'min:1',
                'max:100',
            ],
        ]);

        $query = Expense::query()
            ->where('user_id', $user->id);

        if (!empty($validated['category'])) {
            $query->where('category', $validated['category']);
        }

        if (!empty($validated['currency'])) {
            $query->where('currency', $validated['currency']);
        }

        if (!empty($validated['start_date'])) {
            $query->whereDate(
                'expense_date',
                '>=',
                $validated['start_date']
            );
        }

        if (!empty($validated['end_date'])) {
            $query->whereDate(
                'expense_date',
                '<=',
                $validated['end_date']
            );
        }

        $expenses = $query
            ->latest('expense_date')
            ->latest('id')
            ->paginate($validated['per_page'] ?? 20);

        return response()->json([
            'status' => 'success',
            'message' => 'Expenses retrieved successfully.',
            'data' => $expenses,
        ]);
    }

    /**
     * Store a new expense.
     *
     * US-074 — Daily Expense Tracker
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'category' => [
                'required',
                Rule::in([
                    'food',
                    'transport',
                    'study',
                    'other',
                ]),
            ],

            'amount' => [
                'required',
                'numeric',
                'gt:0',
                'max:999999999999.99',
            ],

            'currency' => [
                'required',
                Rule::in([
                    'USD',
                    'KHR',
                ]),
            ],

            'description' => [
                'nullable',
                'string',
                'max:255',
            ],

            'expense_date' => [
                'required',
                'date',
            ],
        ]);

        $expense = Expense::create([
            'user_id' => $user->id,
            'category' => $validated['category'],
            'amount' => $validated['amount'],
            'currency' => $validated['currency'],
            'description' => $validated['description'] ?? null,
            'expense_date' => $validated['expense_date'],
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Expense added successfully.',
            'data' => $expense,
        ], 201);
    }

    /**
     * Display one expense.
     *
     * US-074 — Daily Expense Tracker
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $expense = Expense::query()
            ->where('user_id', $request->user()->id)
            ->findOrFail($id);

        return response()->json([
            'status' => 'success',
            'message' => 'Expense retrieved successfully.',
            'data' => $expense,
        ]);
    }

    /**
     * Update an expense.
     *
     * US-074 — Daily Expense Tracker
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $expense = Expense::query()
            ->where('user_id', $request->user()->id)
            ->findOrFail($id);

        $validated = $request->validate([
            'category' => [
                'sometimes',
                'required',
                Rule::in([
                    'food',
                    'transport',
                    'study',
                    'other',
                ]),
            ],

            'amount' => [
                'sometimes',
                'required',
                'numeric',
                'gt:0',
                'max:999999999999.99',
            ],

            'currency' => [
                'sometimes',
                'required',
                Rule::in([
                    'USD',
                    'KHR',
                ]),
            ],

            'description' => [
                'sometimes',
                'nullable',
                'string',
                'max:255',
            ],

            'expense_date' => [
                'sometimes',
                'required',
                'date',
            ],
        ]);

        $expense->update($validated);

        return response()->json([
            'status' => 'success',
            'message' => 'Expense updated successfully.',
            'data' => $expense->fresh(),
        ]);
    }

    /**
     * Delete an expense.
     *
     * US-074 — Daily Expense Tracker
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $expense = Expense::query()
            ->where('user_id', $request->user()->id)
            ->findOrFail($id);

        $expense->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Expense deleted successfully.',
        ]);
    }

    /**
     * Return expense summary.
     *
     * US-074 — Daily Expense Tracker
     */
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'start_date' => [
                'nullable',
                'date',
            ],

            'end_date' => [
                'nullable',
                'date',
                'after_or_equal:start_date',
            ],
        ]);

        $query = Expense::query()
            ->where('user_id', $user->id);

        if (!empty($validated['start_date'])) {
            $query->whereDate(
                'expense_date',
                '>=',
                $validated['start_date']
            );
        }

        if (!empty($validated['end_date'])) {
            $query->whereDate(
                'expense_date',
                '<=',
                $validated['end_date']
            );
        }

        $expenses = $query->get();

        $usdTotal = $expenses
            ->where('currency', 'USD')
            ->sum('amount');

        $khrTotal = $expenses
            ->where('currency', 'KHR')
            ->sum('amount');

        $byCategory = [];

        foreach ([
            'food',
            'transport',
            'study',
            'other',
        ] as $category) {
            $categoryExpenses = $expenses->where(
                'category',
                $category
            );

            $byCategory[$category] = [
                'USD' => (float) $categoryExpenses
                    ->where('currency', 'USD')
                    ->sum('amount'),

                'KHR' => (float) $categoryExpenses
                    ->where('currency', 'KHR')
                    ->sum('amount'),

                'count' => $categoryExpenses->count(),
            ];
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Expense summary retrieved successfully.',
            'data' => [
                'total_records' => $expenses->count(),

                'total_usd' => (float) $usdTotal,

                'total_khr' => (float) $khrTotal,

                'by_category' => $byCategory,
            ],
        ]);
    }
}
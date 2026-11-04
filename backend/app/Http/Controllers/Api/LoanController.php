<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Loan;
use App\Services\LoanService;
use App\Services\LoanRepaymentService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class LoanController extends Controller
{
    public function index(Request $request)
    {
        $loans = Loan::where('user_id', $request->user()->id)
            ->with('repayments')
            ->latest()
            ->paginate(10);

        return response()->json([
            'success' => true,
            'message' => 'Loan history retrieved successfully.',
            'data' => $loans,
        ]);
    }

    public function store(Request $request, LoanService $loanService)
    {
        $validator = Validator::make($request->all(), [
            'amount' => ['required', 'numeric', 'gt:0'],
            'currency' => ['required', 'string', 'size:3'],
            'term_days' => ['required', 'integer', 'in:7,14,30'],
            'idempotency_key' => ['required', 'string', 'max:100'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Please check your loan application details.',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $loan = $loanService->apply(
                $request->user(),
                $validator->validated()
            );

            return response()->json([
                'success' => true,
                'message' => 'Your NaNa Quick Loan has been approved.',
                'data' => $loan,
            ], 201);

        } catch (ValidationException $exception) {
            throw $exception;
        }
    }

    public function show(Request $request, string $id)
    {
        $loan = Loan::where('user_id', $request->user()->id)
            ->with('repayments')
            ->findOrFail($id);

        return response()->json([
            'success' => true,
            'message' => 'Loan details retrieved successfully.',
            'data' => $loan,
        ]);
    }

    /**
     * Manually repay a loan before or after its due date.
     */
    public function repay(
        Request $request,
        string $id,
        LoanRepaymentService $repaymentService
    ) {
        $validator = Validator::make($request->all(), [
            'amount' => ['required', 'numeric', 'gt:0'],
            'idempotency_key' => ['required', 'string', 'min:1', 'max:100'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Please enter a valid repayment amount and request key.',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $loan = $repaymentService->repayManually(
                (int) $id,
                (int) $request->user()->id,
                (string) $validator->validated()['amount'],
                (string) $validator->validated()['idempotency_key']
            );

            return response()->json([
                'success' => true,
                'message' => 'Loan repayment completed successfully.',
                'data' => $loan,
            ]);

        } catch (ValidationException $exception) {
            throw $exception;
        }
    }
}
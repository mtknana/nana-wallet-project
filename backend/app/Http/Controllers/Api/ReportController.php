<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ReportService;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    protected ReportService $reportService;

    public function __construct(
        ReportService $reportService
    ) {
        $this->reportService =
            $reportService;
    }

    // ============================================================
    // US-059 — DAILY TRANSACTION REPORT
    // ============================================================

    public function daily(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $user =
            $request->user();

        $report =
            $this->reportService->dailyReport(
                $user,
                $validated['date']
                ?? null,
                $validated['currency']
                ?? null
            );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Daily transaction report generated successfully.',

            'report' =>
                $report,
        ], 200);
    }

    // ============================================================
    // US-060 — WEEKLY TRANSACTION REPORT
    // ============================================================

    public function weekly(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $user =
            $request->user();

        $report =
            $this->reportService->weeklyReport(
                $user,
                $validated['date']
                ?? null,
                $validated['currency']
                ?? null
            );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Weekly transaction report generated successfully.',

            'report' =>
                $report,
        ], 200);
    }

    // ============================================================
    // US-061 — MONTHLY TRANSACTION REPORT
    // ============================================================

    public function monthly(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $user =
            $request->user();

        $report =
            $this->reportService->monthlyReport(
                $user,
                $validated['date']
                ?? null,
                $validated['currency']
                ?? null
            );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Monthly transaction report generated successfully.',

            'report' =>
                $report,
        ], 200);
    }
    // ============================================================
    // US-062 — USER REPORT
    // ============================================================

    public function userReport(
        Request $request
    ) {
        $user =
            $request->user();

        $report =
            $this->reportService->userReport(
                $user
            );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'User report generated successfully.',

            'report' =>
                $report,
        ], 200);
    }


    // ============================================================
    // US-063 — WALLET BALANCE REPORT
    // ============================================================

    public function walletBalanceReport(
        Request $request
    ) {
        $user =
            $request->user();

        $report =
            $this->reportService
                ->walletBalanceReport(
                    $user
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Wallet balance report generated successfully.',

            'report' =>
                $report,
        ], 200);
    }


    // ============================================================
    // US-064 — PAYMENT REPORT
    // ============================================================

    public function paymentReport(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $user =
            $request->user();

        $report =
            $this->reportService
                ->paymentReport(
                    $user,
                    $validated['date']
                    ?? null,
                    $validated['currency']
                    ?? null
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Payment report generated successfully.',

            'report' =>
                $report,
        ], 200);
    }


    // ============================================================
    // US-065 — TRANSFER REPORT
    // ============================================================

    public function transferReport(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $user =
            $request->user();

        $report =
            $this->reportService
                ->transferReport(
                    $user,
                    $validated['date']
                    ?? null,
                    $validated['currency']
                    ?? null
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Transfer report generated successfully.',

            'report' =>
                $report,
        ], 200);
    }


    // ============================================================
    // US-066 — REVENUE REPORT
    // ============================================================

    public function revenueReport(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $user =
            $request->user();

        $report =
            $this->reportService
                ->revenueReport(
                    $user,
                    $validated['date']
                    ?? null,
                    $validated['currency']
                    ?? null
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Revenue report generated successfully.',

            'report' =>
                $report,
        ], 200);
    }
    // ============================================================
    // US-067 — TRANSACTION ANALYTICS
    // ============================================================

    public function transactionAnalytics(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $report =
            $this->reportService
                ->transactionAnalytics(
                    $request->user(),
                    $validated['date']
                    ?? null,
                    $validated['currency']
                    ?? null
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Transaction analytics generated successfully.',

            'report' =>
                $report,
        ], 200);
    }


    // ============================================================
    // US-068 — SPENDING ANALYSIS
    // ============================================================

    public function spendingAnalysis(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $report =
            $this->reportService
                ->spendingAnalysis(
                    $request->user(),
                    $validated['date']
                    ?? null,
                    $validated['currency']
                    ?? null
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Spending analysis generated successfully.',

            'report' =>
                $report,
        ], 200);
    }


    // ============================================================
    // US-069 — INCOME SUMMARY
    // ============================================================

    public function incomeSummary(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $report =
            $this->reportService
                ->incomeSummary(
                    $request->user(),
                    $validated['date']
                    ?? null,
                    $validated['currency']
                    ?? null
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Income summary generated successfully.',

            'report' =>
                $report,
        ], 200);
    }


    // ============================================================
    // US-070 — EXPENSE SUMMARY
    // ============================================================

    public function expenseSummary(
        Request $request
    ) {
        $validated =
            $request->validate([
                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $report =
            $this->reportService
                ->expenseSummary(
                    $request->user(),
                    $validated['date']
                    ?? null,
                    $validated['currency']
                    ?? null
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Expense summary generated successfully.',

            'report' =>
                $report,
        ], 200);
    }
    // ============================================================
    // US-072 — EXPORT REPORT
    // ============================================================

    public function export(
        Request $request
    ) {
        $validated =
            $request->validate([
                'type' =>
                    'nullable|string|in:
                daily,
                weekly,
                monthly,
                transactions,
                payment,
                payments,
                transfer,
                transfers,
                revenue,
                spending,
                income,
                expense,
                expenses',

                'date' =>
                    'nullable|date',

                'currency' =>
                    'nullable|string|in:USD,KHR',
            ]);

        $reportType =
            strtolower(
                trim(
                    $validated['type']
                    ?? 'monthly'
                )
            );

        $date =
            $validated['date']
            ?? null;

        $currency =
            $validated['currency']
            ?? null;

        $transactions =
            $this->reportService
                ->exportReport(
                    $request->user(),
                    $reportType,
                    $date,
                    $currency
                );

        $fileName =
            'nana_' .
            $reportType .
            '_report_' .
            now()->format('Y-m-d_H-i-s') .
            '.csv';

        return response()->streamDownload(
            function () use ($transactions) {

                $handle =
                    fopen(
                        'php://output',
                        'w'
                    );

                /*
                |--------------------------------------------------------------------------
                | CSV Header
                |--------------------------------------------------------------------------
                */

                fputcsv(
                    $handle,
                    [
                        'Transaction ID',
                        'Transaction Type',
                        'Amount',
                        'Fee',
                        'Currency',
                        'Description',
                        'Reference ID',
                        'Status',
                        'Idempotency Key',
                        'Wallet ID',
                        'Created At',
                        'Updated At',
                    ]
                );

                /*
                |--------------------------------------------------------------------------
                | Transaction Rows
                |--------------------------------------------------------------------------
                */

                foreach ($transactions as $transaction) {

                    fputcsv(
                        $handle,
                        [
                            $transaction->id,

                            $transaction->type,

                            number_format(
                                (float) $transaction->amount,
                                2,
                                '.',
                                ''
                            ),

                            number_format(
                                (float) $transaction->fee_charged,
                                2,
                                '.',
                                ''
                            ),

                            $transaction->currency,

                            $transaction->description,

                            $transaction->reference_id,

                            $transaction->status,

                            $transaction->idempotency_key,

                            $transaction->wallet_id,

                            $transaction->created_at,

                            $transaction->updated_at,
                        ]
                    );
                }

                fclose($handle);
            },

            $fileName,

            [
                'Content-Type' =>
                    'text/csv; charset=UTF-8',

                'Content-Disposition' =>
                    'attachment; filename="' .
                    $fileName .
                    '"',
            ]
        );
    }
    // ============================================================
// US-073 — REPORT FILTER
// ============================================================

    public function filter(
        Request $request
    ) {
        $validated =
            $request->validate([
                'start_date' =>
                    'nullable|date',

                'end_date' =>
                    'nullable|date|after_or_equal:start_date',

                'currency' =>
                    'nullable|string|in:USD,KHR',

                'type' =>
                    'nullable|string|in:withdrawal,deposit,payment,bill_payment,mobile_topup,transfer_out,transfer_in,fee_income,refund,fee_reversal',

                'status' =>
                    'nullable|string|in:pending,completed,failed,cancelled',

                'search' =>
                    'nullable|string|max:100',

                'per_page' =>
                    'nullable|integer|min:1|max:100',
            ]);

        $transactions =
            $this->reportService
                ->filteredTransactions(
                    $request->user(),

                    $validated['start_date']
                    ?? null,

                    $validated['end_date']
                    ?? null,

                    $validated['currency']
                    ?? null,

                    $validated['type']
                    ?? null,

                    $validated['status']
                    ?? null,

                    $validated['search']
                    ?? null,

                    (int) (
                        $validated['per_page']
                        ?? 20
                    )
                );

        return response()->json([
            'status' =>
                'success',

            'message' =>
                'Filtered transaction report generated successfully.',

            'filters' => [
                'start_date' =>
                    $validated['start_date']
                    ?? null,

                'end_date' =>
                    $validated['end_date']
                    ?? null,

                'currency' =>
                    $validated['currency']
                    ?? 'ALL',

                'type' =>
                    $validated['type']
                    ?? 'ALL',

                'status' =>
                    $validated['status']
                    ?? 'ALL',

                'search' =>
                    $validated['search']
                    ?? null,
            ],

            'data' =>
                $transactions,
        ], 200);
    }
}
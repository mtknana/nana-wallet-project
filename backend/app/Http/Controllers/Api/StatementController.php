<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class StatementController extends Controller
{
    // ============================================================
    // US-075-A: DOWNLOAD PDF STATEMENT
    // ============================================================

    public function downloadPdf(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'currency' => [
                'nullable',
                'string',
                'in:USD,KHR',
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
        ]);

        $currency = strtoupper(
            $validated['currency'] ?? 'USD'
        );

        $startDate = isset($validated['start_date'])
            ? Carbon::parse($validated['start_date'])->startOfDay()
            : Carbon::now()->startOfMonth();

        $endDate = isset($validated['end_date'])
            ? Carbon::parse($validated['end_date'])->endOfDay()
            : Carbon::now()->endOfDay();

        // --------------------------------------------------------
        // Retrieve only the authenticated user's transactions.
        // --------------------------------------------------------

        $transactions = Transaction::where(
            'user_id',
            $user->id
        )
            ->where(
                'currency',
                $currency
            )
            ->whereBetween(
                'created_at',
                [
                    $startDate,
                    $endDate,
                ]
            )
            ->orderBy(
                'created_at',
                'asc'
            )
            ->get();

        // --------------------------------------------------------
        // Calculate statement summary.
        // --------------------------------------------------------

        $totalCredits = 0.00;
        $totalDebits = 0.00;
        $totalFees = 0.00;

        foreach ($transactions as $transaction) {
            $type = strtolower(
                (string) $transaction->type
            );

            $amount = (float) $transaction->amount;
            $fee = (float) (
                $transaction->fee_charged ?? 0
            );

            $isDebit = in_array(
                $type,
                [
                    'withdrawal',
                    'bill_payment',
                    'mobile_topup',
                    'transfer_out',
                    'payment',
                ],
                true
            );

            if ($isDebit) {
                $totalDebits += $amount;
            } else {
                $totalCredits += $amount;
            }

            $totalFees += $fee;
        }

        $netChange =
            $totalCredits -
            $totalDebits -
            $totalFees;

        // --------------------------------------------------------
        // Generate PDF using the Blade statement template.
        // --------------------------------------------------------

        $pdf = Pdf::loadView(
            'statements.pdf',
            [
                'user' => $user,
                'transactions' => $transactions,
                'currency' => $currency,
                'startDate' => $startDate,
                'endDate' => $endDate,
                'totalCredits' => $totalCredits,
                'totalDebits' => $totalDebits,
                'totalFees' => $totalFees,
                'netChange' => $netChange,
            ]
        );

        $pdf->setPaper(
            'a4',
            'portrait'
        );

        $fileName =
            'NaNa-Wallet-Statement-' .
            $currency .
            '-' .
            $startDate->format('Ymd') .
            '-' .
            $endDate->format('Ymd') .
            '.pdf';

        return $pdf->download($fileName);
    }
}
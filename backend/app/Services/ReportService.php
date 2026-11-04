<?php

namespace App\Services;

use App\Models\Transaction;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;

class ReportService
{
    // ============================================================
    // BASE TRANSACTION QUERY
    // ============================================================

    /**
     * Get the authenticated user's transaction query.
     */
    private function userTransactionQuery(
        User $user
    ): Builder {
        return Transaction::query()
            ->where(
                'user_id',
                $user->id
            );
    }

    // ============================================================
    // DATE RANGE HELPERS
    // ============================================================

    /**
     * Build a date range from the requested period.
     *
     * Supported periods:
     * - daily
     * - weekly
     * - monthly
     */
    private function resolveDateRange(
        string $period,
        ?string $date = null
    ): array {
        $period =
            strtolower(
                trim($period)
            );

        $baseDate = $date
            ? Carbon::parse($date)
            : Carbon::today();

        return match ($period) {

            'daily' => [
                'start' =>
                    $baseDate
                        ->copy()
                        ->startOfDay(),

                'end' =>
                    $baseDate
                        ->copy()
                        ->endOfDay(),
            ],

            'weekly' => [
                'start' =>
                    $baseDate
                        ->copy()
                        ->startOfWeek(),

                'end' =>
                    $baseDate
                        ->copy()
                        ->endOfWeek(),
            ],

            'monthly' => [
                'start' =>
                    $baseDate
                        ->copy()
                        ->startOfMonth(),

                'end' =>
                    $baseDate
                        ->copy()
                        ->endOfMonth(),
            ],

            default => [
                'start' =>
                    $baseDate
                        ->copy()
                        ->startOfDay(),

                'end' =>
                    $baseDate
                        ->copy()
                        ->endOfDay(),
            ],
        };
    }

    // ============================================================
    // TRANSACTION REPORT
    // ============================================================

    /**
     * Generate a transaction report for the user.
     *
     * This is the shared foundation for:
     *
     * US-059 Daily Transaction Report
     * US-060 Weekly Transaction Report
     * US-061 Monthly Transaction Report
     */
    public function transactionReport(
        User $user,
        string $period,
        ?string $date = null,
        ?string $currency = null
    ): array {

        $range =
            $this->resolveDateRange(
                $period,
                $date
            );

        $query =
            $this->userTransactionQuery(
                $user
            )
                ->whereBetween(
                    'created_at',
                    [
                        $range['start'],
                        $range['end'],
                    ]
                )
                ->orderByDesc(
                    'created_at'
                );

        // --------------------------------------------------------
        // OPTIONAL CURRENCY FILTER
        // --------------------------------------------------------

        if ($currency) {
            $currency =
                strtoupper(
                    trim($currency)
                );

            if (
                in_array(
                    $currency,
                    ['USD', 'KHR'],
                    true
                )
            ) {
                $query->where(
                    'currency',
                    $currency
                );
            }
        }

        $transactions =
            $query->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'idempotency_key',
                'wallet_id',
                'created_at',
                'updated_at',
            ]);

        // --------------------------------------------------------
        // BASIC COUNTS
        // --------------------------------------------------------

        $totalTransactions =
            $transactions->count();

        $completedTransactions =
            $transactions
                ->where(
                    'status',
                    'completed'
                )
                ->count();

        $cancelledTransactions =
            $transactions
                ->where(
                    'status',
                    'cancelled'
                )
                ->count();

        $failedTransactions =
            $transactions
                ->where(
                    'status',
                    'failed'
                )
                ->count();

        // --------------------------------------------------------
        // USD TOTALS
        // --------------------------------------------------------

        $usdTransactions =
            $transactions->where(
                'currency',
                'USD'
            );

        $usdTotalAmount =
            (float) $usdTransactions->sum(
                'amount'
            );

        $usdTotalFees =
            (float) $usdTransactions->sum(
                'fee_charged'
            );

        // --------------------------------------------------------
        // KHR TOTALS
        // --------------------------------------------------------

        $khrTransactions =
            $transactions->where(
                'currency',
                'KHR'
            );

        $khrTotalAmount =
            (float) $khrTransactions->sum(
                'amount'
            );

        $khrTotalFees =
            (float) $khrTransactions->sum(
                'fee_charged'
            );

        // --------------------------------------------------------
        // TRANSACTION TYPE BREAKDOWN
        // --------------------------------------------------------

        $typeBreakdown =
            $transactions
                ->groupBy(
                    'type'
                )
                ->map(
                    function ($items, $type) {

                        return [
                            'type' =>
                                $type,

                            'count' =>
                                $items->count(),

                            'usd_amount' =>
                                (float) $items
                                    ->where(
                                        'currency',
                                        'USD'
                                    )
                                    ->sum(
                                        'amount'
                                    ),

                            'khr_amount' =>
                                (float) $items
                                    ->where(
                                        'currency',
                                        'KHR'
                                    )
                                    ->sum(
                                        'amount'
                                    ),

                            'usd_fees' =>
                                (float) $items
                                    ->where(
                                        'currency',
                                        'USD'
                                    )
                                    ->sum(
                                        'fee_charged'
                                    ),

                            'khr_fees' =>
                                (float) $items
                                    ->where(
                                        'currency',
                                        'KHR'
                                    )
                                    ->sum(
                                        'fee_charged'
                                    ),
                        ];
                    }
                )
                ->values();

        // --------------------------------------------------------
        // STATUS BREAKDOWN
        // --------------------------------------------------------

        $statusBreakdown =
            $transactions
                ->groupBy(
                    'status'
                )
                ->map(
                    function ($items, $status) {

                        return [
                            'status' =>
                                $status,

                            'count' =>
                                $items->count(),
                        ];
                    }
                )
                ->values();

        // --------------------------------------------------------
        // DATE INFORMATION
        // --------------------------------------------------------

        return [
            'period' =>
                strtolower($period),

            'start_date' =>
                $range['start']
                    ->toDateString(),

            'end_date' =>
                $range['end']
                    ->toDateString(),

            'start_datetime' =>
                $range['start']
                    ->toDateTimeString(),

            'end_datetime' =>
                $range['end']
                    ->toDateTimeString(),

            'currency' =>
                $currency
                ? strtoupper($currency)
                : 'ALL',

            'summary' => [

                'total_transactions' =>
                    $totalTransactions,

                'completed_transactions' =>
                    $completedTransactions,

                'cancelled_transactions' =>
                    $cancelledTransactions,

                'failed_transactions' =>
                    $failedTransactions,

                'usd' => [
                    'transaction_count' =>
                        $usdTransactions->count(),

                    'total_amount' =>
                        round(
                            $usdTotalAmount,
                            2
                        ),

                    'total_fees' =>
                        round(
                            $usdTotalFees,
                            2
                        ),
                ],

                'khr' => [
                    'transaction_count' =>
                        $khrTransactions->count(),

                    'total_amount' =>
                        round(
                            $khrTotalAmount,
                            2
                        ),

                    'total_fees' =>
                        round(
                            $khrTotalFees,
                            2
                        ),
                ],
            ],

            'type_breakdown' =>
                $typeBreakdown,

            'status_breakdown' =>
                $statusBreakdown,

            'transactions' =>
                $transactions
                    ->values(),
        ];
    }

    // ============================================================
    // DAILY REPORT
    // US-059
    // ============================================================

    public function dailyReport(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        return $this->transactionReport(
            $user,
            'daily',
            $date,
            $currency
        );
    }

    // ============================================================
    // WEEKLY REPORT
    // US-060
    // ============================================================

    public function weeklyReport(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        return $this->transactionReport(
            $user,
            'weekly',
            $date,
            $currency
        );
    }

    // ============================================================
    // MONTHLY REPORT
    // US-061
    // ============================================================

    public function monthlyReport(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        return $this->transactionReport(
            $user,
            'monthly',
            $date,
            $currency
        );
    }
    // ============================================================
    // US-062 — USER REPORT
    // ============================================================

    public function userReport(
        User $user
    ): array {
        $user->loadMissing([
            'wallets',
        ]);

        $wallets = $user->wallets;

        return [
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],

            'wallets' => $wallets
                ->map(function ($wallet) {
                    return [
                        'id' => $wallet->id,
                        'name' => $wallet->name,
                        'currency' => $wallet->currency,
                        'balance' => round(
                            (float) $wallet->balance,
                            2
                        ),
                        'status' => $wallet->status,
                    ];
                })
                ->values(),

            'transaction_count' =>
                Transaction::query()
                    ->where('user_id', $user->id)
                    ->count(),
        ];
    }


    // ============================================================
    // US-063 — WALLET BALANCE REPORT
    // ============================================================

    public function walletBalanceReport(
        User $user
    ): array {
        $wallets = $user
            ->wallets()
            ->orderBy('currency')
            ->get([
                'id',
                'name',
                'currency',
                'balance',
                'status',
            ]);

        $usdBalance = (float) $wallets
            ->where('currency', 'USD')
            ->sum('balance');

        $khrBalance = (float) $wallets
            ->where('currency', 'KHR')
            ->sum('balance');

        return [
            'user_id' => $user->id,

            'wallet_count' =>
                $wallets->count(),

            'usd' => [
                'balance' =>
                    round($usdBalance, 2),
            ],

            'khr' => [
                'balance' =>
                    round($khrBalance, 2),
            ],

            'wallets' =>
                $wallets
                    ->map(function ($wallet) {
                        return [
                            'id' => $wallet->id,
                            'name' => $wallet->name,
                            'currency' => $wallet->currency,
                            'balance' => round(
                                (float) $wallet->balance,
                                2
                            ),
                            'status' => $wallet->status,
                        ];
                    })
                    ->values(),
        ];
    }


    // ============================================================
    // US-064 — PAYMENT REPORT
    // ============================================================

    public function paymentReport(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        $query = $this->userTransactionQuery($user)
            ->whereIn('type', [
                'payment',
                'bill_payment',
                'mobile_topup',
            ]);

        $range = null;

        if ($date) {
            $baseDate = Carbon::parse($date);

            $range = [
                'start' =>
                    $baseDate
                        ->copy()
                        ->startOfDay(),

                'end' =>
                    $baseDate
                        ->copy()
                        ->endOfDay(),
            ];

            $query->whereBetween(
                'created_at',
                [
                    $range['start'],
                    $range['end'],
                ]
            );
        }

        if ($currency) {
            $currency =
                strtoupper(
                    trim($currency)
                );

            if (
                in_array(
                    $currency,
                    ['USD', 'KHR'],
                    true
                )
            ) {
                $query->where(
                    'currency',
                    $currency
                );
            }
        }

        $transactions = $query
            ->orderByDesc('created_at')
            ->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'wallet_id',
                'created_at',
            ]);

        $completed = $transactions
            ->where('status', 'completed');

        $usd = $transactions
            ->where('currency', 'USD');

        $khr = $transactions
            ->where('currency', 'KHR');

        return [
            'report' => 'payment',

            'start_date' =>
                $range
                ? $range['start']->toDateString()
                : null,

            'end_date' =>
                $range
                ? $range['end']->toDateString()
                : null,

            'currency' =>
                $currency
                ? strtoupper($currency)
                : 'ALL',

            'summary' => [
                'total_payments' =>
                    $transactions->count(),

                'completed_payments' =>
                    $completed->count(),

                'failed_payments' =>
                    $transactions
                        ->where('status', 'failed')
                        ->count(),

                'cancelled_payments' =>
                    $transactions
                        ->where('status', 'cancelled')
                        ->count(),

                'usd_amount' =>
                    round(
                        (float) $usd->sum('amount'),
                        2
                    ),

                'khr_amount' =>
                    round(
                        (float) $khr->sum('amount'),
                        2
                    ),

                'usd_fees' =>
                    round(
                        (float) $usd->sum('fee_charged'),
                        2
                    ),

                'khr_fees' =>
                    round(
                        (float) $khr->sum('fee_charged'),
                        2
                    ),
            ],

            'by_type' =>
                $transactions
                    ->groupBy('type')
                    ->map(function ($items, $type) {
                        return [
                            'type' => $type,
                            'count' => $items->count(),

                            'usd_amount' =>
                                round(
                                    (float) $items
                                        ->where('currency', 'USD')
                                        ->sum('amount'),
                                    2
                                ),

                            'khr_amount' =>
                                round(
                                    (float) $items
                                        ->where('currency', 'KHR')
                                        ->sum('amount'),
                                    2
                                ),
                        ];
                    })
                    ->values(),

            'transactions' =>
                $transactions->values(),
        ];
    }


    // ============================================================
    // US-065 — TRANSFER REPORT
    // ============================================================

    public function transferReport(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        $query = $this->userTransactionQuery($user)
            ->whereIn('type', [
                'transfer_out',
                'transfer_in',
                'withdrawal',
                'deposit',
            ]);

        if ($date) {
            $baseDate = Carbon::parse($date);

            $query->whereBetween(
                'created_at',
                [
                    $baseDate->copy()->startOfDay(),
                    $baseDate->copy()->endOfDay(),
                ]
            );
        }

        if ($currency) {
            $currency =
                strtoupper(
                    trim($currency)
                );

            if (
                in_array(
                    $currency,
                    ['USD', 'KHR'],
                    true
                )
            ) {
                $query->where(
                    'currency',
                    $currency
                );
            }
        }

        $transactions = $query
            ->orderByDesc('created_at')
            ->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'wallet_id',
                'created_at',
            ]);

        $outgoing = $transactions
            ->whereIn('type', [
                'transfer_out',
                'withdrawal',
            ]);

        $incoming = $transactions
            ->whereIn('type', [
                'transfer_in',
                'deposit',
            ]);

        return [
            'report' => 'transfer',

            'currency' =>
                $currency
                ? strtoupper($currency)
                : 'ALL',

            'summary' => [
                'total_transfers' =>
                    $transactions->count(),

                'completed_transfers' =>
                    $transactions
                        ->where('status', 'completed')
                        ->count(),

                'outgoing_count' =>
                    $outgoing->count(),

                'incoming_count' =>
                    $incoming->count(),

                'usd_outgoing' =>
                    round(
                        (float) $outgoing
                            ->where('currency', 'USD')
                            ->sum('amount'),
                        2
                    ),

                'khr_outgoing' =>
                    round(
                        (float) $outgoing
                            ->where('currency', 'KHR')
                            ->sum('amount'),
                        2
                    ),

                'usd_incoming' =>
                    round(
                        (float) $incoming
                            ->where('currency', 'USD')
                            ->sum('amount'),
                        2
                    ),

                'khr_incoming' =>
                    round(
                        (float) $incoming
                            ->where('currency', 'KHR')
                            ->sum('amount'),
                        2
                    ),

                'usd_fees' =>
                    round(
                        (float) $transactions
                            ->where('currency', 'USD')
                            ->sum('fee_charged'),
                        2
                    ),

                'khr_fees' =>
                    round(
                        (float) $transactions
                            ->where('currency', 'KHR')
                            ->sum('fee_charged'),
                        2
                    ),
            ],

            'transactions' =>
                $transactions->values(),
        ];
    }


    // ============================================================
    // US-066 — REVENUE REPORT
    // ============================================================

    public function revenueReport(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        $query = $this->userTransactionQuery($user)
            ->where('type', 'fee_income');

        if ($date) {
            $baseDate = Carbon::parse($date);

            $query->whereBetween(
                'created_at',
                [
                    $baseDate->copy()->startOfDay(),
                    $baseDate->copy()->endOfDay(),
                ]
            );
        }

        if ($currency) {
            $currency =
                strtoupper(
                    trim($currency)
                );

            if (
                in_array(
                    $currency,
                    ['USD', 'KHR'],
                    true
                )
            ) {
                $query->where(
                    'currency',
                    $currency
                );
            }
        }

        $transactions = $query
            ->orderByDesc('created_at')
            ->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'wallet_id',
                'created_at',
            ]);

        $usd = $transactions
            ->where('currency', 'USD');

        $khr = $transactions
            ->where('currency', 'KHR');

        return [
            'report' => 'revenue',

            'currency' =>
                $currency
                ? strtoupper($currency)
                : 'ALL',

            'summary' => [
                'total_revenue_transactions' =>
                    $transactions->count(),

                'completed_revenue_transactions' =>
                    $transactions
                        ->where('status', 'completed')
                        ->count(),

                'usd_revenue' =>
                    round(
                        (float) $usd->sum('amount'),
                        2
                    ),

                'khr_revenue' =>
                    round(
                        (float) $khr->sum('amount'),
                        2
                    ),
            ],

            'transactions' =>
                $transactions->values(),
        ];
    }
    // ============================================================
// US-067 — TRANSACTION ANALYTICS
// ============================================================

    public function transactionAnalytics(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        $query = $this->userTransactionQuery($user);

        if ($date) {
            $baseDate = Carbon::parse($date);

            $query->whereBetween(
                'created_at',
                [
                    $baseDate->copy()->startOfDay(),
                    $baseDate->copy()->endOfDay(),
                ]
            );
        }

        if ($currency) {
            $currency = strtoupper(trim($currency));

            if (in_array($currency, ['USD', 'KHR'], true)) {
                $query->where('currency', $currency);
            }
        }

        $transactions = $query
            ->orderBy('created_at')
            ->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'created_at',
            ]);

        $completed = $transactions
            ->where('status', 'completed');

        $moneyOutTypes = [
            'withdrawal',
            'payment',
            'bill_payment',
            'mobile_topup',
            'transfer_out',
        ];

        $moneyInTypes = [
            'deposit',
            'transfer_in',
            'refund',
            'fee_reversal',
        ];

        $moneyOut = $completed
            ->whereIn('type', $moneyOutTypes);

        $moneyIn = $completed
            ->whereIn('type', $moneyInTypes);

        $usdOut = (float) $moneyOut
            ->where('currency', 'USD')
            ->sum('amount');

        $khrOut = (float) $moneyOut
            ->where('currency', 'KHR')
            ->sum('amount');

        $usdIn = (float) $moneyIn
            ->where('currency', 'USD')
            ->sum('amount');

        $khrIn = (float) $moneyIn
            ->where('currency', 'KHR')
            ->sum('amount');

        $usdFees = (float) $completed
            ->where('currency', 'USD')
            ->sum('fee_charged');

        $khrFees = (float) $completed
            ->where('currency', 'KHR')
            ->sum('fee_charged');

        $dailyTrend = $transactions
            ->groupBy(function ($transaction) {
                return $transaction->created_at
                    ? Carbon::parse($transaction->created_at)
                        ->toDateString()
                    : null;
            })
            ->map(function ($items, $date) use ($moneyOutTypes, $moneyInTypes) {
                $completed = $items
                    ->where('status', 'completed');

                $out = $completed
                    ->whereIn('type', $moneyOutTypes);

                $in = $completed
                    ->whereIn('type', $moneyInTypes);

                return [
                    'date' => $date,

                    'transaction_count' =>
                        $items->count(),

                    'completed_count' =>
                        $completed->count(),

                    'usd_money_out' =>
                        round(
                            (float) $out
                                ->where('currency', 'USD')
                                ->sum('amount'),
                            2
                        ),

                    'khr_money_out' =>
                        round(
                            (float) $out
                                ->where('currency', 'KHR')
                                ->sum('amount'),
                            2
                        ),

                    'usd_money_in' =>
                        round(
                            (float) $in
                                ->where('currency', 'USD')
                                ->sum('amount'),
                            2
                        ),

                    'khr_money_in' =>
                        round(
                            (float) $in
                                ->where('currency', 'KHR')
                                ->sum('amount'),
                            2
                        ),
                ];
            })
            ->values();

        return [
            'report' => 'transaction_analytics',

            'currency' =>
                $currency
                ? strtoupper($currency)
                : 'ALL',

            'summary' => [
                'total_transactions' =>
                    $transactions->count(),

                'completed_transactions' =>
                    $completed->count(),

                'failed_transactions' =>
                    $transactions
                        ->where('status', 'failed')
                        ->count(),

                'cancelled_transactions' =>
                    $transactions
                        ->where('status', 'cancelled')
                        ->count(),

                'money_out' => [
                    'usd' => round($usdOut, 2),
                    'khr' => round($khrOut, 2),
                ],

                'money_in' => [
                    'usd' => round($usdIn, 2),
                    'khr' => round($khrIn, 2),
                ],

                'fees' => [
                    'usd' => round($usdFees, 2),
                    'khr' => round($khrFees, 2),
                ],
            ],

            'type_breakdown' =>
                $transactions
                    ->groupBy('type')
                    ->map(function ($items, $type) {
                        return [
                            'type' => $type,
                            'count' => $items->count(),

                            'usd_amount' =>
                                round(
                                    (float) $items
                                        ->where('currency', 'USD')
                                        ->sum('amount'),
                                    2
                                ),

                            'khr_amount' =>
                                round(
                                    (float) $items
                                        ->where('currency', 'KHR')
                                        ->sum('amount'),
                                    2
                                ),
                        ];
                    })
                    ->values(),

            'daily_trend' =>
                $dailyTrend,
        ];
    }


    // ============================================================
// US-068 — SPENDING ANALYSIS
// ============================================================

    public function spendingAnalysis(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        $query = $this->userTransactionQuery($user)
            ->whereIn('type', [
                'payment',
                'bill_payment',
                'mobile_topup',
                'withdrawal',
                'transfer_out',
            ])
            ->where('status', 'completed');

        if ($date) {
            $baseDate = Carbon::parse($date);

            $query->whereBetween(
                'created_at',
                [
                    $baseDate->copy()->startOfDay(),
                    $baseDate->copy()->endOfDay(),
                ]
            );
        }

        if ($currency) {
            $currency = strtoupper(trim($currency));

            if (in_array($currency, ['USD', 'KHR'], true)) {
                $query->where('currency', $currency);
            }
        }

        $transactions = $query
            ->orderByDesc('created_at')
            ->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'created_at',
            ]);

        $payments = $transactions
            ->where('type', 'payment');

        $billPayments = $transactions
            ->where('type', 'bill_payment');

        $mobileTopUps = $transactions
            ->where('type', 'mobile_topup');

        $withdrawals = $transactions
            ->where('type', 'withdrawal');

        $transfers = $transactions
            ->where('type', 'transfer_out');

        $categories = [
            'payments' => $payments,
            'bill_payments' => $billPayments,
            'mobile_topups' => $mobileTopUps,
            'withdrawals' => $withdrawals,
            'transfers' => $transfers,
        ];

        $categoryBreakdown = [];

        foreach ($categories as $name => $items) {
            $categoryBreakdown[] = [
                'category' => $name,

                'count' =>
                    $items->count(),

                'usd_amount' =>
                    round(
                        (float) $items
                            ->where('currency', 'USD')
                            ->sum('amount'),
                        2
                    ),

                'khr_amount' =>
                    round(
                        (float) $items
                            ->where('currency', 'KHR')
                            ->sum('amount'),
                        2
                    ),
            ];
        }

        $usdSpending = (float) $transactions
            ->where('currency', 'USD')
            ->sum('amount');

        $khrSpending = (float) $transactions
            ->where('currency', 'KHR')
            ->sum('amount');

        return [
            'report' => 'spending_analysis',

            'currency' =>
                $currency
                ? strtoupper($currency)
                : 'ALL',

            'summary' => [
                'total_spending_transactions' =>
                    $transactions->count(),

                'usd_total_spending' =>
                    round($usdSpending, 2),

                'khr_total_spending' =>
                    round($khrSpending, 2),

                'usd_total_fees' =>
                    round(
                        (float) $transactions
                            ->where('currency', 'USD')
                            ->sum('fee_charged'),
                        2
                    ),

                'khr_total_fees' =>
                    round(
                        (float) $transactions
                            ->where('currency', 'KHR')
                            ->sum('fee_charged'),
                        2
                    ),
            ],

            'category_breakdown' =>
                $categoryBreakdown,

            'transactions' =>
                $transactions->values(),
        ];
    }


    // ============================================================
// US-069 — INCOME SUMMARY
// ============================================================

    public function incomeSummary(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        $incomeTypes = [
            'deposit',
            'transfer_in',
            'refund',
            'fee_reversal',
        ];

        $query = $this->userTransactionQuery($user)
            ->whereIn('type', $incomeTypes)
            ->where('status', 'completed');

        if ($date) {
            $baseDate = Carbon::parse($date);

            $query->whereBetween(
                'created_at',
                [
                    $baseDate->copy()->startOfDay(),
                    $baseDate->copy()->endOfDay(),
                ]
            );
        }

        if ($currency) {
            $currency = strtoupper(trim($currency));

            if (in_array($currency, ['USD', 'KHR'], true)) {
                $query->where('currency', $currency);
            }
        }

        $transactions = $query
            ->orderByDesc('created_at')
            ->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'created_at',
            ]);

        $usdIncome = (float) $transactions
            ->where('currency', 'USD')
            ->sum('amount');

        $khrIncome = (float) $transactions
            ->where('currency', 'KHR')
            ->sum('amount');

        return [
            'report' => 'income_summary',

            'currency' =>
                $currency
                ? strtoupper($currency)
                : 'ALL',

            'summary' => [
                'total_income_transactions' =>
                    $transactions->count(),

                'usd_total_income' =>
                    round($usdIncome, 2),

                'khr_total_income' =>
                    round($khrIncome, 2),
            ],

            'source_breakdown' =>
                $transactions
                    ->groupBy('type')
                    ->map(function ($items, $type) {
                        return [
                            'source' => $type,

                            'count' =>
                                $items->count(),

                            'usd_amount' =>
                                round(
                                    (float) $items
                                        ->where('currency', 'USD')
                                        ->sum('amount'),
                                    2
                                ),

                            'khr_amount' =>
                                round(
                                    (float) $items
                                        ->where('currency', 'KHR')
                                        ->sum('amount'),
                                    2
                                ),
                        ];
                    })
                    ->values(),

            'transactions' =>
                $transactions->values(),
        ];
    }


    // ============================================================
// US-070 — EXPENSE SUMMARY
// ============================================================

    public function expenseSummary(
        User $user,
        ?string $date = null,
        ?string $currency = null
    ): array {
        $expenseTypes = [
            'withdrawal',
            'payment',
            'bill_payment',
            'mobile_topup',
            'transfer_out',
        ];

        $query = $this->userTransactionQuery($user)
            ->whereIn('type', $expenseTypes)
            ->where('status', 'completed');

        if ($date) {
            $baseDate = Carbon::parse($date);

            $query->whereBetween(
                'created_at',
                [
                    $baseDate->copy()->startOfDay(),
                    $baseDate->copy()->endOfDay(),
                ]
            );
        }

        if ($currency) {
            $currency = strtoupper(trim($currency));

            if (in_array($currency, ['USD', 'KHR'], true)) {
                $query->where('currency', $currency);
            }
        }

        $transactions = $query
            ->orderByDesc('created_at')
            ->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'created_at',
            ]);

        $usdExpense = (float) $transactions
            ->where('currency', 'USD')
            ->sum('amount');

        $khrExpense = (float) $transactions
            ->where('currency', 'KHR')
            ->sum('amount');

        return [
            'report' => 'expense_summary',

            'currency' =>
                $currency
                ? strtoupper($currency)
                : 'ALL',

            'summary' => [
                'total_expense_transactions' =>
                    $transactions->count(),

                'usd_total_expense' =>
                    round($usdExpense, 2),

                'khr_total_expense' =>
                    round($khrExpense, 2),

                'usd_total_fees' =>
                    round(
                        (float) $transactions
                            ->where('currency', 'USD')
                            ->sum('fee_charged'),
                        2
                    ),

                'khr_total_fees' =>
                    round(
                        (float) $transactions
                            ->where('currency', 'KHR')
                            ->sum('fee_charged'),
                        2
                    ),
            ],

            'category_breakdown' =>
                $transactions
                    ->groupBy('type')
                    ->map(function ($items, $type) {
                        return [
                            'category' => $type,

                            'count' =>
                                $items->count(),

                            'usd_amount' =>
                                round(
                                    (float) $items
                                        ->where('currency', 'USD')
                                        ->sum('amount'),
                                    2
                                ),

                            'khr_amount' =>
                                round(
                                    (float) $items
                                        ->where('currency', 'KHR')
                                        ->sum('amount'),
                                    2
                                ),
                        ];
                    })
                    ->values(),

            'transactions' =>
                $transactions->values(),
        ];
    }
    // ============================================================
    // US-072 — EXPORT REPORT DATA
    // ============================================================

    public function exportReport(
        User $user,
        string $reportType = 'monthly',
        ?string $date = null,
        ?string $currency = null
    ) {
        $reportType =
            strtolower(
                trim($reportType)
            );

        $currency =
            $currency
            ? strtoupper(trim($currency))
            : null;

        if (
            $currency &&
            !in_array(
                $currency,
                ['USD', 'KHR'],
                true
            )
        ) {
            $currency = null;
        }

        /*
        |--------------------------------------------------------------------------
        | Determine which transaction types should be exported
        |--------------------------------------------------------------------------
        */

        $allowedTypes = null;

        switch ($reportType) {

            case 'payment':
            case 'payments':
                $allowedTypes = [
                    'payment',
                    'bill_payment',
                    'mobile_topup',
                ];
                break;

            case 'transfer':
            case 'transfers':
                $allowedTypes = [
                    'transfer_out',
                    'transfer_in',
                    'withdrawal',
                    'deposit',
                ];
                break;

            case 'revenue':
                $allowedTypes = [
                    'fee_income',
                ];
                break;

            case 'spending':
                $allowedTypes = [
                    'withdrawal',
                    'payment',
                    'bill_payment',
                    'mobile_topup',
                    'transfer_out',
                ];
                break;

            case 'income':
                $allowedTypes = [
                    'deposit',
                    'transfer_in',
                    'refund',
                    'fee_reversal',
                ];
                break;

            case 'expense':
            case 'expenses':
                $allowedTypes = [
                    'withdrawal',
                    'payment',
                    'bill_payment',
                    'mobile_topup',
                    'transfer_out',
                ];
                break;

            case 'daily':
            case 'weekly':
            case 'monthly':
            case 'transactions':
            default:
                $allowedTypes = null;
                break;
        }

        $query =
            $this->userTransactionQuery(
                $user
            );

        /*
        |--------------------------------------------------------------------------
        | Date filtering
        |--------------------------------------------------------------------------
        */

        if (
            in_array(
                $reportType,
                ['daily', 'weekly', 'monthly'],
                true
            )
        ) {
            $range =
                $this->resolveDateRange(
                    $reportType,
                    $date
                );

            $query->whereBetween(
                'created_at',
                [
                    $range['start'],
                    $range['end'],
                ]
            );
        } elseif ($date) {

            $baseDate =
                Carbon::parse($date);

            $query->whereBetween(
                'created_at',
                [
                    $baseDate
                        ->copy()
                        ->startOfDay(),

                    $baseDate
                        ->copy()
                        ->endOfDay(),
                ]
            );
        }

        /*
        |--------------------------------------------------------------------------
        | Transaction type filtering
        |--------------------------------------------------------------------------
        */

        if ($allowedTypes !== null) {
            $query->whereIn(
                'type',
                $allowedTypes
            );
        }

        /*
        |--------------------------------------------------------------------------
        | Currency filtering
        |--------------------------------------------------------------------------
        */

        if ($currency) {
            $query->where(
                'currency',
                $currency
            );
        }

        /*
        |--------------------------------------------------------------------------
        | Retrieve transactions
        |--------------------------------------------------------------------------
        */

        return $query
            ->orderByDesc('created_at')
            ->get([
                'id',
                'type',
                'amount',
                'fee_charged',
                'currency',
                'description',
                'reference_id',
                'status',
                'idempotency_key',
                'wallet_id',
                'created_at',
                'updated_at',
            ]);
    }
    // ============================================================
    // US-073 — REPORT FILTER
    // ============================================================

    public function filteredTransactions(
        User $user,
        ?string $startDate = null,
        ?string $endDate = null,
        ?string $currency = null,
        ?string $type = null,
        ?string $status = null,
        ?string $search = null,
        int $perPage = 20
    ) {
        $query =
            $this->userTransactionQuery(
                $user
            );

        // ========================================================
        // DATE RANGE
        // ========================================================

        if ($startDate) {
            $query->where(
                'created_at',
                '>=',
                Carbon::parse($startDate)
                    ->startOfDay()
            );
        }

        if ($endDate) {
            $query->where(
                'created_at',
                '<=',
                Carbon::parse($endDate)
                    ->endOfDay()
            );
        }

        // ========================================================
        // CURRENCY
        // ========================================================

        if ($currency) {
            $currency =
                strtoupper(
                    trim($currency)
                );

            if (
                in_array(
                    $currency,
                    ['USD', 'KHR'],
                    true
                )
            ) {
                $query->where(
                    'currency',
                    $currency
                );
            }
        }

        // ========================================================
        // TRANSACTION TYPE
        // ========================================================

        $allowedTypes = [
            'withdrawal',
            'deposit',
            'payment',
            'bill_payment',
            'mobile_topup',
            'transfer_out',
            'transfer_in',
            'fee_income',
            'refund',
            'fee_reversal',
        ];

        if ($type) {
            $type =
                strtolower(
                    trim($type)
                );

            if (
                in_array(
                    $type,
                    $allowedTypes,
                    true
                )
            ) {
                $query->where(
                    'type',
                    $type
                );
            }
        }

        // ========================================================
        // STATUS
        // ========================================================

        $allowedStatuses = [
            'pending',
            'completed',
            'failed',
            'cancelled',
        ];

        if ($status) {
            $status =
                strtolower(
                    trim($status)
                );

            if (
                in_array(
                    $status,
                    $allowedStatuses,
                    true
                )
            ) {
                $query->where(
                    'status',
                    $status
                );
            }
        }

        // ========================================================
        // SEARCH
        // Description / Reference / Transaction ID
        // ========================================================

        if (
            $search &&
            trim($search) !== ''
        ) {
            $search =
                trim($search);

            $query->where(function ($subQuery) use ($search) {

                $subQuery
                    ->where(
                        'description',
                        'like',
                        '%' . $search . '%'
                    )
                    ->orWhere(
                        'reference_id',
                        'like',
                        '%' . $search . '%'
                    )
                    ->orWhere(
                        'id',
                        'like',
                        '%' . $search . '%'
                    );
            });
        }

        // ========================================================
        // RESULTS
        // ========================================================

        return $query
            ->orderByDesc(
                'created_at'
            )
            ->paginate(
                max(
                    1,
                    min(
                        $perPage,
                        100
                    )
                )
            );
    }
}
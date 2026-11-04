<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">

    <title>NaNa Wallet Statement</title>

    <style>
        @page {
            margin: 28px;
        }

        body {
            font-family: DejaVu Sans, sans-serif;
            color: #172126;
            font-size: 10px;
        }

        .header {
            width: 100%;
            border-bottom: 2px solid #315BFF;
            padding-bottom: 14px;
            margin-bottom: 18px;
        }

        .brand {
            font-size: 22px;
            font-weight: bold;
            color: #315BFF;
        }

        .subtitle {
            color: #6B777C;
            font-size: 10px;
            margin-top: 4px;
        }

        .customer-box {
            background: #F3F6F8;
            border-radius: 8px;
            padding: 12px;
            margin-bottom: 15px;
        }

        .customer-name {
            font-size: 14px;
            font-weight: bold;
            margin-bottom: 5px;
        }

        .period {
            color: #68757A;
        }

        .summary-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 18px;
        }

        .summary-table td {
            width: 25%;
            border: 1px solid #E1E6E8;
            padding: 10px;
        }

        .summary-label {
            color: #718087;
            font-size: 8px;
            text-transform: uppercase;
        }

        .summary-value {
            font-size: 13px;
            font-weight: bold;
            margin-top: 4px;
        }

        .credit {
            color: #16834A;
        }

        .debit {
            color: #C63C4A;
        }

        .fee {
            color: #B87800;
        }

        .net {
            color: #315BFF;
        }

        .section-title {
            font-size: 13px;
            font-weight: bold;
            margin-bottom: 8px;
        }

        .transactions {
            width: 100%;
            border-collapse: collapse;
        }

        .transactions th {
            background: #172126;
            color: white;
            padding: 7px;
            text-align: left;
            font-size: 8px;
        }

        .transactions td {
            border-bottom: 1px solid #E5E9EA;
            padding: 7px;
            font-size: 8px;
        }

        .amount {
            text-align: right;
            font-weight: bold;
        }

        .positive {
            color: #16834A;
        }

        .negative {
            color: #C63C4A;
        }

        .status {
            text-transform: capitalize;
        }

        .footer {
            margin-top: 20px;
            padding-top: 10px;
            border-top: 1px solid #E1E6E8;
            color: #7A858A;
            font-size: 8px;
            text-align: center;
        }

        .empty {
            padding: 20px;
            text-align: center;
            color: #7A858A;
            border: 1px solid #E1E6E8;
        }
    </style>
</head>

<body>

    <div class="header">
        <div class="brand">
            NaNa Wallet
        </div>

        <div class="subtitle">
            Official Wallet Transaction Statement
        </div>
    </div>

    <div class="customer-box">
        <div class="customer-name">
            {{ $user->name }}
        </div>

        <div>
            {{ $user->email }}
        </div>

        <div class="period">
            Statement period:
            {{ $startDate->format('d M Y') }}
            -
            {{ $endDate->format('d M Y') }}
        </div>

        <div class="period">
            Currency:
            {{ $currency }}
        </div>
    </div>

    <table class="summary-table">
        <tr>
            <td>
                <div class="summary-label">
                    Total Credits
                </div>

                <div class="summary-value credit">
                    {{ $currency }}
                    {{ number_format($totalCredits, 2) }}
                </div>
            </td>

            <td>
                <div class="summary-label">
                    Total Debits
                </div>

                <div class="summary-value debit">
                    {{ $currency }}
                    {{ number_format($totalDebits, 2) }}
                </div>
            </td>

            <td>
                <div class="summary-label">
                    Total Fees
                </div>

                <div class="summary-value fee">
                    {{ $currency }}
                    {{ number_format($totalFees, 2) }}
                </div>
            </td>

            <td>
                <div class="summary-label">
                    Net Change
                </div>

                <div class="summary-value net">
                    {{ $currency }}
                    {{ number_format($netChange, 2) }}
                </div>
            </td>
        </tr>
    </table>

    <div class="section-title">
        Transaction Details
    </div>

    @if($transactions->count() > 0)

        <table class="transactions">
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Type</th>
                    <th>Description</th>
                    <th>Reference</th>
                    <th>Status</th>
                    <th style="text-align:right;">
                        Amount
                    </th>
                    <th style="text-align:right;">
                        Fee
                    </th>
                </tr>
            </thead>

            <tbody>

                @foreach($transactions as $transaction)

                        @php
                            $type = strtolower(
                                (string) $transaction->type
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
                        @endphp

                        <tr>

                            <td>
                                {{ $transaction->created_at
                        ? $transaction->created_at->format('d M Y H:i')
                        : '-' }}
                            </td>

                            <td>
                                {{ str_replace(
                        '_',
                        ' ',
                        ucfirst($transaction->type)
                    ) }}
                            </td>

                            <td>
                                {{ $transaction->description ?: '-' }}
                            </td>

                            <td>
                                {{ $transaction->reference_id ?: '-' }}
                            </td>

                            <td class="status">
                                {{ $transaction->status ?: '-' }}
                            </td>

                            <td class="amount
                                                                    {{ $isDebit
                        ? 'negative'
                        : 'positive' }}">
                                {{ $isDebit ? '-' : '+' }}
                                {{ number_format(
                        (float) $transaction->amount,
                        2
                    ) }}
                            </td>

                            <td class="amount">
                                {{ number_format(
                        (float) ($transaction->fee_charged ?? 0),
                        2
                    ) }}
                            </td>

                        </tr>

                @endforeach

            </tbody>
        </table>

    @else

        <div class="empty">
            No transactions were recorded during this period.
        </div>

    @endif

    <div class="footer">
        NaNa Wallet • Group 8 Digital Wallet
        <br>
        This statement was generated electronically.
    </div>

</body>

</html>
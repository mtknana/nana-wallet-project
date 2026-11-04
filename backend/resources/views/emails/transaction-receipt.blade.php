<!DOCTYPE html>
<html>

<head>
    <meta charset="UTF-8">

    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>NaNa Wallet Transaction Receipt</title>
</head>

<body style="
    margin: 0;
    padding: 0;
    background-color: #f3f5f6;
    font-family: Arial, Helvetica, sans-serif;
">

    <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
            <td align="center" style="padding: 35px 15px;">

                <table width="600" cellpadding="0" cellspacing="0" border="0" style="
                    max-width: 600px;
                    width: 100%;
                    background-color: #ffffff;
                    border-radius: 18px;
                    overflow: hidden;
                ">

                    {{-- HEADER --}}
                    <tr>
                        <td align="center" style="
                            background-color: #17262B;
                            padding: 32px 25px;
                        ">

                            <div style="
                            width: 58px;
                            height: 58px;
                            line-height: 58px;
                            border-radius: 50%;
                            background-color: #6675FF;
                            color: #ffffff;
                            font-size: 24px;
                            font-weight: bold;
                            margin-bottom: 12px;
                        ">
                                N
                            </div>

                            <div style="
                            color: #ffffff;
                            font-size: 24px;
                            font-weight: bold;
                        ">
                                NaNa Wallet
                            </div>

                            <div style="
                            color: #9AAEB7;
                            font-size: 11px;
                            letter-spacing: 2px;
                            margin-top: 6px;
                        ">
                                TRANSACTION RECEIPT
                            </div>

                        </td>
                    </tr>

                    {{-- CONTENT --}}
                    <tr>
                        <td style="padding: 35px 30px;">

                            <p style="
                            margin: 0 0 8px;
                            color: #17262B;
                            font-size: 18px;
                            font-weight: bold;
                        ">
                                Hello {{ $userName }},
                            </p>

                            <p style="
                            margin: 0 0 25px;
                            color: #71858E;
                            font-size: 14px;
                            line-height: 1.6;
                        ">
                                Here is your transaction receipt from
                                NaNa Wallet.
                            </p>

                            {{-- STATUS --}}
                            <div style="
                            text-align: center;
                            margin-bottom: 20px;
                        ">

                                <div style="
                                display: inline-block;
                                padding: 8px 16px;
                                border-radius: 20px;
                                background-color: #E8F9F1;
                                color: #159A62;
                                font-size: 13px;
                                font-weight: bold;
                            ">
                                    {{ ucfirst($transaction['status'] ?? 'completed') }}
                                </div>

                            </div>

                            {{-- AMOUNT --}}
                            <div style="
                            text-align: center;
                            padding: 20px;
                            background-color: #F7F8F9;
                            border-radius: 14px;
                            margin-bottom: 25px;
                        ">

                                <div style="
                                color: #71858E;
                                font-size: 12px;
                                margin-bottom: 7px;
                            ">
                                    Transaction Amount
                                </div>

                                <div style="
                                color: #17262B;
                                font-size: 32px;
                                font-weight: bold;
                            ">
                                    {{ number_format(abs((float) ($transaction['amount'] ?? 0)), 2) }}
                                    {{ $transaction['currency'] ?? 'USD' }}
                                </div>

                            </div>

                            {{-- DETAILS --}}
                            <table width="100%" cellpadding="0" cellspacing="0" border="0">

                                <tr>
                                    <td style="
                                    padding: 13px 0;
                                    color: #7F929A;
                                    font-size: 13px;
                                ">
                                        Transaction Type
                                    </td>

                                    <td align="right" style="
                                    padding: 13px 0;
                                    color: #17262B;
                                    font-size: 13px;
                                    font-weight: bold;
                                ">
                                        {{ $transaction['type_label'] ?? 'Transaction' }}
                                    </td>
                                </tr>

                                <tr>
                                    <td colspan="2">
                                        <div style="
                                        border-top: 1px solid #eeeeee;
                                    "></div>
                                    </td>
                                </tr>

                                <tr>
                                    <td style="
                                    padding: 13px 0;
                                    color: #7F929A;
                                    font-size: 13px;
                                ">
                                        Reference ID
                                    </td>

                                    <td align="right" style="
                                    padding: 13px 0;
                                    color: #17262B;
                                    font-size: 13px;
                                    font-weight: bold;
                                ">
                                        {{ $transaction['reference_id'] ?? 'N/A' }}
                                    </td>
                                </tr>

                                <tr>
                                    <td colspan="2">
                                        <div style="
                                        border-top: 1px solid #eeeeee;
                                    "></div>
                                    </td>
                                </tr>

                                <tr>
                                    <td style="
                                    padding: 13px 0;
                                    color: #7F929A;
                                    font-size: 13px;
                                ">
                                        Date & Time
                                    </td>

                                    <td align="right" style="
                                    padding: 13px 0;
                                    color: #17262B;
                                    font-size: 13px;
                                    font-weight: bold;
                                ">
                                        {{ $transaction['created_at'] ?? 'N/A' }}
                                    </td>
                                </tr>

                                @if(!empty($transaction['description']))

                                <tr>
                                    <td colspan="2">
                                        <div style="
                                            border-top: 1px solid #eeeeee;
                                        "></div>
                                    </td>
                                </tr>

                                <tr>
                                    <td style="
                                        padding: 13px 0;
                                        color: #7F929A;
                                        font-size: 13px;
                                    ">
                                        Description
                                    </td>

                                    <td align="right" style="
                                        padding: 13px 0;
                                        color: #17262B;
                                        font-size: 13px;
                                        font-weight: bold;
                                    ">
                                        {{ $transaction['description'] }}
                                    </td>
                                </tr>

                                @endif

                                <tr>
                                    <td colspan="2">
                                        <div style="
                                        border-top: 1px solid #eeeeee;
                                    "></div>
                                    </td>
                                </tr>

                                <tr>
                                    <td style="
                                    padding: 13px 0;
                                    color: #7F929A;
                                    font-size: 13px;
                                ">
                                        Receipt Number
                                    </td>

                                    <td align="right" style="
                                    padding: 13px 0;
                                    color: #17262B;
                                    font-size: 13px;
                                    font-weight: bold;
                                ">
                                        {{ $transaction['receipt_number'] ?? 'N/A' }}
                                    </td>
                                </tr>

                            </table>

                            {{-- SECURITY --}}
                            <div style="
                            margin-top: 28px;
                            padding: 15px;
                            background-color: #F0F8FC;
                            border-radius: 12px;
                            color: #52717D;
                            font-size: 11px;
                            line-height: 1.6;
                        ">
                                This receipt was generated automatically by
                                NaNa Wallet. Please keep this email for your
                                records.
                            </div>

                        </td>
                    </tr>

                    {{-- FOOTER --}}
                    <tr>
                        <td align="center" style="
                            background-color: #17262B;
                            padding: 22px;
                            color: #71858E;
                            font-size: 11px;
                            line-height: 1.5;
                        ">
                            NaNa Wallet<br>
                            Secure • Simple • Smart
                        </td>
                    </tr>

                </table>

            </td>
        </tr>
    </table>

</body>

</html>
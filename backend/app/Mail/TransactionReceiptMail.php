<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class TransactionReceiptMail extends Mailable
{
    use Queueable, SerializesModels;

    public array $transaction;
    public string $userName;

    public function __construct(
        array $transaction,
        string $userName
    ) {
        $this->transaction = $transaction;
        $this->userName = $userName;
    }

    public function build()
    {
        return $this
            ->subject('NaNa Wallet - Transaction Receipt')
            ->view('emails.transaction-receipt');
    }
}
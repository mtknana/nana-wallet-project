<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class QrPayment extends Model
{
    protected $fillable = [
        'user_id',
        'merchant_id',
        'merchant_name',
        'amount',
        'currency',
        'reference_id',
        'qr_payload_string',
        'status',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function merchant()
    {
        return $this->belongsTo(Merchant::class);
    }
}
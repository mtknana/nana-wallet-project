<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SplitBillMember extends Model
{
    protected $fillable = [
        'split_bill_id',
        'user_id',
        'owed_amount',
        'is_paid',
    ];

    protected $casts = [
        'owed_amount' => 'decimal:2',
        'is_paid' => 'boolean',
    ];

    public function splitBill()
    {
        return $this->belongsTo(SplitBill::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
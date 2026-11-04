<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    protected $fillable = [
        'user_id',
        'type',
        'amount',
        'fee_charged',
        'currency',
        'description',
        'reference_id',
        'idempotency_key',
        'status',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
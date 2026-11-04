<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class P2pTransfer extends Model
{
    protected $fillable = [
        'sender_id',
        'receiver_id',
        'amount',
        'currency',
        'fee_applied',
        'description',
        'reference_id',
        'status',
        'idempotency_key',
    ];

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function receiver()
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }
}

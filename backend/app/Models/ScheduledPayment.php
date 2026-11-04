<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ScheduledPayment extends Model
{
    protected $fillable = [
        'user_id',
        'payment_type',
        'recipient',
        'amount',
        'currency',
        'scheduled_date',
        'status',
        'description',
        'reference_id',
        'is_recurring',
        'recurrence_period',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'scheduled_date' => 'date',
        'is_recurring' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CalendarEvent extends Model
{
    protected $fillable = [
        'user_id',
        'title',
        'category',
        'estimated_amount',
        'currency',
        'due_date',
        'is_recurring',
        'recurrence_period',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
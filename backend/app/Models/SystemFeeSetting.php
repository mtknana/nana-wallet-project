<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SystemFeeSetting extends Model
{
    protected $fillable = [
        'transaction_type',
        'percentage_rate',
        'fixed_amount',
    ];

    protected $casts = [
        'percentage_rate' => 'decimal:2',
        'fixed_amount' => 'decimal:2',
    ];
}
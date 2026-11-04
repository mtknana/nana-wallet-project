<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Currency extends Model
{
    protected $fillable = [
        'code',
        'name',
        'symbol',
        'exchange_rate',
        'decimal_places',
        'is_active',
        'is_default',
        'rate_update_mode',
    ];

    protected function casts(): array
    {
        return [
            'exchange_rate' => 'decimal:8',
            'decimal_places' => 'integer',
            'is_active' => 'boolean',
            'is_default' => 'boolean',
        ];
    }
}
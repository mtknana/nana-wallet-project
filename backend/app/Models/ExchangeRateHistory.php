<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ExchangeRateHistory extends Model
{
    protected $fillable = [
        'currency_id',
        'exchange_rate',
        'source',
        'recorded_at',
        'changed_by',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'exchange_rate' => 'decimal:8',
            'recorded_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function currency(): BelongsTo
    {
        return $this->belongsTo(Currency::class);
    }

    public function changedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
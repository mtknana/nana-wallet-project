<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletNotification extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'type',
        'severity',
        'title',
        'message',
        'amount',
        'currency',
        'reference_type',
        'reference_id',
        'is_read',
        'read_at',
        'occurred_at',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'is_read' => 'boolean',
        'read_at' => 'datetime',
        'occurred_at' => 'datetime',
    ];

    // ==========================================================
    // USER
    // ==========================================================

    public function user(): BelongsTo
    {
        return $this->belongsTo(
            User::class
        );
    }
}
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SecurityEvent extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'event_type',
        'severity',
        'title',
        'description',
        'ip_address',
        'user_agent',
        'reference_type',
        'reference_id',
        'is_reviewed',
        'occurred_at',
    ];

    protected $casts = [
        'is_reviewed' => 'boolean',
        'occurred_at' => 'datetime',
    ];

    /**
     * Security event belongs to a user.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
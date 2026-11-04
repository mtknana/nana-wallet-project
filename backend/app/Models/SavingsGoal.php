<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SavingsGoal extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'name',
        'description',
        'target_amount',
        'current_amount',
        'currency',
        'target_date',
        'status',
    ];

    protected $casts = [
        'target_amount' => 'decimal:2',
        'current_amount' => 'decimal:2',
        'target_date' => 'date',
    ];

    /**
     * Savings goal belongs to a user.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Calculate progress percentage.
     */
    public function getProgressPercentageAttribute(): float
    {
        if ((float) $this->target_amount <= 0) {
            return 0;
        }

        $percentage =
            ((float) $this->current_amount /
                (float) $this->target_amount) * 100;

        return min(100, round($percentage, 2));
    }

    /**
     * Calculate remaining amount.
     */
    public function getRemainingAmountAttribute(): float
    {
        return max(
            0,
            (float) $this->target_amount -
            (float) $this->current_amount
        );
    }

    /**
     * Check whether the goal has been completed.
     */
    public function getIsCompletedAttribute(): bool
    {
        return (float) $this->current_amount >=
            (float) $this->target_amount;
    }
}
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Loan extends Model
{
    protected $fillable = [
        'user_id',
        'funded_by_user_id',
        'principal',
        'interest_rate',
        'upfront_interest',
        'disbursed_amount',
        'outstanding_principal',
        'currency',
        'term_days',
        'due_at',
        'status',
        'idempotency_key',
        'disbursed_at',
        'repaid_at',
        'auto_repayment_attempted_at',
    ];

    protected function casts(): array
    {
        return [
            'principal' => 'decimal:2',
            'interest_rate' => 'decimal:2',
            'upfront_interest' => 'decimal:2',
            'disbursed_amount' => 'decimal:2',
            'outstanding_principal' => 'decimal:2',
            'term_days' => 'integer',
            'due_at' => 'datetime',
            'disbursed_at' => 'datetime',
            'repaid_at' => 'datetime',
            'auto_repayment_attempted_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function fundedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'funded_by_user_id');
    }

    public function repayments(): HasMany
    {
        return $this->hasMany(LoanRepayment::class);
    }
}
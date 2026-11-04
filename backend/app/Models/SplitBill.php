<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SplitBill extends Model
{
    protected $fillable = [
        'creator_id',
        'title',
        'total_amount',
        'currency',
        'status',
    ];

    protected $casts = [
        'total_amount' => 'decimal:2',
    ];

    public function creator()
    {
        return $this->belongsTo(User::class, 'creator_id');
    }

    public function members()
    {
        return $this->hasMany(SplitBillMember::class);
    }
}
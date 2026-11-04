<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TaxSetting extends Model
{
    protected $fillable = [
        'name',
        'code',
        'rate_percent',
        'applies_to',
        'is_active',
        'is_inclusive',
        'description',
    ];

    protected function casts(): array
    {
        return [
            'rate_percent' => 'decimal:4',
            'is_active' => 'boolean',
            'is_inclusive' => 'boolean',
        ];
    }
}
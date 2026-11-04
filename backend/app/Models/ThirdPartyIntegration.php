<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ThirdPartyIntegration extends Model
{
    protected $fillable = [
        'name',
        'provider',
        'credentials',
        'settings',
        'is_active',
        'status',
        'last_tested_at',
        'last_error',
    ];

    protected function casts(): array
    {
        return [
            'credentials' => 'encrypted:array',
            'settings' => 'array',
            'is_active' => 'boolean',
            'last_tested_at' => 'datetime',
        ];
    }
}
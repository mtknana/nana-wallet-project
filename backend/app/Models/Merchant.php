<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Merchant extends Model
{
    protected $fillable = [
        'merchant_name',
        'merchant_code',
        'category',
        'email',
        'phone',
        'description',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    protected static function booted(): void
    {
        static::created(function (Merchant $merchant) {
            $merchant->wallets()->createMany([
                [
                    'currency' => 'USD',
                    'balance' => 0.00,
                    'status' => 'active',
                ],
                [
                    'currency' => 'KHR',
                    'balance' => 0.00,
                    'status' => 'active',
                ],
            ]);
        });
    }

    public function wallets()
    {
        return $this->hasMany(MerchantWallet::class);
    }

    public function getWallet(string $currency)
    {
        return $this->wallets()
            ->where('currency', strtoupper($currency))
            ->first();
    }
}
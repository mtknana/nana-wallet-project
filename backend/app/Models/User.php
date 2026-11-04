<?php

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Models\SecurityEvent;
use App\Models\WalletNotification;

class User extends Authenticatable implements FilamentUser
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Mass assignable attributes.
     */
    protected $fillable = [
        'name',
        'email',
        'phone_number',
        'password',
        'transaction_pin',
        'two_factor_enabled',
        'role',
        'locale',
    ];

    /**
     * Hidden attributes.
     */
    protected $hidden = [
        'password',
        'remember_token',
        'transaction_pin',
    ];
    protected $casts = [
        'email_verified_at' => 'datetime',
        'two_factor_enabled' => 'boolean',
    ];
    /**
     * Filament Admin Panel Access
     *
     * Only users with the admin role can access
     * the Filament administration panel.
     */
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->role === 'admin';
    }

    // =========================================================
    // WALLETS
    // =========================================================

    /**
     * Backward-compatible USD wallet relationship.
     *
     * Use wallets() when both USD and KHR wallets are needed.
     */
    public function wallet()
    {
        return $this->hasOne(Wallet::class)
            ->where('currency', 'USD');
    }

    /**
     * All wallets owned by the user.
     *
     * Normally contains:
     * - USD wallet
     * - KHR wallet
     */
    public function wallets()
    {
        return $this->hasMany(Wallet::class);
    }

    // =========================================================
    // TRANSACTIONS
    // =========================================================

    /**
     * Financial ledger transactions belonging to the user.
     */
    public function transactions()
    {
        return $this->hasMany(Transaction::class);
    }

    // =========================================================
    // SECURITY EVENTS
    // =========================================================

    /**
     * Security and audit events associated with this user.
     */
    public function securityEvents()
    {
        return $this->hasMany(SecurityEvent::class);
    }

    // =========================================================
    // CALENDAR / SCHEDULED PAYMENTS
    // =========================================================

    /**
     * Calendar events created by the user.
     */
    public function calendarEvents()
    {
        return $this->hasMany(CalendarEvent::class);
    }

    /**
     * Scheduled payments created by the user.
     */
    public function scheduledPayments()
    {
        return $this->hasMany(ScheduledPayment::class);
    }

    // =========================================================
    // SPLIT BILL
    // =========================================================

    /**
     * Split bills created by this user.
     */
    public function splitBillsCreated()
    {
        return $this->hasMany(
            SplitBill::class,
            'creator_id'
        );
    }

    /**
     * Split bill payment commitments belonging to this user.
     */
    public function splitBillCommitments()
    {
        return $this->hasMany(
            SplitBillMember::class,
            'user_id'
        );
    }
    /**
     * ============================================================
     * US-053 — User Devices
     * ============================================================
     */
    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }
    /**
     * ============================================================
     * US-058 — Wallet Notifications
     * ============================================================
     */
    public function walletNotifications(): HasMany
    {
        return $this->hasMany(
            WalletNotification::class
        );
    }
    /**
     * User's manually recorded daily expenses.
     */
    public function expenses(): HasMany
    {
        return $this->hasMany(Expense::class);
    }
    /**
     * User's savings goals.
     */
    public function savingsGoals(): HasMany
    {
        return $this->hasMany(SavingsGoal::class);
    }
    /**
     * User's Loans.
     */
    public function loans()
    {
        return $this->hasMany(\App\Models\Loan::class);
    }

    public function fundedLoans()
    {
        return $this->hasMany(
            \App\Models\Loan::class,
            'funded_by_user_id'
        );
    }

}
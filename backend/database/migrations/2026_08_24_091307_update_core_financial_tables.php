<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        // 1. Update your existing 'wallets' table columns safely (US-023, US-024)
        Schema::table('wallets', function (Blueprint $table) {
            if (!Schema::hasColumn('wallets', 'daily_limit')) {
                $table->decimal('daily_limit', 15, 2)->default(1000.00)->after('status');
            }
            if (!Schema::hasColumn('wallets', 'monthly_limit')) {
                $table->decimal('monthly_limit', 15, 2)->default(5000.00)->after('daily_limit');
            }
        });

        // 2. Update your existing 'transactions' table safely (US-026-A, US-026-D)
        Schema::table('transactions', function (Blueprint $table) {
            if (!Schema::hasColumn('transactions', 'fee_charged')) {
                $table->decimal('fee_charged', 15, 2)->default(0.00)->after('amount');
            }
            if (!Schema::hasColumn('transactions', 'currency')) {
                $table->string('currency', 3)->default('USD')->after('fee_charged');
            }
            if (!Schema::hasColumn('transactions', 'idempotency_key')) {
                $table->string('idempotency_key')->nullable()->unique()->after('reference_id');
            }
        });

        // 3. Create the brand new 'system_fee_settings' table on top (US-026-D)
        if (!Schema::hasTable('system_fee_settings')) {
            Schema::create('system_fee_settings', function (Blueprint $table) {
                $table->id();
                $table->string('transaction_type')->unique(); // p2p, withdrawal, bill_payment
                $table->decimal('percentage_rate', 5, 2)->default(0.00);
                $table->decimal('fixed_amount', 15, 2)->default(0.00);
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('system_fee_settings');

        Schema::table('transactions', function (Blueprint $table) {
            $table->dropColumn(['fee_charged', 'currency', 'idempotency_key']);
        });

        Schema::table('wallets', function (Blueprint $table) {
            $table->dropColumn(['daily_limit', 'monthly_limit']);
        });
    }
};

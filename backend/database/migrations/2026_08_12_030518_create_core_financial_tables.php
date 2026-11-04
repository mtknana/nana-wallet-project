<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Wallets (US-011, US-012, US-021, US-023, US-024, US-025)
        Schema::create('wallets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->decimal('balance', 15, 2)->default(0.00);
            $table->string('currency', 3)->default('USD');
            $table->string('status')->default('active'); // active, suspended, frozen
            $table->decimal('daily_limit', 15, 2)->default(1000.00);
            $table->decimal('monthly_limit', 15, 2)->default(5000.00);
            $table->timestamps();
        });

        // 2. Funding Sources (US-015, US-016)
        Schema::create('funding_sources', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('type'); // bank_account, card
            $table->string('provider_name'); // ABA, Acleda, Visa, Mastercard
            $table->string('account_number_masked'); // *********1234
            $table->boolean('is_default')->default(false);
            $table->timestamps();
        });

        // 3. Transactions Audit Trail Ledger (US-013, US-014, US-017, US-018, US-019, US-020)
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('type'); // deposit, withdrawal, top_up, payment
            $table->decimal('amount', 15, 2);
            $table->string('description')->nullable();
            $table->string('reference_id')->unique();
            $table->timestamps();
        });

        // 4. Planning Commitments Calendar (US-026)
        Schema::create('calendar_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('title'); // Salary Deposit, School Fees, Wifi Bill
            $table->string('category'); // payroll, bill, school_fees
            $table->decimal('estimated_amount', 15, 2);
            $table->date('due_date');
            $table->boolean('is_recurring')->default(false);
            $table->string('recurrence_period')->default('monthly'); // weekly, monthly
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('calendar_events');
        Schema::dropIfExists('transactions');
        Schema::dropIfExists('funding_sources');
        Schema::dropIfExists('wallets');
    }
};

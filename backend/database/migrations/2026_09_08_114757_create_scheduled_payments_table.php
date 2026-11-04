<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('scheduled_payments', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')
                ->constrained()
                ->onDelete('cascade');

            $table->string('payment_type');
            // bill, mobile_topup, merchant, transfer

            $table->string('recipient');
            $table->decimal('amount', 15, 2);

            $table->string('currency', 3)
                ->default('USD');

            $table->date('scheduled_date');

            $table->string('status')
                ->default('scheduled');
            // scheduled, processing, completed, cancelled, failed

            $table->string('description')
                ->nullable();

            $table->string('reference_id')
                ->unique();

            $table->boolean('is_recurring')
                ->default(false);

            $table->string('recurrence_period')
                ->nullable();
            // daily, weekly, monthly

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('scheduled_payments');
    }
};
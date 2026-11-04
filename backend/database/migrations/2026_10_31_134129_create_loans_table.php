<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('loans', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->foreignId('funded_by_user_id')
                ->constrained('users')
                ->restrictOnDelete();

            $table->decimal('principal', 15, 2);
            $table->decimal('interest_rate', 5, 2)->default(5.00);
            $table->decimal('upfront_interest', 15, 2);
            $table->decimal('disbursed_amount', 15, 2);
            $table->decimal('outstanding_principal', 15, 2);

            $table->string('currency', 3);
            $table->unsignedSmallInteger('term_days');
            $table->timestamp('due_at');

            $table->string('status')->default('active');
            // active, overdue, partially_paid, repaid, defaulted

            $table->string('idempotency_key')->unique();
            $table->timestamp('disbursed_at')->nullable();
            $table->timestamp('repaid_at')->nullable();

            $table->timestamps();

            $table->index(['user_id', 'status']);
            $table->index(['status', 'due_at']);
        });

        Schema::create('loan_repayments', function (Blueprint $table) {
            $table->id();

            $table->foreignId('loan_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->decimal('amount_due', 15, 2);
            $table->decimal('amount_collected', 15, 2)->default(0);
            $table->decimal('remaining_amount', 15, 2);

            $table->string('currency', 3);
            $table->string('status')->default('pending');
            // pending, partial, paid, failed

            $table->string('reference_id')->unique();
            $table->timestamp('processed_at')->nullable();

            $table->timestamps();

            $table->index(['loan_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('loan_repayments');
        Schema::dropIfExists('loans');
    }
};
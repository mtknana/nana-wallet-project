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
        Schema::create('expenses', function (Blueprint $table) {
            $table->id();

            // Expense owner
            $table->foreignId('user_id')
                ->constrained()
                ->cascadeOnDelete();

            // Expense category
            $table->enum('category', [
                'food',
                'transport',
                'study',
                'other',
            ]);

            // Expense amount
            $table->decimal('amount', 15, 2);

            // USD or KHR
            $table->enum('currency', [
                'USD',
                'KHR',
            ]);

            // Optional description
            $table->string('description')->nullable();

            // Date the expense happened
            $table->date('expense_date');

            $table->timestamps();

            // Helpful indexes for reporting/filtering
            $table->index(['user_id', 'expense_date']);
            $table->index(['user_id', 'category']);
            $table->index(['user_id', 'currency']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('expenses');
    }
};
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migration.
     */
    public function up(): void
    {
        Schema::create('savings_goals', function (Blueprint $table) {
            $table->id();

            // Goal owner
            $table->foreignId('user_id')
                ->constrained()
                ->cascadeOnDelete();

            // Goal name
            $table->string('name');

            // Optional description
            $table->string('description')->nullable();

            // Target amount
            $table->decimal('target_amount', 15, 2);

            // Amount currently saved
            $table->decimal('current_amount', 15, 2)
                ->default(0);

            // USD or KHR
            $table->enum('currency', [
                'USD',
                'KHR',
            ]);

            // Optional target completion date
            $table->date('target_date')->nullable();

            // Goal status
            $table->enum('status', [
                'active',
                'completed',
                'cancelled',
            ])->default('active');

            $table->timestamps();

            // Useful indexes
            $table->index(['user_id', 'status']);
            $table->index(['user_id', 'target_date']);
            $table->index(['user_id', 'currency']);
        });
    }

    /**
     * Reverse the migration.
     */
    public function down(): void
    {
        Schema::dropIfExists('savings_goals');
    }
};
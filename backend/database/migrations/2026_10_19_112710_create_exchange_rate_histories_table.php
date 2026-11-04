<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('exchange_rate_histories', function (Blueprint $table) {
            $table->id();

            $table->foreignId('currency_id')
                ->constrained('currencies')
                ->cascadeOnUpdate()
                ->restrictOnDelete();

            // Currency units per 1 USD, matching the Currency model.
            $table->decimal('exchange_rate', 18, 8);

            // Examples: manual, provider, scheduled.
            $table->string('source', 30)->default('manual');

            $table->timestamp('recorded_at')->useCurrent();

            $table->foreignId('changed_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->json('metadata')->nullable();

            $table->timestamps();

            $table->index(['currency_id', 'recorded_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('exchange_rate_histories');
    }
};
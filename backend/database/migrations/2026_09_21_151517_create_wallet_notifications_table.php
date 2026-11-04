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
        Schema::create('wallet_notifications', function (Blueprint $table) {
            $table->id();

            // Owner of the notification
            $table->foreignId('user_id')
                ->constrained()
                ->cascadeOnDelete();

            // Notification classification
            $table->string('type', 50);

            // Visual priority
            $table->string('severity', 20)
                ->default('info');

            // Notification content
            $table->string('title');
            $table->text('message');

            // Optional financial information
            $table->decimal('amount', 18, 2)
                ->nullable();

            $table->string('currency', 10)
                ->nullable();

            // Optional reference to another record
            $table->string('reference_type')
                ->nullable();

            $table->unsignedBigInteger('reference_id')
                ->nullable();

            // Notification state
            $table->boolean('is_read')
                ->default(false);

            $table->timestamp('read_at')
                ->nullable();

            $table->timestamp('occurred_at')
                ->useCurrent();

            $table->timestamps();

            // Faster notification queries
            $table->index([
                'user_id',
                'is_read',
            ]);

            $table->index([
                'user_id',
                'occurred_at',
            ]);

            $table->index([
                'reference_type',
                'reference_id',
            ]);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists(
            'wallet_notifications'
        );
    }
};
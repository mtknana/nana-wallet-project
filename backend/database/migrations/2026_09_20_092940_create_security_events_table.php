<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('security_events', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            // What happened
            $table->string('event_type');

            // Security severity
            $table->string('severity')->default('info');

            // Human-readable explanation
            $table->string('title');
            $table->text('description')->nullable();

            // Optional technical information
            $table->string('ip_address')->nullable();
            $table->text('user_agent')->nullable();

            // Optional reference to another system record
            $table->string('reference_type')->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();

            // Whether an admin has reviewed the event
            $table->boolean('is_reviewed')->default(false);

            $table->timestamp('occurred_at')->useCurrent();

            $table->timestamps();

            $table->index(['event_type']);
            $table->index(['severity']);
            $table->index(['is_reviewed']);
            $table->index(['occurred_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('security_events');
    }
};
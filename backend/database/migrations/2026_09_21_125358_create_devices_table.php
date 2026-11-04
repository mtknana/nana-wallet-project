<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * ============================================================
     * US-053 — Device Management
     * ============================================================
     */
    public function up(): void
    {
        Schema::create('devices', function (Blueprint $table) {
            $table->id();

            // Owner of the device
            $table->foreignId('user_id')
                ->constrained()
                ->cascadeOnDelete();

            // Device identification
            $table->string('device_id')->unique();
            $table->string('device_name')->nullable();
            $table->string('platform')->nullable();

            // Security information
            $table->string('ip_address')->nullable();
            $table->text('user_agent')->nullable();

            // Activity
            $table->timestamp('last_active_at')->nullable();

            // Whether this device is currently allowed
            $table->boolean('is_active')->default(true);

            $table->timestamps();

            // Faster lookup for a user's devices
            $table->index([
                'user_id',
                'is_active',
            ]);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('devices');
    }
};
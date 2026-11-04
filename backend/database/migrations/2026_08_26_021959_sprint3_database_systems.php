<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        // 1. Ledger Table for Wallet-to-Wallet Transactions (US-027, US-028, US-029, US-037, US-038)
        if (!Schema::hasTable('p2p_transfers')) {
            Schema::create('p2p_transfers', function (Blueprint $table) {
                $table->id();
                $table->foreignId('sender_id')->constrained('users')->onDelete('cascade');
                $table->foreignId('receiver_id')->constrained('users')->onDelete('cascade');
                $table->decimal('amount', 15, 2);
                $table->decimal('fee_applied', 15, 2)->default(0.00);
                $table->string('description')->nullable();
                $table->string('reference_id')->unique();
                $table->string('status')->default('completed'); // completed, cancelled (US-037, US-038)
                $table->timestamps();
            });
        }

        // 2. Merchant & QR Payments Tracking Table (US-030, US-031, US-032)
        if (!Schema::hasTable('qr_payments')) {
            Schema::create('qr_payments', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->onDelete('cascade');
                $table->string('merchant_name'); // e.g. 'Brown Coffee', 'Aeon Supermarket'
                $table->decimal('amount', 15, 2);
                $table->string('reference_id')->unique();
                $table->string('qr_payload_string')->nullable();
                $table->string('status')->default('completed');
                $table->timestamps();
            });
        }

        // 3. Bill Split Group Master Header (US-042)
        if (!Schema::hasTable('split_bills')) {
            Schema::create('split_bills', function (Blueprint $table) {
                $table->id();
                $table->foreignId('creator_id')->constrained('users')->onDelete('cascade');
                $table->string('title'); // e.g. 'Weekly Pizza Share'
                $table->decimal('total_amount', 15, 2);
                $table->string('status')->default('pending'); // pending, settled
                $table->timestamps();
            });
        }

        // 4. Bill Split Equal-Share Participant Matrix Mapping (US-042)
        if (!Schema::hasTable('split_bill_members')) {
            Schema::create('split_bill_members', function (Blueprint $table) {
                $table->id();
                $table->foreignId('split_bill_id')->constrained()->onDelete('cascade');
                $table->foreignId('user_id')->constrained()->onDelete('cascade');
                $table->decimal('owed_amount', 15, 2); // Backend core engine auto-calculates this value
                $table->boolean('is_paid')->default(false);
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('split_bill_members');
        Schema::dropIfExists('split_bills');
        Schema::dropIfExists('qr_payments');
        Schema::dropIfExists('p2p_transfers');
    }
};
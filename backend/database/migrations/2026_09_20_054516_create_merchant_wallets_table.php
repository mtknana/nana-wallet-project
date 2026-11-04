<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('merchant_wallets', function (Blueprint $table) {
            $table->id();

            $table->foreignId('merchant_id')
                ->constrained('merchants')
                ->cascadeOnDelete();

            $table->string('currency', 3);

            $table->decimal('balance', 18, 2)
                ->default(0);

            $table->string('status')
                ->default('active');

            $table->timestamps();

            // One USD wallet and one KHR wallet per merchant.
            $table->unique(['merchant_id', 'currency']);

            $table->index('currency');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('merchant_wallets');
    }
};
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasIndex('transactions', 'transactions_idempotency_key_unique')) {
            Schema::table('transactions', function (Blueprint $table) {
                $table->unique(
                    'idempotency_key',
                    'transactions_idempotency_key_unique'
                );
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasIndex('transactions', 'transactions_idempotency_key_unique')) {
            Schema::table('transactions', function (Blueprint $table) {
                $table->dropUnique(
                    'transactions_idempotency_key_unique'
                );
            });
        }
    }
};
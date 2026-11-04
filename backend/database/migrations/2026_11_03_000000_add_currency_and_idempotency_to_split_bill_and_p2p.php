<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('split_bills') && !Schema::hasColumn('split_bills', 'currency')) {
            Schema::table('split_bills', function (Blueprint $table): void {
                $table->string('currency', 3)->default('USD');
            });
        }

        if (Schema::hasTable('p2p_transfers') && !Schema::hasColumn('p2p_transfers', 'currency')) {
            Schema::table('p2p_transfers', function (Blueprint $table): void {
                $table->string('currency', 3)->default('USD');
            });
        }

        if (Schema::hasTable('p2p_transfers') && !Schema::hasColumn('p2p_transfers', 'idempotency_key')) {
            Schema::table('p2p_transfers', function (Blueprint $table): void {
                $table->string('idempotency_key')->nullable()->unique();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('p2p_transfers') && Schema::hasColumn('p2p_transfers', 'idempotency_key')) {
            Schema::table('p2p_transfers', function (Blueprint $table): void {
                $table->dropUnique(['idempotency_key']);
                $table->dropColumn('idempotency_key');
            });
        }

        if (Schema::hasTable('p2p_transfers') && Schema::hasColumn('p2p_transfers', 'currency')) {
            Schema::table('p2p_transfers', function (Blueprint $table): void {
                $table->dropColumn('currency');
            });
        }

        if (Schema::hasTable('split_bills') && Schema::hasColumn('split_bills', 'currency')) {
            Schema::table('split_bills', function (Blueprint $table): void {
                $table->dropColumn('currency');
            });
        }
    }
};

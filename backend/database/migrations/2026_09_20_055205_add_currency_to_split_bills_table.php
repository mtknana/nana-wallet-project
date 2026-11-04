<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('split_bills', function (Blueprint $table) {
            $table->string('currency', 3)
                ->default('USD')
                ->after('total_amount');
        });
    }

    public function down(): void
    {
        Schema::table('split_bills', function (Blueprint $table) {
            $table->dropColumn('currency');
        });
    }
};
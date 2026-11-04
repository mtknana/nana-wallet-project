<?php

namespace App\Filament\Resources\CurrencyResource\Pages;

use App\Filament\Resources\CurrencyResource;
use App\Models\ExchangeRateHistory;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class CreateCurrency extends CreateRecord
{
    protected static string $resource = CurrencyResource::class;

    protected function afterCreate(): void
    {
        DB::transaction(function (): void {
            ExchangeRateHistory::create([
                'currency_id' => $this->record->id,
                'exchange_rate' => $this->record->exchange_rate,
                'source' => 'manual',
                'recorded_at' => now(),
                'changed_by' => Auth::id(),
            ]);
        });
    }
}
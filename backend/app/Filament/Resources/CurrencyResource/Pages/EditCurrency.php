<?php

namespace App\Filament\Resources\CurrencyResource\Pages;

use App\Filament\Resources\CurrencyResource;
use App\Models\ExchangeRateHistory;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class EditCurrency extends EditRecord
{
    protected static string $resource = CurrencyResource::class;

    protected function afterSave(): void
    {
        if (!$this->record->wasChanged('exchange_rate')) {
            return;
        }

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
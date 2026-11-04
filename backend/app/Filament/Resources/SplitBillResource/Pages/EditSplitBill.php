<?php

namespace App\Filament\Resources\SplitBillResource\Pages;

use App\Filament\Resources\SplitBillResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditSplitBill extends EditRecord
{
    protected static string $resource = SplitBillResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}

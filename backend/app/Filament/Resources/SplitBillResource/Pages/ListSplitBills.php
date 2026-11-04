<?php

namespace App\Filament\Resources\SplitBillResource\Pages;

use App\Filament\Resources\SplitBillResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListSplitBills extends ListRecords
{
    protected static string $resource = SplitBillResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}

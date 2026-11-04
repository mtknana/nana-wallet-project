<?php

namespace App\Filament\Resources\P2pTransferResource\Pages;

use App\Filament\Resources\P2pTransferResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListP2pTransfers extends ListRecords
{
    protected static string $resource = P2pTransferResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}

<?php

namespace App\Filament\Resources\P2pTransferResource\Pages;

use App\Filament\Resources\P2pTransferResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditP2pTransfer extends EditRecord
{
    protected static string $resource = P2pTransferResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}

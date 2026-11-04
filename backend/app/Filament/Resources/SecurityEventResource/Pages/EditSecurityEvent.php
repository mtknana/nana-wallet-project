<?php

namespace App\Filament\Resources\SecurityEventResource\Pages;

use App\Filament\Resources\SecurityEventResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditSecurityEvent extends EditRecord
{
    protected static string $resource = SecurityEventResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}

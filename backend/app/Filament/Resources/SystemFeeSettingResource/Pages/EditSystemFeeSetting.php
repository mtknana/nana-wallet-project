<?php

namespace App\Filament\Resources\SystemFeeSettingResource\Pages;

use App\Filament\Resources\SystemFeeSettingResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditSystemFeeSetting extends EditRecord
{
    protected static string $resource = SystemFeeSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}

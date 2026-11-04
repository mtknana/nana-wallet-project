<?php

namespace App\Filament\Resources\SystemFeeSettingResource\Pages;

use App\Filament\Resources\SystemFeeSettingResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListSystemFeeSettings extends ListRecords
{
    protected static string $resource = SystemFeeSettingResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}

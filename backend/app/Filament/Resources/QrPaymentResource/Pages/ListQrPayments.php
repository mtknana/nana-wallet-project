<?php

namespace App\Filament\Resources\QrPaymentResource\Pages;

use App\Filament\Resources\QrPaymentResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListQrPayments extends ListRecords
{
    protected static string $resource = QrPaymentResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}

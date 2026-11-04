<?php

namespace App\Filament\Resources\QrPaymentResource\Pages;

use App\Filament\Resources\QrPaymentResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditQrPayment extends EditRecord
{
    protected static string $resource = QrPaymentResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}

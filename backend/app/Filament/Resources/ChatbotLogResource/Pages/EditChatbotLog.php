<?php

namespace App\Filament\Resources\ChatbotLogResource\Pages;

use App\Filament\Resources\ChatbotLogResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditChatbotLog extends EditRecord
{
    protected static string $resource = ChatbotLogResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}

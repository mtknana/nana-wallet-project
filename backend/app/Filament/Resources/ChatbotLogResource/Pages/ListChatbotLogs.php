<?php

namespace App\Filament\Resources\ChatbotLogResource\Pages;

use App\Filament\Resources\ChatbotLogResource;
use Filament\Resources\Pages\ListRecords;

class ListChatbotLogs extends ListRecords
{
    protected static string $resource = ChatbotLogResource::class;
}
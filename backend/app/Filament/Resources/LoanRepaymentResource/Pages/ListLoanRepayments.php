<?php

namespace App\Filament\Resources\LoanRepaymentResource\Pages;

use App\Filament\Resources\LoanRepaymentResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListLoanRepayments extends ListRecords
{
    protected static string $resource = LoanRepaymentResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}

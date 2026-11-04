<?php

namespace App\Filament\Resources\LoanRepaymentResource\Pages;

use App\Filament\Resources\LoanRepaymentResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditLoanRepayment extends EditRecord
{
    protected static string $resource = LoanRepaymentResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            Actions\DeleteAction::make(),
        ];
    }
}

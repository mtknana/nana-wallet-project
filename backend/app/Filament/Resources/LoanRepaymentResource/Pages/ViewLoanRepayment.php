<?php

namespace App\Filament\Resources\LoanRepaymentResource\Pages;

use App\Filament\Resources\LoanRepaymentResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

class ViewLoanRepayment extends ViewRecord
{
    protected static string $resource = LoanRepaymentResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
        ];
    }
}

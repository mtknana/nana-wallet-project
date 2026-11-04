<?php

namespace App\Filament\Resources;

use App\Filament\Resources\LoanRepaymentResource\Pages;
use App\Models\LoanRepayment;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class LoanRepaymentResource extends Resource
{
    protected static ?string $model = LoanRepayment::class;

    protected static ?string $navigationIcon = 'heroicon-o-banknotes';

    protected static ?string $navigationLabel = 'Loan Repayments';

    protected static ?string $navigationGroup = 'Quick Loan Management';

    protected static ?int $navigationSort = 2;

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Section::make('Repayment Information')
                ->schema([
                    TextEntry::make('id')
                        ->label('Repayment ID'),

                    TextEntry::make('loan.id')
                        ->label('Loan ID'),

                    TextEntry::make('loan.user.name')
                        ->label('Customer'),

                    TextEntry::make('amount_due')
                        ->label('Amount Due')
                        ->formatStateUsing(
                            fn($state, $record) =>
                                $record->currency . ' ' . number_format((float) $state, 2)
                        ),

                    TextEntry::make('amount_collected')
                        ->label('Amount Collected')
                        ->formatStateUsing(
                            fn($state, $record) =>
                                $record->currency . ' ' . number_format((float) $state, 2)
                        ),

                    TextEntry::make('remaining_amount')
                        ->label('Remaining Amount')
                        ->formatStateUsing(
                            fn($state, $record) =>
                                $record->currency . ' ' . number_format((float) $state, 2)
                        ),

                    TextEntry::make('currency'),

                    TextEntry::make('status')
                        ->badge(),

                    TextEntry::make('reference_id')
                        ->label('Reference ID'),

                    TextEntry::make('processed_at')
                        ->dateTime(),

                    TextEntry::make('created_at')
                        ->dateTime(),
                ])
                ->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),

                Tables\Columns\TextColumn::make('loan.user.name')
                    ->label('Customer')
                    ->searchable(),

                Tables\Columns\TextColumn::make('loan.id')
                    ->label('Loan ID')
                    ->sortable(),

                Tables\Columns\TextColumn::make('amount_due')
                    ->label('Amount Due')
                    ->formatStateUsing(
                        fn($state, $record) =>
                            $record->currency . ' ' . number_format((float) $state, 2)
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('amount_collected')
                    ->label('Collected')
                    ->formatStateUsing(
                        fn($state, $record) =>
                            $record->currency . ' ' . number_format((float) $state, 2)
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('remaining_amount')
                    ->label('Remaining')
                    ->formatStateUsing(
                        fn($state, $record) =>
                            $record->currency . ' ' . number_format((float) $state, 2)
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('currency')
                    ->searchable(),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'paid' => 'success',
                        'partially_paid' => 'warning',
                        'overdue' => 'danger',
                        default => 'gray',
                    }),

                Tables\Columns\TextColumn::make('processed_at')
                    ->dateTime()
                    ->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'paid' => 'Paid',
                        'partially_paid' => 'Partially Paid',
                        'overdue' => 'Overdue',
                    ]),

                Tables\Filters\SelectFilter::make('currency')
                    ->options([
                        'USD' => 'USD',
                        'KHR' => 'KHR',
                    ]),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ])
            ->bulkActions([]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListLoanRepayments::route('/'),
            'view' => Pages\ViewLoanRepayment::route('/{record}'),
        ];
    }
}
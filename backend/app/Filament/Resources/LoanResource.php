<?php

namespace App\Filament\Resources;

use App\Filament\Resources\LoanResource\Pages;
use App\Models\Loan;
use Filament\Forms\Form;
use Filament\Infolists\Infolist;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class LoanResource extends Resource
{
    protected static ?string $model = Loan::class;

    protected static ?string $navigationIcon = 'heroicon-o-banknotes';

    protected static ?string $navigationLabel = 'Quick Loans';

    protected static ?string $navigationGroup = 'Loan Management';

    protected static ?int $navigationSort = 1;

    protected static ?string $modelLabel = 'Quick Loan';

    protected static ?string $pluralModelLabel = 'Quick Loans';

    public static function form(Form $form): Form
    {
        // Loan records are managed by the customer-facing API.
        // Admins must not manually edit financial values here.
        return $form->schema([]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Section::make('Loan Information')
                ->columns(2)
                ->schema([
                    TextEntry::make('id')
                        ->label('Loan ID'),

                    TextEntry::make('status')
                        ->badge()
                        ->color(fn(string $state): string => match ($state) {
                            'repaid' => 'success',
                            'active' => 'info',
                            'partially_paid' => 'warning',
                            'overdue', 'defaulted' => 'danger',
                            default => 'gray',
                        }),

                    TextEntry::make('user.name')
                        ->label('Customer'),

                    TextEntry::make('fundedBy.name')
                        ->label('Funding Administrator'),

                    TextEntry::make('currency')
                        ->label('Currency'),

                    TextEntry::make('term_days')
                        ->label('Loan Term')
                        ->suffix(' days'),

                    TextEntry::make('principal')
                        ->label('Principal')
                        ->money(fn($record) => $record->currency),

                    TextEntry::make('interest_rate')
                        ->label('Upfront Interest Rate')
                        ->suffix('%'),

                    TextEntry::make('upfront_interest')
                        ->label('Upfront Interest')
                        ->money(fn($record) => $record->currency),

                    TextEntry::make('disbursed_amount')
                        ->label('Customer Received')
                        ->money(fn($record) => $record->currency),

                    TextEntry::make('outstanding_principal')
                        ->label('Outstanding Principal')
                        ->money(fn($record) => $record->currency),

                    TextEntry::make('due_at')
                        ->label('Due Date')
                        ->dateTime(),

                    TextEntry::make('disbursed_at')
                        ->label('Disbursed At')
                        ->dateTime(),

                    TextEntry::make('repaid_at')
                        ->label('Fully Repaid At')
                        ->dateTime()
                        ->placeholder('Not yet repaid'),

                    TextEntry::make('idempotency_key')
                        ->label('Request Key')
                        ->columnSpanFull()
                        ->copyable(),
                ]),

            Section::make('Repayment History')
                ->schema([
                    TextEntry::make('repayments_count')
                        ->label('Repayment Records')
                        ->state(fn(Loan $record) => $record->repayments()->count()),

                    TextEntry::make('repayments_summary')
                        ->label('Repayment Summary')
                        ->state(fn(Loan $record) => $record->repayments
                            ->map(
                                fn($repayment) =>
                                    strtoupper($repayment->status)
                                    . ' — '
                                    . $repayment->amount_collected
                                    . ' / '
                                    . $repayment->amount_due
                                    . ' '
                                    . $repayment->currency
                            )
                            ->implode("\n"))
                        ->columnSpanFull()
                        ->placeholder('No repayment records'),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('Loan ID')
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.name')
                    ->label('Customer')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('principal')
                    ->label('Principal')
                    ->formatStateUsing(
                        fn($state, Loan $record) =>
                            number_format((float) $state, 2) . ' ' . $record->currency
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('upfront_interest')
                    ->label('Interest (5%)')
                    ->formatStateUsing(
                        fn($state, Loan $record) =>
                            number_format((float) $state, 2) . ' ' . $record->currency
                    ),

                Tables\Columns\TextColumn::make('disbursed_amount')
                    ->label('Customer Received')
                    ->formatStateUsing(
                        fn($state, Loan $record) =>
                            number_format((float) $state, 2) . ' ' . $record->currency
                    ),

                Tables\Columns\TextColumn::make('outstanding_principal')
                    ->label('Outstanding')
                    ->formatStateUsing(
                        fn($state, Loan $record) =>
                            number_format((float) $state, 2) . ' ' . $record->currency
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'repaid' => 'success',
                        'active' => 'info',
                        'partially_paid' => 'warning',
                        'overdue', 'defaulted' => 'danger',
                        default => 'gray',
                    }),

                Tables\Columns\TextColumn::make('due_at')
                    ->label('Due Date')
                    ->dateTime()
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Applied')
                    ->dateTime()
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'active' => 'Active',
                        'overdue' => 'Overdue',
                        'partially_paid' => 'Partially Paid',
                        'repaid' => 'Repaid',
                        'defaulted' => 'Defaulted',
                    ]),

                Tables\Filters\SelectFilter::make('currency')
                    ->options(fn() => \App\Models\Currency::query()
                        ->pluck('code', 'code')
                        ->all()),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ])
            ->bulkActions([])
            ->defaultSort('created_at', 'desc');
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListLoans::route('/'),
            'view' => Pages\ViewLoan::route('/{record}'),
        ];
    }
}
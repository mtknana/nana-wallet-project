<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SplitBillResource\Pages;
use App\Models\SplitBill;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;

class SplitBillResource extends Resource
{
    protected static ?string $model = SplitBill::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    protected static ?string $navigationGroup = 'Financial Core';

    protected static ?string $navigationLabel = 'Split Bills';

    protected static ?string $modelLabel = 'Split Bill';

    protected static ?string $pluralModelLabel = 'Split Bills';

    /**
     * Split bills are created through the wallet application.
     * Admin should only monitor the records.
     */
    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit($record): bool
    {
        return false;
    }

    public static function canDelete($record): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([

                TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),

                TextColumn::make('title')
                    ->label('Split Event')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('creator.name')
                    ->label('Created By')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('currency')
                    ->label('Currency')
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'USD' => 'success',
                        'KHR' => 'info',
                        default => 'gray',
                    })
                    ->sortable(),

                TextColumn::make('total_amount')
                    ->label('Total Amount')
                    ->formatStateUsing(function ($state, $record) {
                        $currency = strtoupper(
                            $record->currency ?? 'USD'
                        );

                        if ($currency === 'KHR') {
                            return '៛ ' . number_format(
                                (float) $state,
                                2
                            );
                        }

                        return '$ ' . number_format(
                            (float) $state,
                            2
                        );
                    })
                    ->sortable(),

                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(
                        fn(string $state): string => match ($state) {
                            'settled' => 'success',
                            'pending' => 'warning',
                            'cancelled' => 'danger',
                            default => 'gray',
                        }
                    )
                    ->sortable(),

                TextColumn::make('created_at')
                    ->label('Created')
                    ->dateTime()
                    ->sortable(),
            ])

            ->filters([

                Tables\Filters\SelectFilter::make('currency')
                    ->options([
                        'USD' => 'US Dollar (USD)',
                        'KHR' => 'Cambodian Riel (KHR)',
                    ]),

                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'settled' => 'Settled',
                        'cancelled' => 'Cancelled',
                    ]),
            ])

            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSplitBills::route('/'),
        ];
    }
}
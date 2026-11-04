<?php

namespace App\Filament\Widgets;

use App\Models\ExchangeRateHistory;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Illuminate\Database\Eloquent\Builder;

class ExchangeRateHistoryTable extends BaseWidget
{
    protected static ?string $heading = 'Exchange Rate History Records';

    protected static ?int $sort = 10;

    protected int|string|array $columnSpan = 'full';

    protected function getTableQuery(): Builder
    {
        return ExchangeRateHistory::query()
            ->with(['currency', 'changedBy'])
            ->latest('recorded_at');
    }

    protected function getTableColumns(): array
    {
        return [
            Tables\Columns\TextColumn::make('currency.code')
                ->label('Currency')
                ->badge()
                ->sortable()
                ->searchable(),

            Tables\Columns\TextColumn::make('exchange_rate')
                ->label('Units per 1 USD')
                ->numeric(decimalPlaces: 8)
                ->sortable(),

            Tables\Columns\TextColumn::make('source')
                ->label('Update Source')
                ->badge()
                ->color(fn(?string $state): string => match ($state) {
                    'manual' => 'warning',
                    'automatic' => 'success',
                    'daily_snapshot' => 'info',
                    default => 'gray',
                })
                ->sortable(),

            Tables\Columns\TextColumn::make('changedBy.name')
                ->label('Changed By')
                ->placeholder('System')
                ->searchable(),

            Tables\Columns\TextColumn::make('recorded_at')
                ->label('Recorded At')
                ->dateTime()
                ->sortable(),

            Tables\Columns\TextColumn::make('created_at')
                ->label('Entry Created')
                ->dateTime()
                ->toggleable(isToggledHiddenByDefault: true),
        ];
    }

    protected function getTableDefaultSortColumn(): ?string
    {
        return 'recorded_at';
    }

    protected function getTableDefaultSortDirection(): ?string
    {
        return 'desc';
    }
}
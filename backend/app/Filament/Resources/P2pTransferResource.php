<?php

namespace App\Filament\Resources;

use App\Filament\Resources\P2pTransferResource\Pages;
use App\Models\P2pTransfer;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;

class P2pTransferResource extends Resource
{
    protected static ?string $model = P2pTransfer::class;

    protected static ?string $navigationIcon = 'heroicon-o-arrows-right-left';

    protected static ?string $navigationGroup = 'Financial Core';

    protected static ?string $navigationLabel = 'P2P Transfers';

    protected static ?string $modelLabel = 'P2P Transfer';

    protected static ?string $pluralModelLabel = 'P2P Transfers';

    /**
     * P2P transfers are system-generated financial records.
     * Admins can view them for audit purposes only.
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

    /**
     * Format an amount according to the transaction currency.
     */
    private static function formatCurrency(
        mixed $amount,
        ?string $currency
    ): string {
        $currency = strtoupper($currency ?? 'USD');
        $amount = (float) $amount;

        return match ($currency) {
            'KHR' => '៛ ' . number_format($amount, 0, '.', ','),
            'USD' => '$ ' . number_format($amount, 2, '.', ','),
            default => $currency . ' ' . number_format($amount, 2, '.', ','),
        };
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('reference_id')
                    ->label('Transaction Reference ID')
                    ->searchable()
                    ->copyable()
                    ->fontFamily('mono')
                    ->sortable(),

                TextColumn::make('sender.name')
                    ->label('Sender')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('receiver.name')
                    ->label('Recipient')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('amount')
                    ->label('Transfer Amount')
                    ->formatStateUsing(
                        fn($state, P2pTransfer $record): string =>
                            self::formatCurrency(
                                $state,
                                $record->currency
                            )
                    )
                    ->sortable(),

                TextColumn::make('currency')
                    ->label('Currency')
                    ->badge()
                    ->color(
                        fn($state): string => match (
                        strtoupper($state ?? '')
                    ) {
                            'USD' => 'success',
                            'KHR' => 'info',
                            default => 'gray',
                        }
                    )
                    ->formatStateUsing(
                        fn($state): string =>
                            strtoupper($state ?? 'UNKNOWN')
                    )
                    ->sortable(),

                TextColumn::make('fee_applied')
                    ->label('Transfer Fee')
                    ->formatStateUsing(
                        fn($state, P2pTransfer $record): string =>
                            self::formatCurrency(
                                $state,
                                $record->currency
                            )
                    )
                    ->sortable(),

                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(
                        fn($state): string => match (
                        strtolower($state ?? '')
                    ) {
                            'completed' => 'success',
                            'pending' => 'warning',
                            'failed',
                            'cancelled' => 'danger',
                            default => 'gray',
                        }
                    )
                    ->formatStateUsing(
                        fn($state): string =>
                            ucfirst($state ?? 'Unknown')
                    )
                    ->sortable(),

                TextColumn::make('created_at')
                    ->label('Processed At')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(),
            ])

            ->filters([
                SelectFilter::make('currency')
                    ->label('Currency')
                    ->options([
                        'USD' => 'USD',
                        'KHR' => 'KHR',
                    ]),

                SelectFilter::make('status')
                    ->label('Transfer Status')
                    ->options([
                        'completed' => 'Completed',
                        'pending' => 'Pending',
                        'failed' => 'Failed',
                        'cancelled' => 'Cancelled',
                    ]),
            ])

            ->actions([
                // No Edit/Delete.
                // P2P records are financial audit records.
            ])

            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListP2pTransfers::route('/'),
        ];
    }
}
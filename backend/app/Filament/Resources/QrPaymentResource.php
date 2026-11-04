<?php

namespace App\Filament\Resources;

use App\Filament\Resources\QrPaymentResource\Pages;
use App\Models\QrPayment;
use Filament\Resources\Resource;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables;

class QrPaymentResource extends Resource
{
    protected static ?string $model = QrPayment::class;

    protected static ?string $navigationIcon = 'heroicon-o-qr-code';

    protected static ?string $navigationGroup = 'Financial Core';

    /**
     * QR payments are created by customers through the wallet app.
     * Admin should only audit them here.
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

                TextColumn::make('reference_id')
                    ->label('Payment Reference')
                    ->searchable()
                    ->fontFamily('mono')
                    ->copyable(),

                TextColumn::make('user.name')
                    ->label('Payer Customer')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('merchant_name')
                    ->label('Merchant')
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

                TextColumn::make('amount')
                    ->label('Payment Amount')
                    ->formatStateUsing(function ($state, $record) {
                        $currency = strtoupper($record->currency ?? 'USD');

                        if ($currency === 'KHR') {
                            return '៛ ' . number_format((float) $state, 2);
                        }

                        return '$ ' . number_format((float) $state, 2);
                    })
                    ->sortable(),

                TextColumn::make('status')
                    ->label('Payment Status')
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'completed' => 'success',
                        'pending' => 'warning',
                        'failed',
                        'cancelled' => 'danger',
                        default => 'gray',
                    })
                    ->sortable(),

                TextColumn::make('created_at')
                    ->label('Payment Date')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])

            ->filters([

                Tables\Filters\SelectFilter::make('currency')
                    ->options([
                        'USD' => 'US Dollar (USD)',
                        'KHR' => 'Cambodian Riel (KHR)',
                    ]),

                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'completed' => 'Completed',
                        'pending' => 'Pending',
                        'failed' => 'Failed',
                        'cancelled' => 'Cancelled',
                    ]),
            ])

            ->defaultSort('created_at', 'desc')

            ->actions([
                // Intentionally read-only.
                // QR payments are financial ledger records.
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListQrPayments::route('/'),
        ];
    }
}
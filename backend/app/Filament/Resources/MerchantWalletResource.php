<?php

namespace App\Filament\Resources;

use App\Filament\Resources\MerchantWalletResource\Pages;
use App\Models\MerchantWallet;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;

class MerchantWalletResource extends Resource
{
    protected static ?string $model = MerchantWallet::class;

    protected static ?string $navigationIcon = 'heroicon-o-wallet';

    protected static ?string $navigationGroup = 'Merchant Management';

    protected static ?string $navigationLabel = 'Merchant Wallets';

    protected static ?string $modelLabel = 'Merchant Wallet';

    protected static ?string $pluralModelLabel = 'Merchant Wallets';

    /**
     * Merchant wallets are financial ledger records.
     * Admin should not manually create or delete them.
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

                TextColumn::make('merchant.merchant_name')
                    ->label('Merchant')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('merchant.merchant_code')
                    ->label('Merchant Code')
                    ->searchable()
                    ->fontFamily('mono'),

                TextColumn::make('currency')
                    ->label('Currency')
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'USD' => 'success',
                        'KHR' => 'info',
                        default => 'gray',
                    })
                    ->sortable(),

                TextColumn::make('balance')
                    ->label('Available Balance')
                    ->formatStateUsing(function ($state, $record) {
                        $currency = strtoupper($record->currency ?? 'USD');

                        if ($currency === 'KHR') {
                            return '៛ ' . number_format((float) $state, 2);
                        }

                        return '$ ' . number_format((float) $state, 2);
                    })
                    ->sortable(),

                TextColumn::make('status')
                    ->label('Wallet Status')
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'active' => 'success',
                        'inactive' => 'warning',
                        'suspended' => 'danger',
                        default => 'gray',
                    })
                    ->sortable(),

                TextColumn::make('created_at')
                    ->label('Created')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),

                TextColumn::make('updated_at')
                    ->label('Last Updated')
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
                        'active' => 'Active',
                        'inactive' => 'Inactive',
                        'suspended' => 'Suspended',
                    ]),
            ])

            ->defaultSort('created_at', 'desc')

            ->actions([
                // Read-only financial ledger.
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListMerchantWallets::route('/'),
        ];
    }
}
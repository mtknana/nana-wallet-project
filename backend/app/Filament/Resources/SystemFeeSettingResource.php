<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SystemFeeSettingResource\Pages;
use App\Models\SystemFeeSetting;
use Filament\Forms\Form;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Select;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;

class SystemFeeSettingResource extends Resource
{
    protected static ?string $model = SystemFeeSetting::class;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';

    protected static ?string $navigationGroup = 'Financial Core';

    protected static ?string $navigationLabel = 'System Fee Settings';

    // =========================================================
    // FORM
    // =========================================================

    public static function form(Form $form): Form
    {
        return $form
            ->schema([

                Select::make('transaction_type')
                    ->label('Transaction Type')
                    ->options([
                        'deposit' => 'Account Deposit',
                        'withdrawal' => 'Wallet Withdrawal',
                        'p2p' => 'P2P Transfer',
                    ])
                    ->required()
                    ->disabledOn('edit'),

                TextInput::make('percentage_rate')
                    ->numeric()
                    ->label('Percentage Processing Fee (%)')
                    ->default(1.50)
                    ->suffix('%')
                    ->minValue(0)
                    ->maxValue(100)
                    ->required()
                    ->helperText(
                        'Example: 1.50 means a 1.5% transaction fee.'
                    ),

                TextInput::make('fixed_amount')
                    ->numeric()
                    ->label('Fixed Fee Amount')
                    ->default(0.00)
                    ->minValue(0)
                    ->required()
                    ->helperText(
                        'Used only when the percentage fee is 0.00. ' .
                        'The fee uses the same currency as the transaction (USD or KHR).'
                    ),
            ]);
    }

    // =========================================================
    // TABLE
    // =========================================================

    public static function table(Table $table): Table
    {
        return $table
            ->columns([

                TextColumn::make('transaction_type')
                    ->label('Transaction Type')
                    ->badge()
                    ->color('primary')
                    ->formatStateUsing(
                        fn(string $state): string =>
                            strtoupper(
                                str_replace('_', ' ', $state)
                            )
                    )
                    ->sortable(),

                TextColumn::make('percentage_rate')
                    ->label('Percentage Fee')
                    ->suffix('%')
                    ->sortable(),

                TextColumn::make('fixed_amount')
                    ->label('Fixed Fee')
                    ->formatStateUsing(
                        fn($state): string =>
                            number_format((float) $state, 2)
                    )
                    ->sortable(),

                TextColumn::make('updated_at')
                    ->label('Last Updated')
                    ->dateTime()
                    ->sortable(),
            ])

            ->filters([
                Tables\Filters\SelectFilter::make('transaction_type')
                    ->label('Transaction Type')
                    ->options([
                        'deposit' => 'Account Deposit',
                        'withdrawal' => 'Wallet Withdrawal',
                        'p2p' => 'P2P Transfer',
                    ]),
            ])

            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])

            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ])

            ->defaultSort('updated_at', 'desc');
    }

    // =========================================================
    // RELATIONS
    // =========================================================

    public static function getRelations(): array
    {
        return [];
    }

    // =========================================================
    // PAGES
    // =========================================================

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSystemFeeSettings::route('/'),
            'create' => Pages\CreateSystemFeeSetting::route('/create'),
            'edit' => Pages\EditSystemFeeSetting::route('/{record}/edit'),
        ];
    }
}
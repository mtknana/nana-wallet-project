<?php

namespace App\Filament\Resources;

use App\Filament\Resources\TaxSettingResource\Pages;
use App\Models\TaxSetting;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class TaxSettingResource extends Resource
{
    protected static ?string $model = TaxSetting::class;

    protected static ?string $navigationIcon = 'heroicon-o-receipt-percent';

    protected static ?string $navigationGroup = 'System Administration';

    protected static ?string $navigationLabel = 'Tax Settings';

    protected static ?int $navigationSort = 3;

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Tax Configuration')
                ->schema([
                    Forms\Components\TextInput::make('name')
                        ->label('Tax Name')
                        ->required()
                        ->maxLength(100),

                    Forms\Components\TextInput::make('code')
                        ->label('Tax Code')
                        ->required()
                        ->alphaDash()
                        ->maxLength(50)
                        ->unique(
                            table: TaxSetting::class,
                            column: 'code',
                            ignoreRecord: true
                        )
                        ->dehydrateStateUsing(
                            fn($state) => strtoupper($state)
                        ),

                    Forms\Components\TextInput::make('rate_percent')
                        ->label('Tax Rate (%)')
                        ->numeric()
                        ->required()
                        ->minValue(0)
                        ->maxValue(100)
                        ->step('0.0001')
                        ->suffix('%'),

                    Forms\Components\Select::make('applies_to')
                        ->label('Applies To')
                        ->options([
                            'all' => 'All Supported Transactions',
                            'transfer' => 'Transfers',
                            'withdrawal' => 'Withdrawals',
                            'payment' => 'Payments',
                            'bill_payment' => 'Bill Payments',
                            'mobile_topup' => 'Mobile Top-ups',
                            'qr_payment' => 'QR Payments',
                        ])
                        ->required()
                        ->default('all'),

                    Forms\Components\Toggle::make('is_active')
                        ->label('Tax Enabled')
                        ->default(false)
                        ->helperText(
                            'Enabling this activates the configuration only. ' .
                            'Transaction calculations are not connected yet.'
                        ),

                    Forms\Components\Toggle::make('is_inclusive')
                        ->label('Tax Included in Price')
                        ->default(false)
                        ->helperText(
                            'On means the configured tax is intended to be included in the price.'
                        ),

                    Forms\Components\Textarea::make('description')
                        ->label('Description')
                        ->rows(3)
                        ->maxLength(2000)
                        ->columnSpanFull(),
                ])
                ->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label('Tax Name')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('code')
                    ->badge()
                    ->searchable(),

                Tables\Columns\TextColumn::make('rate_percent')
                    ->label('Rate')
                    ->formatStateUsing(
                        fn($state) => number_format((float) $state, 4) . '%'
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('applies_to')
                    ->label('Applies To')
                    ->formatStateUsing(
                        fn($state) => str($state)
                            ->replace('_', ' ')
                            ->title()
                    )
                    ->badge(),

                Tables\Columns\IconColumn::make('is_active')
                    ->label('Enabled')
                    ->boolean(),

                Tables\Columns\IconColumn::make('is_inclusive')
                    ->label('Tax Inclusive')
                    ->boolean(),

                Tables\Columns\TextColumn::make('updated_at')
                    ->label('Last Updated')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')
                    ->label('Tax Status'),

                Tables\Filters\SelectFilter::make('applies_to')
                    ->options([
                        'all' => 'All Supported Transactions',
                        'transfer' => 'Transfers',
                        'withdrawal' => 'Withdrawals',
                        'payment' => 'Payments',
                        'bill_payment' => 'Bill Payments',
                        'mobile_topup' => 'Mobile Top-ups',
                        'qr_payment' => 'QR Payments',
                    ]),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),

                Tables\Actions\Action::make('toggleStatus')
                    ->label(
                        fn(TaxSetting $record) =>
                            $record->is_active ? 'Disable' : 'Enable'
                    )
                    ->icon('heroicon-o-power')
                    ->color(
                        fn(TaxSetting $record) =>
                            $record->is_active ? 'danger' : 'success'
                    )
                    ->requiresConfirmation()
                    ->action(function (TaxSetting $record): void {
                        $record->update([
                            'is_active' => !$record->is_active,
                        ]);
                    }),
            ])
            ->bulkActions([])
            ->defaultSort('name');
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->orderBy('name');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListTaxSettings::route('/'),
            'create' => Pages\CreateTaxSetting::route('/create'),
            'edit' => Pages\EditTaxSetting::route('/{record}/edit'),
        ];
    }
}
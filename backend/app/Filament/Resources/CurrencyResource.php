<?php

namespace App\Filament\Resources;

use App\Filament\Resources\CurrencyResource\Pages;
use App\Models\Currency;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

class CurrencyResource extends Resource
{
    protected static ?string $model = Currency::class;

    protected static ?string $navigationIcon = 'heroicon-o-currency-dollar';

    protected static ?string $navigationGroup = 'System Administration';

    protected static ?string $navigationLabel = 'Currencies';

    protected static ?int $navigationSort = 2;

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Currency Information')
                ->schema([
                    Forms\Components\TextInput::make('code')
                        ->label('Currency Code')
                        ->required()
                        ->length(3)
                        ->alpha()
                        ->uppercase()
                        ->unique(ignoreRecord: true)
                        ->helperText('Example: USD, KHR, EUR.'),

                    Forms\Components\TextInput::make('name')
                        ->label('Currency Name')
                        ->required()
                        ->maxLength(100),

                    Forms\Components\TextInput::make('symbol')
                        ->label('Currency Symbol')
                        ->required()
                        ->maxLength(10)
                        ->helperText('Example: $, ៛, €.'),

                    Forms\Components\TextInput::make('exchange_rate')
                        ->label('Units per 1 USD')
                        ->required()
                        ->numeric()
                        ->minValue(0.00000001)
                        ->maxValue(9999999999)
                        ->step(0.00000001)
                        ->helperText(
                            'USD should be 1. KHR may be 4050, depending on your configured rate.'
                        ),

                    Forms\Components\Select::make('rate_update_mode')
                        ->label('Exchange Rate Update Mode')
                        ->options([
                            'automatic' => 'Automatic — update from provider',
                            'manual' => 'Manual — preserve admin rate',
                        ])
                        ->required()
                        ->default('automatic')
                        ->helperText(
                            'Automatic currencies may be updated by the exchange-rate provider. Manual currencies are preserved.'
                        ),

                    Forms\Components\TextInput::make('decimal_places')
                        ->label('Decimal Places')
                        ->required()
                        ->numeric()
                        ->integer()
                        ->minValue(0)
                        ->maxValue(6)
                        ->default(2),

                    Forms\Components\Toggle::make('is_active')
                        ->label('Active')
                        ->default(true),

                    Forms\Components\Toggle::make('is_default')
                        ->label('Default Currency')
                        ->default(false)
                        ->helperText(
                            'Only one currency should be the default.'
                        ),
                ])
                ->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('code')
                    ->label('Code')
                    ->searchable()
                    ->sortable()
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'USD' => 'success',
                        'KHR' => 'info',
                        default => 'gray',
                    }),

                TextColumn::make('name')
                    ->label('Currency')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('symbol')
                    ->label('Symbol'),

                TextColumn::make('exchange_rate')
                    ->label('Units per USD')
                    ->numeric(decimalPlaces: 8)
                    ->sortable(),

                TextColumn::make('rate_update_mode')
                    ->label('Rate Update Mode')
                    ->badge()
                    ->color(fn(?string $state): string => match ($state) {
                        'automatic' => 'success',
                        'manual' => 'warning',
                        default => 'gray',
                    })
                    ->formatStateUsing(
                        fn(?string $state): string =>
                            match ($state) {
                                'automatic' => 'Automatic',
                                'manual' => 'Manual',
                                default => 'Not configured',
                            }
                    ),

                TextColumn::make('decimal_places')
                    ->label('Decimals')
                    ->sortable(),

                Tables\Columns\IconColumn::make('is_active')
                    ->label('Active')
                    ->boolean()
                    ->sortable(),

                Tables\Columns\IconColumn::make('is_default')
                    ->label('Default')
                    ->boolean()
                    ->sortable(),

                TextColumn::make('updated_at')
                    ->label('Last Updated')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')
                    ->label('Active Status'),

                Tables\Filters\TernaryFilter::make('is_default')
                    ->label('Default Currency'),

                Tables\Filters\SelectFilter::make('rate_update_mode')
                    ->label('Rate Update Mode')
                    ->options([
                        'automatic' => 'Automatic',
                        'manual' => 'Manual',
                    ]),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),

                Tables\Actions\Action::make('setDefault')
                    ->label('Set as Default')
                    ->icon('heroicon-o-star')
                    ->color('warning')
                    ->visible(
                        fn(Currency $record): bool =>
                            $record->is_active && !$record->is_default
                    )
                    ->requiresConfirmation()
                    ->action(function (Currency $record): void {
                        DB::transaction(function () use ($record): void {
                            $currencies = Currency::query()
                                ->orderBy('id')
                                ->lockForUpdate()
                                ->get();

                            $target = $currencies->firstWhere(
                                'id',
                                $record->id
                            );

                            if (!$target || !$target->is_active) {
                                return;
                            }

                            Currency::query()->update([
                                'is_default' => false,
                            ]);

                            $target->update([
                                'is_default' => true,
                            ]);
                        });
                    }),

                Tables\Actions\Action::make('toggleStatus')
                    ->label(
                        fn(Currency $record): string =>
                            $record->is_active ? 'Deactivate' : 'Activate'
                    )
                    ->icon('heroicon-o-power')
                    ->color(
                        fn(Currency $record): string =>
                            $record->is_active ? 'danger' : 'success'
                    )
                    ->requiresConfirmation()
                    ->action(function (Currency $record): void {
                        DB::transaction(function () use ($record): void {
                            $currencies = Currency::query()
                                ->orderBy('id')
                                ->lockForUpdate()
                                ->get();

                            $target = $currencies->firstWhere(
                                'id',
                                $record->id
                            );

                            if (!$target) {
                                return;
                            }

                            if (
                                $target->is_active &&
                                $target->is_default
                            ) {
                                \Filament\Notifications\Notification::make()
                                    ->title('Cannot deactivate the default currency')
                                    ->body(
                                        'Set another active currency as default first.'
                                    )
                                    ->danger()
                                    ->send();

                                return;
                            }

                            $target->update([
                                'is_active' => !$target->is_active,
                            ]);
                        });
                    }),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    // Currency deletion is intentionally disabled.
                ]),
            ])
            ->defaultSort('code');
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery();
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListCurrencies::route('/'),
            'create' => Pages\CreateCurrency::route('/create'),
            'edit' => Pages\EditCurrency::route('/{record}/edit'),
        ];
    }
}
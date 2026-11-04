<?php

namespace App\Filament\Resources;

use App\Filament\Resources\MerchantResource\Pages;
use App\Models\Merchant;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\IconColumn;

class MerchantResource extends Resource
{
    protected static ?string $model = Merchant::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-storefront';

    protected static ?string $navigationGroup = 'Merchant Management';

    protected static ?string $navigationLabel = 'Merchants';

    protected static ?string $modelLabel = 'Merchant';

    protected static ?string $pluralModelLabel = 'Merchants';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([

                TextInput::make('merchant_name')
                    ->label('Merchant Name')
                    ->required()
                    ->maxLength(255)
                    ->placeholder('e.g. Phnom Penh Water Supply'),

                TextInput::make('merchant_code')
                    ->label('Merchant Code')
                    ->required()
                    ->unique(ignoreRecord: true)
                    ->maxLength(50)
                    ->placeholder('e.g. PPWSA001')
                    ->helperText('Unique identifier used by the NaNa Wallet system.'),

                Select::make('category')
                    ->label('Merchant Category')
                    ->options([
                        'water' => 'Water',
                        'electricity' => 'Electricity',
                        'mobile' => 'Mobile',
                        'internet' => 'Internet',
                        'education' => 'Education',
                        'government' => 'Government',
                        'retail' => 'Retail',
                        'food' => 'Food & Beverage',
                        'other' => 'Other',
                    ])
                    ->required()
                    ->searchable(),

                TextInput::make('email')
                    ->label('Merchant Email')
                    ->email()
                    ->maxLength(255)
                    ->placeholder('merchant@example.com'),

                TextInput::make('phone')
                    ->label('Merchant Phone')
                    ->tel()
                    ->maxLength(30)
                    ->placeholder('012 345 678'),

                Textarea::make('description')
                    ->label('Description')
                    ->rows(3)
                    ->columnSpanFull()
                    ->placeholder('Describe this merchant or service.'),

                Toggle::make('is_active')
                    ->label('Merchant Active')
                    ->default(true)
                    ->helperText(
                        'Inactive merchants cannot receive new payments.'
                    ),
            ])
            ->columns(2);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([

                TextColumn::make('merchant_name')
                    ->label('Merchant')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('merchant_code')
                    ->label('Merchant Code')
                    ->searchable()
                    ->fontFamily('mono')
                    ->copyable(),

                TextColumn::make('category')
                    ->label('Category')
                    ->badge()
                    ->formatStateUsing(
                        fn(string $state): string =>
                            ucwords(str_replace('_', ' ', $state))
                    )
                    ->color(fn(string $state): string => match ($state) {
                        'water' => 'info',
                        'electricity' => 'warning',
                        'mobile' => 'success',
                        'internet' => 'primary',
                        'education' => 'danger',
                        'government' => 'gray',
                        'retail' => 'success',
                        'food' => 'warning',
                        default => 'gray',
                    })
                    ->sortable(),

                TextColumn::make('email')
                    ->label('Email')
                    ->searchable()
                    ->toggleable(),

                TextColumn::make('phone')
                    ->label('Phone')
                    ->searchable()
                    ->toggleable(),

                IconColumn::make('is_active')
                    ->label('Status')
                    ->boolean()
                    ->sortable(),

                TextColumn::make('created_at')
                    ->label('Created')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])

            ->filters([

                Tables\Filters\SelectFilter::make('category')
                    ->options([
                        'water' => 'Water',
                        'electricity' => 'Electricity',
                        'mobile' => 'Mobile',
                        'internet' => 'Internet',
                        'education' => 'Education',
                        'government' => 'Government',
                        'retail' => 'Retail',
                        'food' => 'Food & Beverage',
                        'other' => 'Other',
                    ]),

                Tables\Filters\TernaryFilter::make('is_active')
                    ->label('Merchant Status')
                    ->placeholder('All Merchants')
                    ->trueLabel('Active Only')
                    ->falseLabel('Inactive Only'),
            ])

            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])

            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListMerchants::route('/'),
            'create' => Pages\CreateMerchant::route('/create'),
            'edit' => Pages\EditMerchant::route('/{record}/edit'),
        ];
    }
}
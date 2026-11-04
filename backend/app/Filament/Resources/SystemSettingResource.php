<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SystemSettingResource\Pages;
use App\Models\SystemSetting;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;

class SystemSettingResource extends Resource
{
    protected static ?string $model = SystemSetting::class;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';

    protected static ?string $navigationGroup = 'System Administration';

    protected static ?string $navigationLabel = 'System Settings';

    protected static ?int $navigationSort = 1;

    private static function allowedSettings(): array
    {
        return [
            'app_name' => 'Application Name',
            'default_currency' => 'Default Currency',
            'default_language' => 'Default Language',
            'maintenance_mode' => 'Maintenance Mode',
            'notifications_enabled' => 'Notifications Enabled',
            'support_email' => 'Support Email',
            'session_timeout_minutes' => 'Session Timeout',
        ];
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Setting Details')
                ->schema([
                    Forms\Components\Select::make('key')
                        ->label('Setting')
                        ->options(self::allowedSettings())
                        ->required()
                        ->unique(ignoreRecord: true)
                        ->disabled(
                            fn(string $operation): bool =>
                                $operation === 'edit'
                        )
                        ->dehydrated(),

                    Forms\Components\TextInput::make('value')
                        ->label('Value')
                        ->requiredUnless('key', 'support_email')
                        ->maxLength(1000)
                        ->visible(
                            fn(Forms\Get $get): bool =>
                                !in_array($get('key'), [
                                    'maintenance_mode',
                                    'notifications_enabled',
                                    'default_currency',
                                    'default_language',
                                ], true)
                        ),

                    Forms\Components\Select::make('value')
                        ->label('Default Currency')
                        ->options([
                            'USD' => 'USD - US Dollar',
                            'KHR' => 'KHR - Cambodian Riel',
                        ])
                        ->required()
                        ->visible(
                            fn(Forms\Get $get): bool =>
                                $get('key') === 'default_currency'
                        ),

                    Forms\Components\Select::make('value')
                        ->label('Default Language')
                        ->options([
                            'en' => 'English',
                            'km' => 'Khmer',
                        ])
                        ->required()
                        ->visible(
                            fn(Forms\Get $get): bool =>
                                $get('key') === 'default_language'
                        ),

                    Forms\Components\Toggle::make('value')
                        ->label('Maintenance Mode')
                        ->formatStateUsing(
                            fn($state): bool =>
                                filter_var($state, FILTER_VALIDATE_BOOLEAN)
                        )
                        ->dehydrateStateUsing(
                            fn($state): string =>
                                $state ? 'true' : 'false'
                        )
                        ->required()
                        ->visible(
                            fn(Forms\Get $get): bool =>
                                $get('key') === 'maintenance_mode'
                        ),

                    Forms\Components\Toggle::make('value')
                        ->label('Notifications Enabled')
                        ->formatStateUsing(
                            fn($state): bool =>
                                filter_var($state, FILTER_VALIDATE_BOOLEAN)
                        )
                        ->dehydrateStateUsing(
                            fn($state): string =>
                                $state ? 'true' : 'false'
                        )
                        ->required()
                        ->visible(
                            fn(Forms\Get $get): bool =>
                                $get('key') === 'notifications_enabled'
                        ),

                    Forms\Components\TextInput::make('value')
                        ->label('Support Email')
                        ->email()
                        ->maxLength(255)
                        ->nullable()
                        ->visible(
                            fn(Forms\Get $get): bool =>
                                $get('key') === 'support_email'
                        ),

                    Forms\Components\TextInput::make('value')
                        ->label('Session Timeout (minutes)')
                        ->numeric()
                        ->integer()
                        ->minValue(5)
                        ->maxValue(1440)
                        ->required()
                        ->visible(
                            fn(Forms\Get $get): bool =>
                                $get('key') === 'session_timeout_minutes'
                        ),

                    Forms\Components\Select::make('group')
                        ->options([
                            'general' => 'General',
                            'currency' => 'Currency',
                            'localization' => 'Localization',
                            'system' => 'System',
                            'notifications' => 'Notifications',
                            'security' => 'Security',
                        ])
                        ->required(),

                    Forms\Components\Textarea::make('description')
                        ->label('Description')
                        ->maxLength(1000)
                        ->columnSpanFull(),
                ])
                ->columns(2),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('key')
                    ->label('Setting')
                    ->formatStateUsing(
                        fn(string $state): string =>
                            self::allowedSettings()[$state] ?? $state
                    )
                    ->searchable()
                    ->sortable(),

                TextColumn::make('value')
                    ->label('Current Value')
                    ->formatStateUsing(function ($state, SystemSetting $record) {
                        if (
                            in_array($record->key, [
                                'maintenance_mode',
                                'notifications_enabled',
                            ], true)
                        ) {
                            return filter_var(
                                $state,
                                FILTER_VALIDATE_BOOLEAN
                            ) ? 'Enabled' : 'Disabled';
                        }

                        return $state === '' || $state === null
                            ? 'Not configured'
                            : (string) $state;
                    })
                    ->wrap(),

                TextColumn::make('group')
                    ->badge()
                    ->sortable(),

                TextColumn::make('description')
                    ->limit(50)
                    ->toggleable(),

                TextColumn::make('updated_at')
                    ->label('Last Updated')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('group')
                    ->options([
                        'general' => 'General',
                        'currency' => 'Currency',
                        'localization' => 'Localization',
                        'system' => 'System',
                        'notifications' => 'Notifications',
                        'security' => 'Security',
                    ]),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    // System settings cannot be bulk deleted.
                ]),
            ])
            ->defaultSort('group')
            ->emptyStateHeading('No system settings found')
            ->emptyStateDescription(
                'Create the supported settings or initialize their default values.'
            );
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSystemSettings::route('/'),
            'create' => Pages\CreateSystemSetting::route('/create'),
            'edit' => Pages\EditSystemSetting::route('/{record}/edit'),
        ];
    }
}
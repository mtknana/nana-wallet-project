<?php

namespace App\Filament\Resources;

use App\Filament\Resources\UserResource\Pages;
use App\Models\User;
use Filament\Forms\Form;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Section;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;
use Illuminate\Support\Facades\Hash;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    protected static ?string $navigationGroup = 'Financial Core';

    protected static ?string $navigationLabel = 'Users';

    // =========================================================
    // FORM
    // =========================================================

    public static function form(Form $form): Form
    {
        return $form
            ->schema([

                Section::make('Account Information')
                    ->schema([

                        TextInput::make('name')
                            ->label('Full Name')
                            ->required()
                            ->maxLength(255),

                        TextInput::make('email')
                            ->label('Email Address')
                            ->email()
                            ->required()
                            ->unique(
                                table: 'users',
                                column: 'email',
                                ignoreRecord: true
                            )
                            ->maxLength(255),

                        Select::make('role')
                            ->label('Account Role')
                            ->options([
                                'user' => 'Standard Client Wallet',
                                'admin' => 'Administrator',
                            ])
                            ->required()
                            ->native(false)
                            ->helperText(
                                'Administrators can manage the financial system. ' .
                                'Only assign this role to authorized staff.'
                            ),
                    ])
                    ->columns(2),

                Section::make('Security')
                    ->schema([

                        TextInput::make('password')
                            ->label('Password')
                            ->password()
                            ->revealable()
                            ->dehydrateStateUsing(
                                fn(?string $state): ?string =>
                                    filled($state)
                                    ? Hash::make($state)
                                    : null
                            )
                            ->dehydrated(
                                fn(?string $state): bool =>
                                    filled($state)
                            )
                            ->required(
                                fn(string $context): bool =>
                                    $context === 'create'
                            )
                            ->minLength(8)
                            ->maxLength(255)
                            ->helperText(
                                'Leave blank when editing to keep the existing password.'
                            ),

                        TextInput::make('password_confirmation')
                            ->label('Confirm Password')
                            ->password()
                            ->revealable()
                            ->same('password')
                            ->required(
                                fn(string $context): bool =>
                                    $context === 'create'
                            )
                            ->dehydrated(false)
                            ->minLength(8)
                            ->maxLength(255),
                    ])
                    ->columns(2),
            ]);
    }

    // =========================================================
    // TABLE
    // =========================================================

    public static function table(Table $table): Table
    {
        return $table
            ->columns([

                TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),

                TextColumn::make('name')
                    ->label('Name')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('email')
                    ->label('Email')
                    ->searchable()
                    ->sortable()
                    ->copyable(),

                TextColumn::make('role')
                    ->label('Role')
                    ->badge()
                    ->formatStateUsing(
                        fn(string $state): string =>
                            match ($state) {
                                'admin' => 'ADMINISTRATOR',
                                'user' => 'CLIENT',
                                default => strtoupper($state),
                            }
                    )
                    ->color(
                        fn(string $state): string =>
                            match ($state) {
                                'admin' => 'danger',
                                'user' => 'success',
                                default => 'gray',
                            }
                    )
                    ->sortable(),

                TextColumn::make('created_at')
                    ->label('Registered')
                    ->dateTime()
                    ->sortable(),
            ])

            // =====================================================
            // FILTERS
            // =====================================================

            ->filters([

                Tables\Filters\SelectFilter::make('role')
                    ->label('Account Role')
                    ->options([
                        'admin' => 'Administrator',
                        'user' => 'Standard Client',
                    ]),
            ])

            // =====================================================
            // ACTIONS
            // =====================================================

            ->actions([
                Tables\Actions\EditAction::make(),
            ])

            // =====================================================
            // BULK ACTIONS
            // =====================================================

            /*
             * Do NOT provide a delete action here.
             *
             * Users are linked to:
             * - Wallets
             * - Transactions
             * - P2P transfers
             * - QR payments
             * - Split bills
             *
             * Deleting a user can therefore damage the financial
             * audit trail.
             */
            ->bulkActions([])

            ->defaultSort('created_at', 'desc');
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
            'index' => Pages\ListUsers::route('/'),
            'create' => Pages\CreateUser::route('/create'),
            'edit' => Pages\EditUser::route('/{record}/edit'),
        ];
    }
}
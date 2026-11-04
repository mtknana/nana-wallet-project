<?php

namespace App\Filament\Resources;

use App\Filament\Resources\WalletResource\Pages;
use App\Models\Wallet;
use App\Models\Transaction;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Select;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\SelectColumn;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class WalletResource extends Resource
{
    protected static ?string $model = Wallet::class;

    protected static ?string $navigationIcon = 'heroicon-o-wallet';

    protected static ?string $navigationGroup = 'Financial Core';

    protected static ?string $navigationLabel = 'Wallets';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Wallet Information')
                    ->schema([
                        Select::make('user_id')
                            ->label('Wallet Holder')
                            ->relationship('user', 'name')
                            ->required()
                            ->searchable()
                            ->preload(),

                        Select::make('currency')
                            ->label('Currency')
                            ->options([
                                'USD' => 'USD - United States Dollar',
                                'KHR' => 'KHR - Cambodian Riel',
                            ])
                            ->required()
                            ->default('USD'),

                        Select::make('status')
                            ->options([
                                'active' => 'Active',
                                'suspended' => 'Suspended',
                                'frozen' => 'Frozen',
                            ])
                            ->required()
                            ->default('active'),
                    ])
                    ->columns(3),

                Forms\Components\Section::make('Wallet Controls')
                    ->description(
                        'Balance should normally be changed through controlled financial adjustments rather than direct editing.'
                    )
                    ->schema([
                        TextInput::make('balance')
                            ->label('Current Balance')
                            ->numeric()
                            ->required()
                            ->default(0)
                            ->disabled(fn(string $context): bool => $context === 'edit')
                            ->dehydrated(fn(string $context): bool => $context === 'create'),

                        TextInput::make('daily_limit')
                            ->label('Daily Transaction Limit')
                            ->numeric()
                            ->required()
                            ->default(1000),

                        TextInput::make('monthly_limit')
                            ->label('Monthly Transaction Limit')
                            ->numeric()
                            ->required()
                            ->default(5000),
                    ])
                    ->columns(3),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),

                TextColumn::make('user.name')
                    ->label('Wallet Holder')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('balance')
                    ->label('Balance')
                    ->formatStateUsing(
                        fn($state, Wallet $record): string =>
                            $record->currency === 'KHR'
                            ? number_format((float) $state, 0) . ' KHR'
                            : '$' . number_format((float) $state, 2)
                    )
                    ->sortable(),

                TextColumn::make('currency')
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'USD' => 'success',
                        'KHR' => 'info',
                        default => 'gray',
                    }),

                SelectColumn::make('status')
                    ->options([
                        'active' => 'Active',
                        'suspended' => 'Suspended',
                        'frozen' => 'Frozen',
                    ])
                    ->sortable(),

                TextColumn::make('daily_limit')
                    ->label('Daily Limit')
                    ->formatStateUsing(
                        fn($state, Wallet $record): string =>
                            $record->currency === 'KHR'
                            ? number_format((float) $state, 0) . ' KHR'
                            : '$' . number_format((float) $state, 2)
                    ),

                TextColumn::make('monthly_limit')
                    ->label('Monthly Limit')
                    ->formatStateUsing(
                        fn($state, Wallet $record): string =>
                            $record->currency === 'KHR'
                            ? number_format((float) $state, 0) . ' KHR'
                            : '$' . number_format((float) $state, 2)
                    ),

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
                        'USD' => 'USD Wallets',
                        'KHR' => 'KHR Wallets',
                    ]),

                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'active' => 'Active',
                        'suspended' => 'Suspended',
                        'frozen' => 'Frozen',
                    ]),
            ])

            ->actions([
                Tables\Actions\Action::make('adjustBalance')
                    ->label('Adjust Balance')
                    ->icon('heroicon-o-adjustments-horizontal')
                    ->color('warning')
                    ->requiresConfirmation()
                    ->modalHeading('Adjust Wallet Balance')
                    ->modalDescription(
                        'Use a positive amount to add funds or a negative amount to deduct funds. This action creates a financial audit transaction.'
                    )
                    ->form([
                        TextInput::make('amount')
                            ->label('Adjustment Amount')
                            ->numeric()
                            ->required()
                            ->helperText(
                                'Positive = credit wallet. Negative = debit wallet.'
                            ),

                        TextInput::make('reason')
                            ->label('Adjustment Reason')
                            ->required()
                            ->maxLength(500),
                    ])
                    ->action(function (Wallet $record, array $data): void {
                        DB::transaction(function () use ($record, $data): void {
                            $wallet = Wallet::where('id', $record->id)
                                ->lockForUpdate()
                                ->firstOrFail();

                            $amount = (float) $data['amount'];

                            if ($amount === 0.0) {
                                throw new \RuntimeException(
                                    'Adjustment amount cannot be zero.'
                                );
                            }

                            if ($amount < 0 && $wallet->balance < abs($amount)) {
                                throw new \RuntimeException(
                                    'Insufficient wallet balance for this deduction.'
                                );
                            }

                            $wallet->increment('balance', $amount);

                            Transaction::create([
                                'user_id' => $wallet->user_id,
                                'type' => $amount > 0
                                    ? 'deposit'
                                    : 'withdrawal',
                                'amount' => abs($amount),
                                'fee_charged' => 0,
                                'currency' => $wallet->currency,
                                'reference_id' => 'ADJ-' . strtoupper(Str::random(10)),
                                'idempotency_key' => 'ADMIN-ADJ-' . Str::uuid(),
                                'status' => 'completed',
                                'description' =>
                                    'Admin Wallet Adjustment: ' .
                                    $data['reason'],
                            ]);
                        });
                    }),

                Tables\Actions\EditAction::make(),
            ])

            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    // Intentionally no wallet deletion.
                ]),
            ])

            ->defaultSort('created_at', 'desc');
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListWallets::route('/'),
            'create' => Pages\CreateWallet::route('/create'),
            'edit' => Pages\EditWallet::route('/{record}/edit'),
        ];
    }
}
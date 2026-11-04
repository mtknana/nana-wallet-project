<?php

namespace App\Filament\Resources;

use App\Filament\Resources\TransactionResource\Pages;
use App\Models\Transaction;
use Filament\Forms\Form;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Select;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;

class TransactionResource extends Resource
{
    protected static ?string $model = Transaction::class;

    protected static ?string $navigationIcon = 'heroicon-o-arrow-path';

    protected static ?string $navigationGroup = 'Financial Core';

    protected static ?string $navigationLabel = 'Transactions';

    // =========================================================
    // READ-ONLY LEDGER
    // =========================================================

    /**
     * Transactions should only be created by the wallet backend.
     *
     * Admins should never manually create ledger transactions
     * because doing so could create money that did not come
     * from an actual wallet operation.
     */
    public static function canCreate(): bool
    {
        return false;
    }

    /**
     * Prevent editing ledger records.
     */
    public static function canEdit($record): bool
    {
        return false;
    }

    /**
     * Prevent deleting ledger records.
     */
    public static function canDelete($record): bool
    {
        return false;
    }

    // =========================================================
    // VIEW FORM
    // =========================================================

    public static function form(Form $form): Form
    {
        return $form
            ->schema([

                Select::make('user_id')
                    ->label('Account Holder')
                    ->relationship('user', 'name')
                    ->disabled(),

                TextInput::make('type')
                    ->label('Transaction Type')
                    ->disabled(),

                TextInput::make('amount')
                    ->label('Amount')
                    ->numeric()
                    ->disabled(),

                TextInput::make('currency')
                    ->label('Currency')
                    ->disabled(),

                TextInput::make('fee_charged')
                    ->label('Service Fee')
                    ->numeric()
                    ->disabled(),

                TextInput::make('reference_id')
                    ->label('Reference ID')
                    ->disabled()
                    ->copyable(),

                TextInput::make('idempotency_key')
                    ->label('Idempotency Key')
                    ->disabled()
                    ->copyable(),

                TextInput::make('status')
                    ->label('Status')
                    ->disabled(),

                Textarea::make('description')
                    ->label('Description')
                    ->disabled()
                    ->rows(3),

                TextInput::make('created_at')
                    ->label('Created At')
                    ->disabled(),
            ]);
    }

    // =========================================================
    // TRANSACTION TABLE
    // =========================================================

    public static function table(Table $table): Table
    {
        return $table
            ->columns([

                // -------------------------------------------------
                // Reference
                // -------------------------------------------------

                TextColumn::make('reference_id')
                    ->label('Reference ID')
                    ->searchable()
                    ->copyable()
                    ->fontFamily('mono')
                    ->sortable(),

                // -------------------------------------------------
                // Account Holder
                // -------------------------------------------------

                TextColumn::make('user.name')
                    ->label('Account Holder')
                    ->searchable()
                    ->sortable(),

                // -------------------------------------------------
                // Transaction Type
                // -------------------------------------------------

                TextColumn::make('type')
                    ->label('Type')
                    ->badge()
                    ->formatStateUsing(
                        fn(string $state): string =>
                            strtoupper(
                                str_replace('_', ' ', $state)
                            )
                    )
                    ->color(
                        fn(string $state): string =>
                            match ($state) {

                                // Money entering a customer wallet
                                'deposit',
                                'payment_received',
                                'fee_income'
                                => 'success',

                                // Money leaving a customer wallet
                                'withdrawal',
                                'transfer_out',
                                'bill_payment',
                                'mobile_topup',
                                'payment'
                                => 'danger',

                                // Refund / reversal
                                'refund',
                                'fee_reversal'
                                => 'warning',

                                // Neutral/system transactions
                                'transfer_in'
                                => 'success',

                                default
                                => 'gray',
                            }
                    )
                    ->sortable(),

                // -------------------------------------------------
                // Amount
                // -------------------------------------------------

                TextColumn::make('amount')
                    ->label('Amount')
                    ->formatStateUsing(
                        fn($state, Transaction $record): string =>
                            strtoupper($record->currency ?? 'USD')
                            . ' '
                            . number_format(
                                (float) $state,
                                2
                            )
                    )
                    ->sortable(),

                // -------------------------------------------------
                // Currency
                // -------------------------------------------------

                TextColumn::make('currency')
                    ->label('Currency')
                    ->badge()
                    ->color(
                        fn(string $state): string =>
                            match (strtoupper($state)) {
                                'USD' => 'success',
                                'KHR' => 'warning',
                                default => 'gray',
                            }
                    )
                    ->sortable(),

                // -------------------------------------------------
                // Fee
                // -------------------------------------------------

                TextColumn::make('fee_charged')
                    ->label('Fee')
                    ->formatStateUsing(
                        fn($state, Transaction $record): string =>
                            strtoupper($record->currency ?? 'USD')
                            . ' '
                            . number_format(
                                (float) ($state ?? 0),
                                2
                            )
                    )
                    ->sortable(),

                // -------------------------------------------------
                // Status
                // -------------------------------------------------

                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->color(
                        fn(?string $state): string =>
                            match ($state) {
                                'completed' => 'success',
                                'pending' => 'warning',
                                'failed',
                                'cancelled' => 'danger',
                                default => 'gray',
                            }
                    )
                    ->sortable(),

                // -------------------------------------------------
                // Description
                // -------------------------------------------------

                TextColumn::make('description')
                    ->label('Audit Description')
                    ->searchable()
                    ->limit(45)
                    ->tooltip(
                        fn(Transaction $record): ?string =>
                            $record->description
                    ),

                // -------------------------------------------------
                // Timestamp
                // -------------------------------------------------

                TextColumn::make('created_at')
                    ->label('Logged Timestamp')
                    ->dateTime()
                    ->sortable(),
            ])

            // =====================================================
            // FILTERS
            // =====================================================

            ->filters([

                Tables\Filters\SelectFilter::make('type')
                    ->label('Transaction Type')
                    ->options([

                        'deposit' => 'Deposit',

                        'withdrawal' => 'Withdrawal',

                        'transfer_out' => 'Transfer Out',

                        'transfer_in' => 'Transfer In',

                        'payment' => 'Merchant Payment',

                        'bill_payment' => 'Bill Payment',

                        'mobile_topup' => 'Mobile Top-up',

                        'payment_received' => 'Payment Received',

                        'fee_income' => 'Fee Income',

                        'refund' => 'Refund',

                        'fee_reversal' => 'Fee Reversal',
                    ]),

                Tables\Filters\SelectFilter::make('currency')
                    ->label('Currency')
                    ->options([
                        'USD' => 'USD',
                        'KHR' => 'KHR',
                    ]),

                Tables\Filters\SelectFilter::make('status')
                    ->label('Status')
                    ->options([
                        'completed' => 'Completed',
                        'pending' => 'Pending',
                        'failed' => 'Failed',
                        'cancelled' => 'Cancelled',
                    ]),
            ])

            // =====================================================
            // ACTIONS
            // =====================================================

            ->actions([
                Tables\Actions\ViewAction::make(),
            ])

            // =====================================================
            // DEFAULT SORT
            // =====================================================

            ->defaultSort('created_at', 'desc');
    }

    // =========================================================
    // PAGES
    // =========================================================

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListTransactions::route('/'),
        ];
    }
}
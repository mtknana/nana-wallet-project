<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ExpenseResource\Pages;
use App\Models\Expense;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class ExpenseResource extends Resource
{
    protected static ?string $model = Expense::class;

    protected static ?string $navigationIcon = 'heroicon-o-receipt-percent';

    protected static ?string $navigationLabel = 'Daily Expenses';

    protected static ?string $navigationGroup = 'Financial Management';

    protected static ?int $navigationSort = 5;

    protected static ?string $modelLabel = 'Expense';

    protected static ?string $pluralModelLabel = 'Daily Expenses';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Select::make('user_id')
                    ->label('Customer')
                    ->relationship(
                        name: 'user',
                        titleAttribute: 'name'
                    )
                    ->searchable()
                    ->preload()
                    ->required(),

                Forms\Components\Select::make('category')
                    ->label('Category')
                    ->options([
                        'food' => 'Food',
                        'transport' => 'Transport',
                        'study' => 'Study Costs',
                        'other' => 'Other',
                    ])
                    ->required(),

                Forms\Components\TextInput::make('amount')
                    ->label('Amount')
                    ->numeric()
                    ->minValue(0.01)
                    ->required(),

                Forms\Components\Select::make('currency')
                    ->label('Currency')
                    ->options([
                        'USD' => 'USD',
                        'KHR' => 'KHR',
                    ])
                    ->default('USD')
                    ->required(),

                Forms\Components\TextInput::make('description')
                    ->label('Description')
                    ->maxLength(255)
                    ->placeholder('e.g. Lunch, Bus fare, Books'),

                Forms\Components\DatePicker::make('expense_date')
                    ->label('Expense Date')
                    ->default(now())
                    ->required(),
            ])
            ->columns(2);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('expense_date', 'desc')
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.name')
                    ->label('Customer')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('category')
                    ->label('Category')
                    ->badge()
                    ->formatStateUsing(
                        fn(string $state): string => match ($state) {
                            'food' => 'Food',
                            'transport' => 'Transport',
                            'study' => 'Study Costs',
                            'other' => 'Other',
                            default => ucfirst($state),
                        }
                    )
                    ->color(
                        fn(string $state): string => match ($state) {
                            'food' => 'warning',
                            'transport' => 'info',
                            'study' => 'primary',
                            'other' => 'gray',
                            default => 'gray',
                        }
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('amount')
                    ->label('Amount')
                    ->numeric(
                        decimalPlaces: 2
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('currency')
                    ->label('Currency')
                    ->badge()
                    ->sortable(),

                Tables\Columns\TextColumn::make('description')
                    ->label('Description')
                    ->limit(35)
                    ->searchable()
                    ->toggleable(),

                Tables\Columns\TextColumn::make('expense_date')
                    ->label('Expense Date')
                    ->date()
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Created')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('category')
                    ->options([
                        'food' => 'Food',
                        'transport' => 'Transport',
                        'study' => 'Study Costs',
                        'other' => 'Other',
                    ]),

                Tables\Filters\SelectFilter::make('currency')
                    ->options([
                        'USD' => 'USD',
                        'KHR' => 'KHR',
                    ]),

                Tables\Filters\Filter::make('expense_date')
                    ->form([
                        Forms\Components\DatePicker::make('from')
                            ->label('From'),

                        Forms\Components\DatePicker::make('until')
                            ->label('Until'),
                    ])
                    ->query(
                        function (Builder $query, array $data): Builder {
                            return $query
                                ->when(
                                    $data['from'] ?? null,
                                    fn(
                                    Builder $query,
                                    $date
                                ) => $query->whereDate(
                                            'expense_date',
                                            '>=',
                                            $date
                                        )
                                )
                                ->when(
                                    $data['until'] ?? null,
                                    fn(
                                    Builder $query,
                                    $date
                                ) => $query->whereDate(
                                            'expense_date',
                                            '<=',
                                            $date
                                        )
                                );
                        }
                    ),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),

                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListExpenses::route('/'),
            'create' => Pages\CreateExpense::route('/create'),
            'edit' => Pages\EditExpense::route('/{record}/edit'),
        ];
    }
}
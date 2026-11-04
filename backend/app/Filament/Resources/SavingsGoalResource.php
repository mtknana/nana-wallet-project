<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SavingsGoalResource\Pages;
use App\Models\SavingsGoal;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class SavingsGoalResource extends Resource
{
    protected static ?string $model = SavingsGoal::class;

    protected static ?string $navigationIcon =
        'heroicon-o-trophy';

    protected static ?string $navigationLabel =
        'Savings Goals';

    protected static ?string $navigationGroup =
        'Financial Management';

    protected static ?int $navigationSort = 6;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Select::make('user_id')
                    ->label('Customer')
                    ->relationship(
                        'user',
                        'name',
                        fn(Builder $query) =>
                            $query->where('role', 'user')
                    )
                    ->searchable()
                    ->preload()
                    ->required(),

                Forms\Components\TextInput::make('name')
                    ->label('Goal Name')
                    ->required()
                    ->maxLength(255)
                    ->placeholder('e.g. New Laptop'),

                Forms\Components\Textarea::make('description')
                    ->label('Description')
                    ->rows(3)
                    ->maxLength(255)
                    ->placeholder(
                        'Optional description for this savings goal.'
                    ),

                Forms\Components\TextInput::make('target_amount')
                    ->label('Target Amount')
                    ->numeric()
                    ->required()
                    ->minValue(0.01)
                    ->step(0.01),

                Forms\Components\TextInput::make('current_amount')
                    ->label('Current Saved Amount')
                    ->numeric()
                    ->required()
                    ->default(0)
                    ->minValue(0)
                    ->step(0.01),

                Forms\Components\Select::make('currency')
                    ->label('Currency')
                    ->options([
                        'USD' => 'USD',
                        'KHR' => 'KHR',
                    ])
                    ->required()
                    ->default('USD'),

                Forms\Components\DatePicker::make('target_date')
                    ->label('Target Date')
                    ->native(false),

                Forms\Components\Select::make('status')
                    ->label('Status')
                    ->options([
                        'active' => 'Active',
                        'completed' => 'Completed',
                        'cancelled' => 'Cancelled',
                    ])
                    ->required()
                    ->default('active'),
            ])
            ->columns(2);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('#')
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.name')
                    ->label('Customer')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('name')
                    ->label('Goal')
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),

                Tables\Columns\TextColumn::make('target_amount')
                    ->label('Target')
                    ->numeric(
                        decimalPlaces: 2
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('current_amount')
                    ->label('Saved')
                    ->numeric(
                        decimalPlaces: 2
                    )
                    ->sortable(),

                Tables\Columns\TextColumn::make('currency')
                    ->badge()
                    ->color(
                        fn(string $state): string =>
                            $state === 'USD'
                            ? 'success'
                            : 'info'
                    ),

                Tables\Columns\TextColumn::make('progress_percentage')
                    ->label('Progress')
                    ->state(
                        fn(SavingsGoal $record): string =>
                            number_format(
                                $record->progress_percentage,
                                2
                            ) . '%'
                    )
                    ->sortable(false),

                Tables\Columns\TextColumn::make('target_date')
                    ->label('Target Date')
                    ->date()
                    ->sortable(),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->colors([
                        'warning' => 'active',
                        'success' => 'completed',
                        'danger' => 'cancelled',
                    ]),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Created')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])

            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'active' => 'Active',
                        'completed' => 'Completed',
                        'cancelled' => 'Cancelled',
                    ]),

                Tables\Filters\SelectFilter::make('currency')
                    ->options([
                        'USD' => 'USD',
                        'KHR' => 'KHR',
                    ]),

                Tables\Filters\SelectFilter::make('user_id')
                    ->label('Customer')
                    ->relationship(
                        'user',
                        'name',
                        fn(Builder $query) =>
                            $query->where('role', 'user')
                    )
                    ->searchable()
                    ->preload(),
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

            ->defaultSort(
                'created_at',
                'desc'
            );
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' =>
                Pages\ListSavingsGoals::route('/'),

            'create' =>
                Pages\CreateSavingsGoal::route('/create'),

            'edit' =>
                Pages\EditSavingsGoal::route(
                    '/{record}/edit'
                ),
        ];
    }
}
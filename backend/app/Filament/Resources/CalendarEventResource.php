<?php

namespace App\Filament\Resources;

use App\Filament\Resources\CalendarEventResource\Pages;
use App\Models\CalendarEvent;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;

class CalendarEventResource extends Resource
{
    protected static ?string $model = CalendarEvent::class;

    protected static ?string $navigationIcon = 'heroicon-o-calendar';

    protected static ?string $navigationGroup = 'Integrations';

    protected static ?string $navigationLabel = 'Calendar Events';

    protected static ?string $modelLabel = 'Calendar Event';

    protected static ?string $pluralModelLabel = 'Calendar Events';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Select::make('user_id')
                    ->label('User')
                    ->relationship('user', 'name')
                    ->required()
                    ->searchable()
                    ->preload()
                    ->native(false)
                    ->helperText(
                        'Select the wallet user associated with this event.'
                    ),

                TextInput::make('title')
                    ->label('Commitment Title')
                    ->placeholder('e.g. WiFi Bill, School Fee, Salary')
                    ->required()
                    ->maxLength(255),

                Select::make('category')
                    ->label('Category')
                    ->options([
                        'payroll' => 'Payroll Inflow',
                        'bill' => 'Utility / Service Bill Outflow',
                        'school_fees' => 'Education / School Fees Outflow',
                    ])
                    ->required()
                    ->native(false)
                    ->searchable(),

                Select::make('currency')
                    ->label('Currency')
                    ->options([
                        'USD' => 'USD — US Dollar',
                        'KHR' => 'KHR — Cambodian Riel',
                    ])
                    ->default('USD')
                    ->required()
                    ->native(false)
                    ->live()
                    ->helperText(
                        'Select the currency used for this commitment.'
                    ),

                TextInput::make('estimated_amount')
                    ->label('Estimated Amount')
                    ->numeric()
                    ->minValue(0)
                    ->step(0.01)
                    ->required()
                    ->prefix(
                        fn(Forms\Get $get): string =>
                            $get('currency') === 'KHR'
                            ? '៛'
                            : '$'
                    )
                    ->helperText(
                        fn(Forms\Get $get): string =>
                            $get('currency') === 'KHR'
                            ? 'Enter the estimated amount in Cambodian Riel.'
                            : 'Enter the estimated amount in US Dollars.'
                    ),

                DatePicker::make('due_date')
                    ->label('Due Date')
                    ->required()
                    ->native(false)
                    ->displayFormat('d M Y')
                    ->closeOnDateSelection(),

                Toggle::make('is_recurring')
                    ->label('Recurring Event')
                    ->helperText(
                        'Enable this if the event repeats automatically.'
                    )
                    ->live()
                    ->afterStateUpdated(
                        function (Forms\Set $set, ?bool $state): void {
                            if (!$state) {
                                $set('recurrence_period', null);
                            }
                        }
                    ),

                Select::make('recurrence_period')
                    ->label('Recurrence Period')
                    ->options([
                        'weekly' => 'Weekly',
                        'monthly' => 'Monthly',
                    ])
                    ->required(
                        fn(Forms\Get $get): bool =>
                            (bool) $get('is_recurring')
                    )
                    ->visible(
                        fn(Forms\Get $get): bool =>
                            (bool) $get('is_recurring')
                    )
                    ->native(false)
                    ->placeholder('Select recurrence period'),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('due_date', 'asc')
            ->columns([
                TextColumn::make('user.name')
                    ->label('User')
                    ->searchable()
                    ->sortable()
                    ->description(
                        fn(CalendarEvent $record): ?string =>
                            $record->user?->email
                    ),

                TextColumn::make('title')
                    ->label('Commitment')
                    ->searchable()
                    ->sortable()
                    ->wrap(),

                TextColumn::make('category')
                    ->label('Category')
                    ->badge()
                    ->formatStateUsing(
                        fn(?string $state): string => match ($state) {
                            'payroll' => 'Payroll Inflow',
                            'bill' => 'Utility / Service Bill',
                            'school_fees' => 'School Fees',
                            default => ucfirst(
                                str_replace(
                                    '_',
                                    ' ',
                                    $state ?? 'Unknown'
                                )
                            ),
                        }
                    )
                    ->color(
                        fn(?string $state): string => match ($state) {
                            'payroll' => 'success',
                            'bill' => 'warning',
                            'school_fees' => 'danger',
                            default => 'gray',
                        }
                    )
                    ->sortable(),

                TextColumn::make('currency')
                    ->label('Currency')
                    ->badge()
                    ->color(
                        fn(?string $state): string => match ($state) {
                            'USD' => 'info',
                            'KHR' => 'success',
                            default => 'gray',
                        }
                    )
                    ->sortable(),

                TextColumn::make('estimated_amount')
                    ->label('Estimated Amount')
                    ->formatStateUsing(
                        fn(
                        $state,
                        CalendarEvent $record
                    ): string => $record->currency === 'KHR'
                            ? '៛ ' . number_format((float) $state, 2)
                            : '$ ' . number_format((float) $state, 2)
                    )
                    ->sortable(),

                TextColumn::make('due_date')
                    ->label('Due Date')
                    ->date('d M Y')
                    ->sortable(),

                IconColumn::make('is_recurring')
                    ->label('Recurring')
                    ->boolean()
                    ->sortable(),

                TextColumn::make('recurrence_period')
                    ->label('Repeat')
                    ->badge()
                    ->formatStateUsing(
                        fn(?string $state): string => match ($state) {
                            'weekly' => 'Weekly',
                            'monthly' => 'Monthly',
                            default => 'One-time',
                        }
                    )
                    ->color(
                        fn(?string $state): string => match ($state) {
                            'weekly',
                            'monthly' => 'info',
                            default => 'gray',
                        }
                    )
                    ->toggleable(),
            ])
            ->filters([
                SelectFilter::make('category')
                    ->label('Category')
                    ->options([
                        'payroll' => 'Payroll',
                        'bill' => 'Utility / Service Bill',
                        'school_fees' => 'School Fees',
                    ]),

                SelectFilter::make('currency')
                    ->label('Currency')
                    ->options([
                        'USD' => 'USD',
                        'KHR' => 'KHR',
                    ]),

                TernaryFilter::make('is_recurring')
                    ->label('Recurring')
                    ->placeholder('All events')
                    ->trueLabel('Recurring only')
                    ->falseLabel('One-time only'),
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
            ->emptyStateHeading('No calendar events')
            ->emptyStateDescription(
                'Create a calendar event to track upcoming financial commitments.'
            )
            ->emptyStateIcon('heroicon-o-calendar');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListCalendarEvents::route('/'),
            'create' => Pages\CreateCalendarEvent::route('/create'),
            'edit' => Pages\EditCalendarEvent::route('/{record}/edit'),
        ];
    }
}
<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ChatbotLogResource\Pages;
use App\Models\ChatbotLog;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class ChatbotLogResource extends Resource
{
    protected static ?string $model = ChatbotLog::class;

    protected static ?string $navigationIcon = 'heroicon-o-chat-bubble-left-right';

    protected static ?string $navigationLabel = 'Chatbot Logs';

    protected static ?string $navigationGroup = 'AI & Analytics';

    protected static ?int $navigationSort = 10;

    public static function canViewAny(): bool
    {
        return auth()->user()?->role === 'admin';
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit($record): bool
    {
        return false;
    }

    public static function canDelete($record): bool
    {
        return false;
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->with('user');
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('Log ID')
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.email')
                    ->label('User Email')
                    ->placeholder('Deleted user')
                    ->searchable(),

                Tables\Columns\TextColumn::make('message')
                    ->label('User Message')
                    ->limit(80)
                    ->wrap()
                    ->searchable(),

                Tables\Columns\TextColumn::make('intent')
                    ->badge()
                    ->placeholder('Unknown')
                    ->sortable(),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(
                        fn(string $state): string =>
                            $state === 'success' ? 'success' : 'danger'
                    ),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Time')
                    ->dateTime()
                    ->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('intent')
                    ->options([
                        'greeting' => 'Greeting',
                        'wallet_balance' => 'Wallet Balance',
                        'spending_summary' => 'Spending Summary',
                        'spending_prediction' => 'Spending Prediction',
                        'recommendations' => 'Recommendations',
                        'savings_goals' => 'Savings Goals',
                        'help' => 'Help',
                    ]),

                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'success' => 'Success',
                        'failed' => 'Failed',
                    ]),
            ])
            ->actions([])
            ->bulkActions([]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListChatbotLogs::route('/'),
        ];
    }
}
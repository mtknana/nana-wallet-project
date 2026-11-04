<?php

namespace App\Filament\Widgets;

use App\Models\Loan;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Illuminate\Database\Eloquent\Builder;

class OverdueLoanTable extends BaseWidget
{
    protected static ?string $heading = 'Overdue Loans';

    protected static ?int $sort = 4;

    public function table(Table $table): Table
    {
        $query = Loan::query()
            ->with('user')
            ->whereIn('status', [
                'active',
                'overdue',
                'partially_paid',
            ])
            ->where('outstanding_principal', '>', 0)
            ->where('due_at', '<', now())
            ->orderBy('due_at', 'asc');

        /** @var Builder $query */

        return $table
            ->query($query)
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('Loan ID')
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.name')
                    ->label('Customer')
                    ->searchable(),

                Tables\Columns\TextColumn::make('principal')
                    ->label('Principal')
                    ->formatStateUsing(
                        fn($state, Loan $record) =>
                            $record->currency . ' ' . number_format((float) $state, 2)
                    ),

                Tables\Columns\TextColumn::make('outstanding_principal')
                    ->label('Outstanding')
                    ->formatStateUsing(
                        fn($state, Loan $record) =>
                            $record->currency . ' ' . number_format((float) $state, 2)
                    )
                    ->color('danger'),

                Tables\Columns\TextColumn::make('due_at')
                    ->label('Due Date')
                    ->dateTime('d M Y')
                    ->sortable(),

                Tables\Columns\TextColumn::make('days_overdue')
                    ->label('Days Overdue')
                    ->getStateUsing(
                        fn(Loan $record) =>
                            $record->due_at
                            ? (int) $record->due_at->diffInDays(now())
                            : 0
                    )
                    ->suffix(' days')
                    ->color('danger'),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color('danger')
                    ->formatStateUsing(fn() => 'Overdue'),
            ])
            ->defaultSort('due_at', 'asc');
    }
}
<?php

namespace Tests\Feature;

use App\Models\Currency;
use App\Models\Loan;
use App\Models\LoanRepayment;
use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;
use App\Services\LoanRepaymentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class LoanRepaymentIdempotencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_replaying_the_same_manual_repayment_does_not_transfer_twice(): void
    {
        [$borrower, $funder, $loan, $borrowerWallet] = $this->makeLoan('USD', 2);
        $service = app(LoanRepaymentService::class);

        $service->repayManually($loan->id, $borrower->id, '10.25', 'retry-safe-key');
        $service->repayManually($loan->id, $borrower->id, '10.25', 'retry-safe-key');

        $this->assertSame('14.75', $borrowerWallet->fresh()->balance);
        $this->assertSame('89.75', $loan->fresh()->outstanding_principal);
        $this->assertSame(1, Transaction::where('type', 'loan_repayment')->count());
        $this->assertSame(1, Transaction::where('type', 'loan_repayment_received')->count());
        $this->assertDatabaseHas('loan_repayments', [
            'loan_id' => $loan->id,
            'amount_collected' => '10.25',
            'remaining_amount' => '89.75',
            'status' => 'partial',
        ]);
    }

    public function test_same_key_with_a_different_amount_is_rejected(): void
    {
        [$borrower, , $loan, $borrowerWallet] = $this->makeLoan('USD', 2);
        $service = app(LoanRepaymentService::class);
        $service->repayManually($loan->id, $borrower->id, '10.00', 'single-use-key');

        try {
            $service->repayManually($loan->id, $borrower->id, '11.00', 'single-use-key');
            $this->fail('A reused key with a changed amount should be rejected.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('idempotency_key', $exception->errors());
        }

        $this->assertSame('15.00', $borrowerWallet->fresh()->balance);
        $this->assertSame('90.00', $loan->fresh()->outstanding_principal);
        $this->assertSame(1, Transaction::where('type', 'loan_repayment')->count());
    }

    public function test_usd_repayment_with_more_than_two_decimal_places_is_rejected(): void
    {
        [$borrower, , $loan, $borrowerWallet] = $this->makeLoan('USD', 2);

        try {
            app(LoanRepaymentService::class)->repayManually(
                $loan->id,
                $borrower->id,
                '1.001',
                'overprecision-key'
            );
            $this->fail('Over-precision input should be rejected.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('amount', $exception->errors());
        }

        $this->assertSame('25.00', $borrowerWallet->fresh()->balance);
        $this->assertSame('100.00', $loan->fresh()->outstanding_principal);
        $this->assertSame(0, Transaction::where('type', 'loan_repayment')->count());
    }

    public function test_khr_repayment_must_be_a_whole_number(): void
    {
        [$borrower, , $loan, $borrowerWallet] = $this->makeLoan('KHR', 0);

        try {
            app(LoanRepaymentService::class)->repayManually(
                $loan->id,
                $borrower->id,
                '1.5',
                'khr-fraction-key'
            );
            $this->fail('KHR repayment should not accept a fractional amount.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('amount', $exception->errors());
        }

        $this->assertSame('25.00', $borrowerWallet->fresh()->balance);
        $this->assertSame('100.00', $loan->fresh()->outstanding_principal);
        $this->assertSame(0, Transaction::where('type', 'loan_repayment')->count());
    }

    private function makeLoan(string $code, int $decimals): array
    {
        Currency::create([
            'code' => $code,
            'name' => $code === 'USD' ? 'US Dollar' : 'Cambodian Riel',
            'symbol' => $code === 'USD' ? '$' : '៛',
            'exchange_rate' => 1,
            'decimal_places' => $decimals,
            'is_active' => true,
            'is_default' => $code === 'USD',
        ]);

        $borrower = User::factory()->create(['role' => 'user']);
        $funder = User::factory()->create(['role' => 'admin']);
        $borrowerWallet = Wallet::create([
            'user_id' => $borrower->id,
            'balance' => 25,
            'currency' => $code,
            'status' => 'active',
        ]);
        Wallet::create([
            'user_id' => $funder->id,
            'balance' => 500,
            'currency' => $code,
            'status' => 'active',
        ]);
        $loan = Loan::create([
            'user_id' => $borrower->id,
            'funded_by_user_id' => $funder->id,
            'principal' => 100,
            'interest_rate' => 5,
            'upfront_interest' => 5,
            'disbursed_amount' => 95,
            'outstanding_principal' => 100,
            'currency' => $code,
            'term_days' => 7,
            'due_at' => now()->addDays(7),
            'status' => 'active',
            'idempotency_key' => (string) Str::uuid(),
            'disbursed_at' => now(),
        ]);
        LoanRepayment::create([
            'loan_id' => $loan->id,
            'amount_due' => 100,
            'amount_collected' => 0,
            'remaining_amount' => 100,
            'currency' => $code,
            'status' => 'pending',
            'reference_id' => (string) Str::uuid(),
        ]);

        return [$borrower, $funder, $loan, $borrowerWallet];
    }
}

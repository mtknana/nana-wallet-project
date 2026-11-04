<?php

namespace App\Console\Commands;

use App\Services\LoanRepaymentService;
use Illuminate\Console\Command;

class ProcessDueLoanRepayments extends Command
{
    protected $signature = 'loans:process-due';

    protected $description = 'Process due NaNa Quick Loan repayments';

    public function handle(LoanRepaymentService $service): int
    {
        $count = $service->processDueLoans();

        $this->info("Loan repayment processing completed. Loans processed: {$count}");

        return self::SUCCESS;
    }
}
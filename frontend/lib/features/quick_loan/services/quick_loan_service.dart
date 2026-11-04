import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class QuickLoanService {
  // ==========================================================
  // NANA QUICK LOAN
  // ==========================================================

  // Get the user's loan history.
  static Future<Map<String, dynamic>> fetchLoans({required String token}) {
    return WalletService.fetchLoans(token: token);
  }

  // Apply for a new loan.
  static Future<Map<String, dynamic>> applyForLoan({
    required String token,
    required double amount,
    required String currency,
    required int termDays,
    required String idempotencyKey,
  }) {
    return WalletService.applyForLoan(
      token: token,
      amount: amount,
      currency: currency,
      termDays: termDays,
      idempotencyKey: idempotencyKey,
    );
  }

  // Get details of a specific loan.
  static Future<Map<String, dynamic>> fetchLoanDetails({
    required String token,
    required int loanId,
  }) {
    return WalletService.fetchLoanDetails(token: token, loanId: loanId);
  }

  // Manually repay an existing loan.
  static Future<Map<String, dynamic>> repayLoan({
    required String token,
    required int loanId,
    required double amount,
    required String idempotencyKey,
  }) {
    return WalletService.repayLoan(
      token: token,
      loanId: loanId,
      amount: amount,
      idempotencyKey: idempotencyKey,
    );
  }
}

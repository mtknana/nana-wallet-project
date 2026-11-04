import 'package:flutter/material.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/theme/app_theme_controller.dart';

import 'package:digital_wallet_app/features/auth/presentation/login_screen.dart';

import 'package:digital_wallet_app/features/wallet/presentation/camera_test_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/wallet_dashboard_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/p2p_transfer_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/split_bill_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/qr_payment_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/bill_payment_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/mobile_topup_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/deposit_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/withdraw_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/settings_screen.dart';

import 'package:digital_wallet_app/features/wallet/presentation/transaction_pin_setup_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/transaction_pin_verify_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/transaction_pin_change_screen.dart';

import 'package:digital_wallet_app/features/wallet/presentation/change_password_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/profile_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/security_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/my_qr_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/receive_money_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/wallet_transfer_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/scheduled_payment_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/payment_confirmation_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/payment_history_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/wallet_overview_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/pdf_statement_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/transaction_notifications_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/spending_prediction_screen.dart';
import 'package:digital_wallet_app/features/chatbot/presentation/chatbot_screen.dart';
import 'package:digital_wallet_app/features/quick_loan/presentation/quick_loan_screen.dart';
import 'package:digital_wallet_app/features/quick_loan/presentation/apply_loan_screen.dart';
import 'package:digital_wallet_app/features/quick_loan/presentation/loan_details_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.load();

  runApp(DigitalWalletApp());
}

class DigitalWalletApp extends StatelessWidget {
  DigitalWalletApp({super.key});

  // ============================================================
  // SAFE TOKEN HELPER
  // ============================================================

  String? _getToken(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is String && arguments.trim().isNotEmpty) {
      return arguments.trim();
    }

    if (arguments is Map) {
      final token = arguments['token'];

      if (token is String && token.trim().isNotEmpty) {
        return token.trim();
      }
    }

    return null;
  }

  // ============================================================
  // TOKEN ERROR SCREEN
  // ============================================================

  Widget _missingTokenScreen({
    required BuildContext context,
    required String screenName,
  }) {
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'NaNa Wallet',
          style: TextStyle(
            color: AppColors.themeText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.adaptiveSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.themeText.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.10),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '$screenName requires login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your authentication session is missing. '
                  'Please login again to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB7C4C8),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: AppColors.themeText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'GO TO LOGIN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);

    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'Group 8 - Digital Wallet',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(dark: false),
        darkTheme: _buildTheme(dark: true),
        themeMode: AppThemeController.instance.themeMode,

        // ========================================================
        // INITIAL ROUTE
        // ========================================================
        initialRoute: '/login',

        // ========================================================
        // GLOBAL NAMED ROUTES
        // ========================================================
        routes: {
          '/camera-test': (context) => CameraTestScreen(),

          // ------------------------------------------------------
          // AUTH
          // ------------------------------------------------------
          '/login': (context) => LoginScreen(),

          // ------------------------------------------------------
          // MAIN WALLET
          // ------------------------------------------------------
          '/dashboard': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;

            return WalletDashboardScreen(
              activeToken: arguments is String ? arguments : null,
            );
          },

          '/p2p-transfer': (context) => P2pTransferScreen(),

          '/split-bill': (context) => SplitBillScreen(),

          '/pay-qr': (context) => QrPaymentScreen(),

          '/pay-bill': (context) => BillPaymentScreen(),

          '/top-up': (context) => MobileTopUpScreen(),

          '/deposit': (context) => DepositScreen(),

          '/withdraw': (context) => WithdrawScreen(),

          // ------------------------------------------------------
          // SETTINGS
          // ------------------------------------------------------
          '/settings': (context) => SettingsScreen(),

          // ------------------------------------------------------
          // US-086 — SPENDING PREDICTION
          // ------------------------------------------------------
          '/spending-prediction': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Spending Prediction',
              );
            }

            return SpendingPredictionScreen(token: token);
          },

          // ------------------------------------------------------
          // TRANSACTION NOTIFICATIONS
          // ------------------------------------------------------
          '/transaction-notifications': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Transaction Notifications',
              );
            }

            return TransactionNotificationsScreen(token: token);
          },

          // ------------------------------------------------------
          // TRANSACTION PIN
          // ------------------------------------------------------
          '/transaction-pin-setup': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Transaction PIN Setup',
              );
            }

            return TransactionPinSetupScreen(token: token);
          },

          '/transaction-pin-verify': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Transaction PIN Verification',
              );
            }

            return TransactionPinVerifyScreen(token: token);
          },

          '/transaction-pin-change': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Transaction PIN Change',
              );
            }

            return TransactionPinChangeScreen(token: token);
          },

          // ------------------------------------------------------
          // ACCOUNT
          // ------------------------------------------------------
          '/change-password': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Change Password',
              );
            }

            return ChangePasswordScreen(token: token);
          },

          '/profile': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Profile',
              );
            }

            return ProfileScreen(token: token);
          },

          '/security': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Security',
              );
            }

            return SecurityScreen(token: token);
          },

          // ------------------------------------------------------
          // QR / RECEIVE MONEY
          // ------------------------------------------------------
          '/my-qr': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(context: context, screenName: 'My QR');
            }

            return MyQrScreen(token: token);
          },

          '/receive-money': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Receive Money',
              );
            }

            return ReceiveMoneyScreen(token: token);
          },

          // ------------------------------------------------------
          // WALLET TRANSFER
          // ------------------------------------------------------
          '/wallet-transfer': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Wallet Transfer',
              );
            }

            return WalletTransferScreen(token: token);
          },

          // ------------------------------------------------------
          // WALLET OVERVIEW
          // ------------------------------------------------------
          '/wallet': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Wallet',
              );
            }

            return WalletOverviewScreen(token: token);
          },

          // ------------------------------------------------------
          // PAYMENT HISTORY
          // ------------------------------------------------------
          '/payment-history': (context) => PaymentHistoryScreen(),

          // ------------------------------------------------------
          // SCHEDULED PAYMENT
          // ------------------------------------------------------
          '/scheduled-payment': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Scheduled Payment',
              );
            }

            return ScheduledPaymentScreen(token: token);
          },

          // ------------------------------------------------------
          // PDF STATEMENT
          // ------------------------------------------------------
          '/pdf-statement': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'PDF Statement',
              );
            }
            return PdfStatementScreen(activeToken: token);
          },
          // ------------------------------------------------------
          // NANA WALLET ASSISTANT
          // ------------------------------------------------------
          '/chatbot': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'NaNa Assistant',
              );
            }

            return ChatbotScreen(token: token);
          },
          // ------------------------------------------------------
          // NANA QUICK LOAN
          // ------------------------------------------------------
          '/quick-loan': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'NaNa Quick Loan',
              );
            }

            return QuickLoanScreen(token: token);
          },

          '/quick-loan/apply': (context) {
            final token = _getToken(context);

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Apply for a Loan',
              );
            }

            return ApplyLoanScreen(token: token);
          },

          '/quick-loan/details': (context) {
            final token = _getToken(context);
            final arguments = ModalRoute.of(context)?.settings.arguments;

            final loanId = arguments is Map
                ? int.tryParse(arguments['loanId']?.toString() ?? '')
                : null;

            if (token == null) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Loan Details',
              );
            }

            return LoanDetailsScreen(token: token, loanId: loanId);
          },
          // ------------------------------------------------------
          // PAYMENT CONFIRMATION
          // ------------------------------------------------------
          '/payment-confirmation': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;

            if (arguments is! Map<String, dynamic>) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Payment Confirmation',
              );
            }

            final token = arguments['token'];
            final paymentType = arguments['paymentType'];
            final recipient = arguments['recipient'];
            final amount = arguments['amount'];
            final currency = arguments['currency'];
            final description = arguments['description'];
            final onConfirm = arguments['onConfirm'];

            if (token is! String ||
                token.trim().isEmpty ||
                paymentType is! String ||
                recipient is! String ||
                amount is! num ||
                currency is! String ||
                description is! String ||
                onConfirm is! Future<Map<String, dynamic>> Function()) {
              return _missingTokenScreen(
                context: context,
                screenName: 'Payment Confirmation',
              );
            }

            return PaymentConfirmationScreen(
              token: token,
              paymentType: paymentType,
              recipient: recipient,
              amount: amount.toDouble(),
              currency: currency,
              description: description,
              onConfirm: onConfirm,
            );
          },
        },
      ),
    );
  }

  // ============================================================
  // APP THEME
  // ============================================================

  ThemeData _buildTheme({required bool dark}) {
    final scheme = dark
        ? const ColorScheme.dark(
            primary: AppColors.brandMint,
            secondary: AppColors.accentLime,
            surface: AppColors.surface,
            error: Color(0xFFFF6B6B),
          )
        : const ColorScheme.light(
            primary: Color(0xFF087F68),
            secondary: Color(0xFF79A91A),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFB42318),
          );

    final background = dark ? AppColors.midnightBlue : const Color(0xFFF4F7F6);

    final surface = dark ? AppColors.surface : const Color(0xFFFFFFFF);

    final border = dark ? AppColors.glassBorder : const Color(0xFFE1E8E5);

    return ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: dark ? AppColors.textPrimary : const Color(0xFF17231F),
        elevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      useMaterial3: true,
    );
  }
}

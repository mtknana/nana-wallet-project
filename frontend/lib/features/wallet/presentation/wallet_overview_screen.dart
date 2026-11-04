import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class WalletOverviewScreen extends StatefulWidget {
  const WalletOverviewScreen({super.key, required this.token});

  final String token;

  @override
  State<WalletOverviewScreen> createState() => _WalletOverviewScreenState();
}

class _WalletOverviewScreenState extends State<WalletOverviewScreen> {
  List<WalletModel> _wallets = [];
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _selectedCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final wallets = await WalletService.fetchWalletBalances(widget.token);
      final transactions = await WalletService.fetchHistory(widget.token);
      if (!mounted) return;
      setState(() {
        _wallets = wallets;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Wallet overview load failed: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  WalletModel? _walletFor(String currency) {
    for (final wallet in _wallets) {
      if (wallet.currency.toUpperCase() == currency) return wallet;
    }
    return null;
  }

  List<TransactionModel> get _visibleTransactions => _transactions
      .where((transaction) =>
          transaction.currency.toUpperCase() == _selectedCurrency)
      .toList();

  void _selectCurrency(String currency) {
    setState(() => _selectedCurrency = currency);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Wallet',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh wallets',
            onPressed: _isLoading ? null : _loadWalletData,
            icon: Icon(LucideIcons.refreshCw, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.surface,
        onRefresh: _loadWalletData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
          children: [
            Text(
              'Your balances',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Choose a wallet to see its payment history.',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.62),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final usdCard = _buildWalletCard('USD', colors);
                final khrCard = _buildWalletCard('KHR', colors);
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [
                      usdCard,
                      const SizedBox(height: 12),
                      khrCard,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: usdCard),
                    const SizedBox(width: 14),
                    Expanded(child: khrCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment history',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_visibleTransactions.length} ${_visibleTransactions.length == 1 ? 'payment' : 'payments'}',
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCurrencySelector(colors),
            const SizedBox(height: 14),
            if (_isLoading && _transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(color: colors.primary),
                ),
              )
            else
              _buildTransactionList(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(String currency, ColorScheme colors) {
    final wallet = _walletFor(currency);
    final selected = _selectedCurrency == currency;
    final accent = currency == 'USD' ? colors.primary : const Color(0xFF4B91E2);
    final amount = wallet == null
        ? (_isLoading ? 'Loading…' : 'Wallet unavailable')
        : _formatMoney(wallet.balance, currency, includeSign: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectCurrency(currency),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: selected ? 0.18 : 0.11),
                colors.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.55 : 0.20),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.wallet,
                      color: accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$currency Wallet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(LucideIcons.circleCheck, color: accent, size: 18),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'AVAILABLE BALANCE',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.55),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencySelector(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          _currencyChoice('USD', colors),
          _currencyChoice('KHR', colors),
        ],
      ),
    );
  }

  Widget _currencyChoice(String currency, ColorScheme colors) {
    final selected = _selectedCurrency == currency;
    return Expanded(
      child: InkWell(
        onTap: () => _selectCurrency(currency),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            '$currency History',
            style: TextStyle(
              color: selected ? colors.primary : colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList(ColorScheme colors) {
    final transactions = _visibleTransactions;
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Icon(
              LucideIcons.receiptText,
              color: colors.onSurface.withValues(alpha: 0.30),
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              _isLoading
                  ? 'Loading ${_selectedCurrency} payments…'
                  : 'No ${_selectedCurrency} payments yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.70),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Payments in the selected wallet will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.48),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < transactions.length; index++) ...[
            _transactionTile(transactions[index], colors),
            if (index < transactions.length - 1)
              Divider(
                height: 1,
                indent: 62,
                color: colors.onSurface.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }

  Widget _transactionTile(TransactionModel transaction, ColorScheme colors) {
    final outgoing = _isOutgoing(transaction.type);
    final amountColor = outgoing ? Colors.redAccent : Colors.green;
    final title = transaction.description.trim().isNotEmpty
        ? transaction.description.trim()
        : _typeLabel(transaction.type);
    final date = _formatDate(transaction.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_transactionIcon(transaction.type), color: colors.primary, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$date · ${transaction.status}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.53),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _formatMoney(transaction.amount, _selectedCurrency, includeSign: true, outgoing: outgoing),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: amountColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(
    double amount,
    String currency, {
    required bool includeSign,
    bool outgoing = false,
  }) {
    final digits = currency == 'KHR' ? 0 : 2;
    final raw = amount.abs().toStringAsFixed(digits);
    final parts = raw.split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final formatted = digits == 0 ? integer : '$integer.${parts.last}';
    final symbol = currency == 'KHR' ? '៛' : '\$';
    final sign = !includeSign ? '' : (outgoing ? '−' : '+');
    return '$sign$symbol$formatted';
  }

  bool _isOutgoing(String type) {
    return const {
      'withdrawal',
      'withdraw',
      'bill_payment',
      'bill',
      'mobile_topup',
      'mobile_top_up',
      'top_up',
      'top-up',
      'transfer_out',
      'payment',
      'qr_payment',
    }.contains(type.toLowerCase());
  }

  String _typeLabel(String type) {
    return type
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  IconData _transactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'withdrawal':
      case 'withdraw':
      case 'transfer_out':
        return LucideIcons.arrowUpRight;
      case 'transfer_in':
      case 'deposit':
        return LucideIcons.arrowDownLeft;
      case 'bill_payment':
      case 'bill':
      case 'qr_payment':
      case 'payment':
        return LucideIcons.receiptText;
      case 'mobile_topup':
      case 'mobile_top_up':
      case 'top_up':
      case 'top-up':
        return LucideIcons.smartphone;
      default:
        return LucideIcons.arrowLeftRight;
    }
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw.isEmpty ? 'Date unavailable' : raw;
    final local = date.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} ${months[local.month - 1]} ${local.year} · $hour:$minute $period';
  }
}

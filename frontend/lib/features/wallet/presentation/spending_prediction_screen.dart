import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class SpendingPredictionScreen extends StatefulWidget {
  final String? token;

  const SpendingPredictionScreen({super.key, this.token});

  @override
  State<SpendingPredictionScreen> createState() =>
      _SpendingPredictionScreenState();
}

class _SpendingPredictionScreenState extends State<SpendingPredictionScreen> {
  String? _activeToken;
  String _currency = 'USD';
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _prediction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.token != null && widget.token!.isNotEmpty) {
      _activeToken = widget.token;
    } else {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is String && args.isNotEmpty) {
        _activeToken = args;
      } else if (args is Map) {
        final possibleToken = args['token'];
        if (possibleToken is String && possibleToken.isNotEmpty) {
          _activeToken = possibleToken;
        }
      }
    }

    if (_prediction == null && _isLoading) {
      _loadPrediction();
    }
  }

  Future<void> _loadPrediction() async {
    if (_activeToken == null || _activeToken!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Authentication token is missing. Please sign in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await WalletService.fetchSpendingPrediction(
        token: _activeToken!,
        currency: _currency,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        final rawData = response['data'];

        if (rawData is Map) {
          setState(() {
            _prediction = Map<String, dynamic>.from(rawData);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'The server returned an unexpected response.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ??
              'Unable to load spending prediction.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to load prediction. Please try again.';
        _isLoading = false;
      });
    }
  }

  double _number(String key) {
    final value = _prediction?[key];

    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(num value) {
    if (_currency == 'KHR') {
      return '៛${value.round()}';
    }

    return '\$${value.toStringAsFixed(2)}';
  }

  String _prettyCategory(String category) {
    if (category.isEmpty) return 'Other';

    return '${category[0].toUpperCase()}${category.substring(1)}';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return LucideIcons.utensils;
      case 'transport':
        return LucideIcons.car;
      case 'study':
        return LucideIcons.bookOpen;
      default:
        return LucideIcons.shoppingBag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context);
    final textColor = colors.colorScheme.onSurface;
    final secondaryColor = textColor.withValues(alpha: 0.65);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Spending Prediction',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh prediction',
            onPressed: _isLoading ? null : _loadPrediction,
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildError()
            : _buildContent(secondaryColor),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.chartNoAxesCombined, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPrediction,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Color secondaryColor) {
    final predicted = _number('predicted_monthly_total');
    final spent = _number('spent_so_far');
    final dailyAverage = _number('average_daily_spending');
    final remaining = _prediction?['days_remaining'] ?? 0;
    final period = _prediction?['period'] is Map
        ? Map<String, dynamic>.from(_prediction!['period'] as Map)
        : <String, dynamic>{};

    final rawCategories = _prediction?['by_category'];
    final categories = rawCategories is Map
        ? Map<String, dynamic>.from(rawCategories)
        : <String, dynamic>{};

    final progress = predicted > 0
        ? (spent / predicted).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return RefreshIndicator(
      onRefresh: _loadPrediction,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.brandMint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.brainCircuit, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Your spending outlook',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Predicted month-end spending',
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(predicted),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on your recorded $_currency expenses',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Spent so far',
                  value: _money(spent),
                  icon: LucideIcons.wallet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  title: 'Daily average',
                  value: _money(dailyAverage),
                  icon: LucideIcons.calendarDays,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _sectionTitle('Prediction details'),
          const SizedBox(height: 12),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly spending progress'),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: AppColors.textSecondary.withValues(
                      alpha: 0.15,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brandMint,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow('Days remaining', '$remaining'),
                _detailRow(
                  'Period starts',
                  period['start_date']?.toString() ?? '—',
                ),
                _detailRow(
                  'Period ends',
                  period['end_date']?.toString() ?? '—',
                ),
                _detailRow(
                  'Prediction method',
                  _prediction?['prediction_method']?.toString() ??
                      'Daily average',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Spending by category'),
          const SizedBox(height: 12),
          _panel(
            child: categories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No expenses recorded this month yet.'),
                    ),
                  )
                : Column(
                    children: categories.entries.map((entry) {
                      final amount = entry.value is num
                          ? (entry.value as num).toDouble()
                          : double.tryParse(entry.value.toString()) ?? 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.brandMint.withValues(
                                  alpha: 0.25,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_categoryIcon(entry.key), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _prettyCategory(entry.key),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              _money(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Currency'),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'USD', label: Text('USD \$')),
              ButtonSegment(value: 'KHR', label: Text('KHR ៛')),
            ],
            selected: {_currency},
            onSelectionChanged: (selection) {
              setState(() {
                _currency = selection.first;
                _prediction = null;
              });
              _loadPrediction();
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _prediction?['disclaimer']?.toString() ??
                        'This is an estimate based on recorded expenses, not a guarantee of future spending.',
                    style: TextStyle(color: secondaryColor, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: child,
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

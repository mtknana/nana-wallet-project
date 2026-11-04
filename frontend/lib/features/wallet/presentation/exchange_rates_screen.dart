import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class ExchangeRatesScreen extends StatefulWidget {
  final String? token;

  const ExchangeRatesScreen({super.key, this.token});

  @override
  State<ExchangeRatesScreen> createState() => _ExchangeRatesScreenState();
}

class _ExchangeRatesScreenState extends State<ExchangeRatesScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: '1',
  );
  final TextEditingController _searchController = TextEditingController();

  String? _activeToken;
  String _fromCurrency = 'USD';
  String _toCurrency = 'KHR';
  String _searchQuery = '';

  List<Map<String, dynamic>> _currencies = [];

  bool _isLoading = true;
  bool _isConverting = false;
  bool _hasLoadedCurrencies = false;

  String? _errorMessage;
  String? _conversionError;
  String? _lastUpdated;

  double? _convertedAmount;
  double? _exchangeRate;

  Color get _mint => AppColors.brandMint;
  Color get _lime => AppColors.accentLime;

  Color get _textColor => Theme.of(context).brightness == Brightness.dark
      ? AppColors.textPrimary
      : const Color(0xFF17231F);

  Color get _mutedColor => Theme.of(context).brightness == Brightness.dark
      ? AppColors.textSecondary
      : const Color(0xFF687873);

  Color get _surfaceColor => Theme.of(context).brightness == Brightness.dark
      ? AppColors.surface
      : Colors.white;

  Color get _backgroundColor => Theme.of(context).brightness == Brightness.dark
      ? AppColors.midnightBlue
      : const Color(0xFFF4F8F6);

  Color get _borderColor => Theme.of(context).brightness == Brightness.dark
      ? AppColors.glassBorder
      : const Color(0xFFE1EAE5);

  @override
  void initState() {
    super.initState();
    _activeToken = widget.token;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_activeToken == null || _activeToken!.trim().isEmpty) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is String) {
        _activeToken = arguments;
      } else if (arguments is Map) {
        _activeToken =
            arguments['token']?.toString() ??
            arguments['activeToken']?.toString();
      }
    }

    if (_activeToken != null &&
        _activeToken!.trim().isNotEmpty &&
        !_hasLoadedCurrencies &&
        _isLoading) {
      _hasLoadedCurrencies = true;
      _loadCurrencies();
    } else if (_activeToken == null || _activeToken!.trim().isEmpty) {
      _isLoading = false;
      _errorMessage =
          'Your login token was not provided. Please reopen this screen after logging in.';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _number(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic>? _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<Map<String, dynamic>> _extractCurrencies(Map<String, dynamic> response) {
    dynamic data = response['currencies'];

    data ??= response['data'];

    if (data is Map) {
      data = data['currencies'] ?? data['data'];
    }

    if (data is! List) return [];

    final currencies = data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
          final code = item['code']?.toString().trim() ?? '';
          return code.isNotEmpty;
        })
        .toList();

    currencies.sort((a, b) {
      final aDefault =
          a['is_default'] == true || a['is_default']?.toString() == '1';
      final bDefault =
          b['is_default'] == true || b['is_default']?.toString() == '1';

      if (aDefault != bDefault) {
        return aDefault ? -1 : 1;
      }

      return (a['code']?.toString() ?? '').compareTo(
        b['code']?.toString() ?? '',
      );
    });

    return currencies;
  }

  Future<void> _loadCurrencies() async {
    if (_activeToken == null || _activeToken!.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in again to load exchange rates.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _conversionError = null;
    });

    try {
      final response = await WalletService.fetchCurrencies(
        token: _activeToken!,
      );

      if (!mounted) return;

      if (response['status'] != 'success') {
        setState(() {
          _isLoading = false;
          _errorMessage =
              response['message']?.toString() ?? 'Unable to load currencies.';
        });
        return;
      }

      final currencies = _extractCurrencies(response);

      if (currencies.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No currencies were returned by the server.';
        });
        return;
      }

      final codes = currencies
          .map((item) => item['code'].toString().toUpperCase())
          .toSet();

      String chooseCurrency(String preferred, String fallback) {
        if (codes.contains(preferred)) return preferred;
        if (codes.contains(fallback)) return fallback;
        return currencies.first['code'].toString().toUpperCase();
      }

      String latestDate = '';

      for (final currency in currencies) {
        final updated = currency['updated_at']?.toString() ?? '';

        if (updated.isNotEmpty && updated.compareTo(latestDate) > 0) {
          latestDate = updated;
        }
      }

      setState(() {
        _currencies = currencies;

        _fromCurrency = codes.contains(_fromCurrency)
            ? _fromCurrency
            : chooseCurrency('USD', 'KHR');

        _toCurrency = codes.contains(_toCurrency)
            ? _toCurrency
            : chooseCurrency('KHR', 'USD');

        if (_fromCurrency == _toCurrency && currencies.length > 1) {
          _toCurrency = currencies
              .firstWhere(
                (item) =>
                    item['code'].toString().toUpperCase() != _fromCurrency,
              )['code']
              .toString()
              .toUpperCase();
        }

        _lastUpdated = latestDate.isEmpty ? null : latestDate;
        _isLoading = false;
        _errorMessage = null;
      });

      await _convert();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to connect to the server: $e';
      });
    }
  }

  Future<void> _convert() async {
    if (_activeToken == null || _currencies.isEmpty) return;

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount < 0) {
      setState(() {
        _convertedAmount = null;
        _exchangeRate = null;
        _conversionError = 'Enter a valid amount.';
        _isConverting = false;
      });
      return;
    }

    if (_fromCurrency == _toCurrency) {
      setState(() {
        _convertedAmount = amount;
        _exchangeRate = 1;
        _conversionError = null;
        _isConverting = false;
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _conversionError = null;
    });

    try {
      final response = await WalletService.convertCurrency(
        token: _activeToken!,
        amount: amount,
        fromCurrency: _fromCurrency,
        toCurrency: _toCurrency,
      );

      if (!mounted) return;

      if (response['status'] != 'success') {
        setState(() {
          _isConverting = false;
          _convertedAmount = null;
          _exchangeRate = null;
          _conversionError =
              response['message']?.toString() ??
              'Conversion failed. Please try again.';
        });
        return;
      }

      final data = _map(response['data']) ?? response;

      final converted =
          data['converted_amount'] ??
          data['convertedAmount'] ??
          data['converted'] ??
          data['result'];

      final rate =
          data['exchange_rate'] ?? data['exchangeRate'] ?? data['rate'];

      setState(() {
        _convertedAmount = converted == null ? null : _number(converted);
        _exchangeRate = rate == null ? null : _number(rate);
        _isConverting = false;

        if (_convertedAmount == null) {
          _conversionError =
              'The server did not return a converted amount. Check the API response format.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isConverting = false;
        _convertedAmount = null;
        _exchangeRate = null;
        _conversionError = 'Conversion failed: $e';
      });
    }
  }

  void _swapCurrencies() {
    if (_fromCurrency == _toCurrency) return;

    setState(() {
      final previousFrom = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = previousFrom;
    });

    _convert();
  }

  void _changeCurrency({required bool isFrom, required String value}) {
    setState(() {
      if (isFrom) {
        _fromCurrency = value;
      } else {
        _toCurrency = value;
      }

      if (_fromCurrency == _toCurrency && _currencies.length > 1) {
        final other = _currencies
            .firstWhere(
              (item) => item['code'].toString().toUpperCase() != value,
            )['code']
            .toString()
            .toUpperCase();

        if (isFrom) {
          _toCurrency = other;
        } else {
          _fromCurrency = other;
        }
      }

      _convertedAmount = null;
      _exchangeRate = null;
    });

    _convert();
  }

  String _flag(String code) {
    const flags = <String, String>{
      'USD': '🇺🇸',
      'KHR': '🇰🇭',
      'EUR': '🇪🇺',
      'GBP': '🇬🇧',
      'JPY': '🇯🇵',
      'CNY': '🇨🇳',
      'THB': '🇹🇭',
      'VND': '🇻🇳',
      'LAK': '🇱🇦',
      'SGD': '🇸🇬',
      'MYR': '🇲🇾',
      'IDR': '🇮🇩',
      'PHP': '🇵🇭',
      'INR': '🇮🇳',
      'KRW': '🇰🇷',
      'AUD': '🇦🇺',
      'NZD': '🇳🇿',
      'CAD': '🇨🇦',
      'CHF': '🇨🇭',
      'HKD': '🇭🇰',
      'TWD': '🇹🇼',
      'MMK': '🇲🇲',
      'BDT': '🇧🇩',
      'PKR': '🇵🇰',
      'AED': '🇦🇪',
      'SAR': '🇸🇦',
      'ZAR': '🇿🇦',
      'BRL': '🇧🇷',
      'MXN': '🇲🇽',
      'TRY': '🇹🇷',
      'RUB': '🇷🇺',
      'NOK': '🇳🇴',
      'SEK': '🇸🇪',
      'DKK': '🇩🇰',
      'PLN': '🇵🇱',
      'CZK': '🇨🇿',
      'XOF': '🌍',
      'XAF': '🌍',
      'XCD': '🌎',
      'XDR': '🌐',
    };

    return flags[code.toUpperCase()] ?? '🌐';
  }

  String _symbol(Map<String, dynamic>? currency) {
    if (currency == null) return '';

    final symbol = currency['symbol']?.toString() ?? '';
    if (symbol.isNotEmpty) return symbol;

    final code = currency['code']?.toString().toUpperCase() ?? '';

    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
      case 'CNY':
        return '¥';
      case 'KHR':
        return '៛';
      case 'THB':
        return '฿';
      case 'INR':
        return '₹';
      default:
        return '$code ';
    }
  }

  Map<String, dynamic>? _currencyByCode(String code) {
    for (final currency in _currencies) {
      if (currency['code']?.toString().toUpperCase() == code) {
        return currency;
      }
    }
    return null;
  }

  int _decimalPlaces(String code) {
    final currency = _currencyByCode(code);
    final places = int.tryParse(currency?['decimal_places']?.toString() ?? '');

    if (places != null && places >= 0 && places <= 8) {
      return places;
    }

    return code == 'KHR' || code == 'JPY' ? 0 : 2;
  }

  String _formatAmount(double amount, String code) {
    return amount.toStringAsFixed(_decimalPlaces(code));
  }

  String _formattedDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'Not provided by server';
    }

    final date = DateTime.tryParse(raw);
    if (date == null) return raw;

    final local = date.toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _sectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, {String? subtitle, Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: _mutedColor, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _currencyDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
    required String label,
  }) {
    final codes = _currencies
        .map((item) => item['code'].toString().toUpperCase())
        .toSet();

    final safeValue = codes.contains(value)
        ? value
        : (_currencies.isNotEmpty
              ? _currencies.first['code'].toString().toUpperCase()
              : null);

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _mutedColor),
        filled: true,
        fillColor: _backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _mint, width: 1.5),
        ),
      ),
      dropdownColor: _surfaceColor,
      style: TextStyle(color: _textColor, fontWeight: FontWeight.w700),
      items: _currencies.map((currency) {
        final code = currency['code'].toString().toUpperCase();
        final name = currency['name']?.toString() ?? code;

        return DropdownMenuItem<String>(
          value: code,
          child: Text(
            '${_flag(code)}  $code · $name',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConverter() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Currency converter',
            subtitle: 'Calculate using the rates stored by your server.',
          ),
          const SizedBox(height: 20),
          Text(
            'Amount',
            style: TextStyle(
              color: _mutedColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}')),
            ],
            style: TextStyle(
              color: _textColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: 'Enter amount',
              prefixIcon: Icon(Icons.payments_outlined, color: _mint),
              filled: true,
              fillColor: _backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _mint, width: 1.5),
              ),
            ),
            onSubmitted: (_) => _convert(),
          ),
          const SizedBox(height: 16),
          _currencyDropdown(
            value: _fromCurrency,
            label: 'From',
            onChanged: (value) {
              if (value != null) {
                _changeCurrency(isFrom: true, value: value);
              }
            },
          ),
          const SizedBox(height: 10),
          Center(
            child: IconButton.filledTonal(
              tooltip: 'Swap currencies',
              onPressed: _swapCurrencies,
              icon: const Icon(Icons.swap_vert_rounded),
              style: IconButton.styleFrom(
                foregroundColor: _mint,
                backgroundColor: _mint.withValues(alpha: 0.12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _currencyDropdown(
            value: _toCurrency,
            label: 'To',
            onChanged: (value) {
              if (value != null) {
                _changeCurrency(isFrom: false, value: value);
              }
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isConverting ? null : _convert,
              icon: _isConverting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.currency_exchange_rounded),
              label: Text(_isConverting ? 'Converting...' : 'Convert'),
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                foregroundColor: const Color(0xFF06221B),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_convertedAmount != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _mint.withValues(alpha: 0.18),
                    _lime.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _mint.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Converted amount',
                    style: TextStyle(color: _mutedColor, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_flag(_toCurrency)}  '
                    '${_symbol(_currencyByCode(_toCurrency))}'
                    '${_formatAmount(_convertedAmount!, _toCurrency)}',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_exchangeRate != null) ...[
                    const SizedBox(height: 12),
                    Divider(color: _borderColor),
                    const SizedBox(height: 6),
                    Text(
                      '1 $_fromCurrency = '
                      '${_formatAmount(_exchangeRate!, _toCurrency)} '
                      '$_toCurrency',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Reference conversion only. Actual wallet transactions '
                    'may use configured transaction rates and fees.',
                    style: TextStyle(color: _mutedColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
          if (_conversionError != null) ...[
            const SizedBox(height: 12),
            _errorBanner(_conversionError!),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyList() {
    final filtered = _currencies.where((currency) {
      final code = currency['code']?.toString().toLowerCase() ?? '';
      final name = currency['name']?.toString().toLowerCase() ?? '';

      return code.contains(_searchQuery) || name.contains(_searchQuery);
    }).toList();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Available currencies',
            subtitle:
                '${_currencies.length} currencies returned by your server',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'Search code or currency name',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
              filled: true,
              fillColor: _backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'No matching currencies found.',
                  style: TextStyle(color: _mutedColor),
                ),
              ),
            )
          else
            ...filtered.map((currency) {
              final code = currency['code'].toString().toUpperCase();
              final name = currency['name']?.toString() ?? code;
              final rate = _number(currency['exchange_rate']);
              final isDefault =
                  currency['is_default'] == true ||
                  currency['is_default']?.toString() == '1';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _mint.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        _flag(code),
                        style: const TextStyle(fontSize: 23),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  code,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _mint.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      color: _mint,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _mutedColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rate > 0
                              ? '${_symbol(currency)}${rate.toStringAsFixed(4)}'
                              : 'Unavailable',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'per 1 ${_currencies.first['code']}',
                          style: TextStyle(color: _mutedColor, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRateInfo() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Rate information'),
          const SizedBox(height: 16),
          _infoRow(
            Icons.schedule_rounded,
            'Last currency record update',
            _formattedDate(_lastUpdated),
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.cloud_sync_outlined,
            'Rate source',
            'Backend currency database',
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.info_outline_rounded,
            'Rate type',
            'Reference rate; not a guaranteed transaction quote',
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.account_balance_wallet_outlined,
            'Wallet currencies',
            'USD and KHR',
          ),
          const SizedBox(height: 14),
          Text(
            'The timestamp comes from currency records returned by the '
            'server. It may not represent the exact provider update time.',
            style: TextStyle(color: _mutedColor, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _mint, size: 20),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: Text(
            title,
            style: TextStyle(color: _mutedColor, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.currency_exchange_rounded, size: 54, color: _mint),
            const SizedBox(height: 16),
            Text(
              'Unable to load exchange rates',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedColor),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadCurrencies,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                foregroundColor: const Color(0xFF06221B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF54D6AE), Color(0xFF239F84), Color(0xFF18745F)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.currency_exchange_rounded,
                color: Colors.white,
                size: 25,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Global currency reference',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'REFERENCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            'Compare currencies and estimate conversions using the rates '
            'stored in NaNa Wallet.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              height: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.public_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                '${_currencies.length} currencies available',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        elevation: 0,
        title: const Text(
          'Exchange Rates',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload currencies',
            onPressed: _isLoading ? null : _loadCurrencies,
            icon: _isLoading
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _mint),
                  const SizedBox(height: 14),
                  Text(
                    'Loading exchange rates...',
                    style: TextStyle(color: _mutedColor),
                  ),
                ],
              ),
            )
          : _currencies.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadCurrencies,
              color: _mint,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 18),
                  _buildConverter(),
                  const SizedBox(height: 18),
                  _buildCurrencyList(),
                  const SizedBox(height: 18),
                  _buildRateInfo(),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _mint.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _mint.withValues(alpha: 0.24)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: _mint, size: 21),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your wallet balances and transfers remain '
                            'USD/KHR. These reference conversions do not '
                            'perform a wallet transaction.',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

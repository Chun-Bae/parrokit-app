import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  bool _isParrotsToCrackers = true; // true: 패롯 -> 크래커, false: 크래커 -> 패롯
  final TextEditingController _amountController = TextEditingController();
  bool _isExchanging = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onExchange() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showToast('올바른 수량을 입력해 주세요.');
      return;
    }

    final provider = context.read<UserProvider>();
    final currentUser = provider.currentUser;
    if (currentUser == null) return;

    if (_isParrotsToCrackers && currentUser.parrots < amount) {
      showToast('보유하신 패롯이 부족합니다.');
      return;
    }

    if (!_isParrotsToCrackers && currentUser.crackers < amount) {
      showToast('보유하신 크래커가 부족합니다.');
      return;
    }

    setState(() => _isExchanging = true);

    try {
      final deduct = amount;
      final add =
          _isParrotsToCrackers ? amount * 1000 : (amount / 1000).floor();

      if (!_isParrotsToCrackers && amount % 1000 != 0) {
        showToast('크래커에서 패롯으로의 환전은 1000 단위로만 가능합니다.');
        setState(() => _isExchanging = false);
        return;
      }

      await provider.exchangeCurrency(
        amountToDeduct: deduct,
        amountToAdd: add,
        isParrotsToCrackers: _isParrotsToCrackers,
      );

      if (!mounted) return;
      _amountController.clear();
      showToast('환전이 완료되었습니다!');
      Navigator.pop(context);
    } catch (e) {
      showToast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isExchanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final int inputAmount = int.tryParse(_amountController.text) ?? 0;
    final int expectedAmount = _isParrotsToCrackers
        ? inputAmount * 1000
        : (inputAmount / 1000).floor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('환전소', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 내 잔액 표시 카드
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBalanceItem(
                        '패롯', user.parrots, AppColors.parrotCurrency),
                    Icon(Icons.compare_arrows_rounded,
                        color: context.tokens.textTertiary),
                    _buildBalanceItem(
                        '크래커', user.crackers, AppColors.crackerCurrency),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 환전 방향 고르기
              AppSegmentedTabs(
                selectedIndex: _isParrotsToCrackers ? 0 : 1,
                onChanged: (index) {
                  setState(() {
                    _isParrotsToCrackers = index == 0;
                    _amountController.clear();
                  });
                },
                segments: const [
                  AppSegment(label: '패롯 → 크래커'),
                  AppSegment(label: '크래커 → 패롯'),
                ],
              ),
              const SizedBox(height: 32),

              // 입력 폼
              Text(
                _isParrotsToCrackers ? '교환할 패롯 수량' : '교환할 크래커 수량 (1000단위)',
                style: context.texts.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '수량을 입력하세요',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: context.tokens.borderStrong),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: context.tokens.borderStrong),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 자주 쓰는 수량을 눌러 바로 채운다. 전에는 숫자를 직접 쳐야 했고,
              // 크래커는 1000 단위라 틀리기 쉬웠다.
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, value) in _quickAmounts(
                      _isParrotsToCrackers ? user.parrots : user.crackers))
                    ActionChip(
                      label: Text(label),
                      onPressed: value <= 0
                          ? null
                          : () => setState(() {
                                _amountController.text = '$value';
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 예상 결과
              if (inputAmount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.tokens.info.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: context.tokens.info),
                      const SizedBox(width: 8),
                      Text(
                        '받을 양: ${NumberFormat.decimalPattern('ko').format(expectedAmount)} ${_isParrotsToCrackers ? '크래커' : '패롯'}',
                        style: TextStyle(
                            color: context.tokens.info,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // 환전 버튼
              ElevatedButton(
                onPressed:
                    _isExchanging || inputAmount <= 0 ? null : _onExchange,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: _isExchanging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        '환전하기',
                        // 테마 글자색이 버튼의 흰 글자를 덮어 파란 바탕에 검은 글자가 됐다
                        style: context.texts.titleMedium.copyWith(
                          color: inputAmount > 0
                              ? theme.colorScheme.onPrimary
                              : null,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 빠른 수량 칩. 패롯은 1·5·10·전부, 크래커는 1,000 단위로 1,000·5,000·
  /// 10,000·전부(1,000 단위로 내림). 가진 것보다 많으면 누를 수 없다.
  List<(String, int)> _quickAmounts(int balance) {
    final format = NumberFormat.decimalPattern('ko');
    final steps =
        _isParrotsToCrackers ? const [1, 5, 10] : const [1000, 5000, 10000];
    final all = _isParrotsToCrackers ? balance : (balance ~/ 1000) * 1000;
    return [
      for (final step in steps)
        (format.format(step), step <= balance ? step : 0),
      ('전부', all),
    ];
  }

  Widget _buildBalanceItem(String title, int amount, Color color) {
    return Column(
      children: [
        Text(title,
            style: context.texts.labelMedium
                .copyWith(color: context.tokens.textTertiary)),
        const SizedBox(height: 4),
        Text(
          NumberFormat.decimalPattern('ko').format(amount),
          style: context.texts.headlineSmall.copyWith(color: color),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/currency_icon.dart';
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
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/user_error_message.dart';

/// 패롯 1개 = 크래커 1,000개. 양쪽 환전 모두 같은 비율이다.
const exchangeRate = 1000;

/// 입력한 수량으로 환전할 수 없는 이유. 없으면 null.
///
/// 예전에는 보유량보다 많이 넣거나 크래커를 1,000 단위가 아니게 넣어도
/// '환전하기'가 눌렸고, 누른 뒤에야 토스트로 알렸다(5차). 넣는 동안 보여준다.
String? exchangeInputProblem({
  required bool parrotsToCrackers,
  required int amount,
  required int balance,
}) {
  if (amount <= 0) return null;
  final format = NumberFormat.decimalPattern('ko');
  final name = parrotsToCrackers ? '패롯' : '크래커';
  if (amount > balance) {
    return '가진 $name보다 많아요 (보유 ${format.format(balance)})';
  }
  if (!parrotsToCrackers && amount % exchangeRate != 0) {
    return '크래커는 ${format.format(exchangeRate)}개 단위로 바꿀 수 있어요';
  }
  return null;
}

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
    } catch (e, st) {
      AppLogger.e('환전 실패', error: e, stackTrace: st);
      showToast(userErrorMessage(e, fallback: '환전하지 못했어요. 다시 시도해 주세요.'));
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
        ? inputAmount * exchangeRate
        : (inputAmount / exchangeRate).floor();
    final problem = exchangeInputProblem(
      parrotsToCrackers: _isParrotsToCrackers,
      amount: inputAmount,
      balance: _isParrotsToCrackers ? user.parrots : user.crackers,
    );
    final canExchange = inputAmount > 0 && problem == null;

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
              const SizedBox(height: 10),
              // 비율을 숫자를 넣기 전에도 보여준다(예전엔 넣어야 받을 양이 보였다).
              // 고른 방향대로 읽히게 좌우를 바꾼다. 예전엔 어느 쪽을 골라도
              // '패롯 1 = 크래커 1,000'이라 거꾸로 읽혔다(5차).
              Builder(builder: (context) {
                final rateStyle = context.texts.labelLarge
                    .copyWith(color: context.tokens.textSecondary);
                final amount =
                    NumberFormat.decimalPattern('ko').format(exchangeRate);
                return Row(
                  key: const ValueKey('exchange-rate'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _isParrotsToCrackers
                      ? [
                          const CurrencyIcon(Currency.parrot, size: 16),
                          Text(' 1 = ', style: rateStyle),
                          const CurrencyIcon(Currency.cracker, size: 16),
                          Text(' $amount', style: rateStyle),
                        ]
                      : [
                          const CurrencyIcon(Currency.cracker, size: 16),
                          Text(' $amount = ', style: rateStyle),
                          const CurrencyIcon(Currency.parrot, size: 16),
                          Text(' 1', style: rateStyle),
                        ],
                );
              }),
              const SizedBox(height: 24),

              // 입력 폼
              Text(
                // 화면 제목('환전소')·버튼('환전하기')과 같은 말을 쓴다.
                // 여기만 '교환할'이었다(5차).
                _isParrotsToCrackers
                    ? '환전할 패롯 수량'
                    // 아래 안내와 같은 말로('1,000개 단위').
                    : '환전할 크래커 수량 '
                        '(${NumberFormat.decimalPattern('ko').format(exchangeRate)}개 단위)',
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

              // 예상 결과. 아직 아무것도 안 넣었으면 왜 버튼이 꺼져 있는지
              // 알 수 있게 한 줄 띄운다(5차, 새 클립 화면과 같게).
              if (inputAmount <= 0)
                Text(
                  '바꿀 수량을 적어 주세요.',
                  key: const ValueKey('exchange-hint'),
                  style: context.texts.bodySmall
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: (problem == null
                            ? context.tokens.info
                            : theme.colorScheme.error)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          problem == null
                              ? Icons.info_outline
                              : Icons.error_outline_rounded,
                          size: 18,
                          color: problem == null
                              ? context.tokens.info
                              : theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          problem ??
                              '받을 양: ${NumberFormat.decimalPattern('ko').format(expectedAmount)} ${_isParrotsToCrackers ? '크래커' : '패롯'}',
                          key: const ValueKey('exchange-preview'),
                          style: TextStyle(
                              color: problem == null
                                  ? context.tokens.info
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // 환전 버튼
              ElevatedButton(
                onPressed: _isExchanging || !canExchange ? null : _onExchange,
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
                          color: canExchange
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
        Row(mainAxisSize: MainAxisSize.min, children: [
          CurrencyIcon(
              title == '패롯' ? Currency.parrot : Currency.cracker,
              size: 16),
          const SizedBox(width: 4),
          Text(title,
              style: context.texts.labelMedium
                  .copyWith(color: context.tokens.textTertiary)),
        ]),
        const SizedBox(height: 4),
        Text(
          NumberFormat.decimalPattern('ko').format(amount),
          style: context.texts.headlineSmall.copyWith(color: color),
        ),
      ],
    );
  }
}

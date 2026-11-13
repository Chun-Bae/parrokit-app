import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimeTripletField extends StatefulWidget {
  const TimeTripletField({
    super.key,
    required this.label,
    required this.target,
    this.showGuide = true,
    this.compact = false,
    this.onCommitted,
    this.action,
  });

  final String label;
  final TextEditingController target;
  final bool showGuide;
  final bool compact;
  final VoidCallback? onCommitted;
  final Widget? action;

  @override
  State<TimeTripletField> createState() => _TimeTripletFieldState();
}

class _TimeTripletFieldState extends State<TimeTripletField> {
  late final TextEditingController _mCtl;
  late final TextEditingController _sCtl;
  late final TextEditingController _msCtl;

  late final FocusNode _mFn;
  late final FocusNode _sFn;
  late final FocusNode _msFn;

  late final VoidCallback _targetListener;

  @override
  void initState() {
    super.initState();
    // 처음부터 자리를 채워 보인다. 예전엔 '0 : 0 . 50'처럼 보여 0.05초가
    // 0.5초로 읽혔다(5차).
    final init = _fromMMSsMs(widget.target.text);
    _mCtl = TextEditingController(text: _pad2(init.m));
    _sCtl = TextEditingController(text: _pad2(init.s));
    _msCtl = TextEditingController(text: _pad3(init.ms));

    _mFn = FocusNode()..addListener(_onFocusChange);
    _sFn = FocusNode()..addListener(_onFocusChange);
    _msFn = FocusNode()..addListener(_onFocusChange);

    // 외부에서 target이 바뀌면 내부 칸에 반영
    _targetListener = _syncFromTarget;
    widget.target.addListener(_targetListener);

    // ✅ 초기 동기화: target.text가 비어있거나 형식이 아니면 기본값으로 채움
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncToTarget();
    });
  }

  @override
  void didUpdateWidget(covariant TimeTripletField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.target != widget.target) {
      oldWidget.target.removeListener(_targetListener);
      widget.target.addListener(_targetListener);
      _syncFromTarget();
    }
  }

  @override
  void dispose() {
    widget.target.removeListener(_targetListener);
    _mCtl.dispose();
    _sCtl.dispose();
    _msCtl.dispose();
    _mFn.dispose();
    _sFn.dispose();
    _msFn.dispose();
    super.dispose();
  }

  void _setIfDiff(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  /// target 값을 칸에 옮긴다. 자리를 채워 보이되, 지금 치고 있는 칸은 건드리지
  /// 않는다(치는 중에 '5'가 '05'로 바뀌면 커서가 튀고 다음 글자가 막힌다).
  void _syncFromTarget() {
    final p = _fromMMSsMs(widget.target.text);
    if (!_mFn.hasFocus) _setIfDiff(_mCtl, _pad2(p.m));
    if (!_sFn.hasFocus) _setIfDiff(_sCtl, _pad2(p.s));
    if (!_msFn.hasFocus) _setIfDiff(_msCtl, _pad3(p.ms));
  }

  void _onFocusChange() {
    // 칸이 '00'·'000'으로 차 있어 끝에 숫자를 치면 글자 수 제한에 막혔다.
    // 칸을 누르면 전체를 골라서 치는 숫자로 바로 바뀌게 한다(5차).
    for (final (fn, ctl) in [(_mFn, _mCtl), (_sFn, _sCtl), (_msFn, _msCtl)]) {
      if (fn.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && fn.hasFocus) {
            ctl.selection =
                TextSelection(baseOffset: 0, extentOffset: ctl.text.length);
          }
        });
      }
    }
    // 포커스 빠질 때: 강제 동기화 + 보기용 패딩 반영
    if (!(_mFn.hasFocus || _sFn.hasFocus || _msFn.hasFocus)) {
      _syncToTarget();
      _applyPaddingToFields(); // "04" / "07" / "005" 같은 형식으로 보여주기
      widget.onCommitted?.call();
    }
  }

  void _applyPaddingToFields() {
    final m = int.tryParse(_mCtl.text) ?? 0;
    final s = int.tryParse(_sCtl.text) ?? 0;
    final ms = int.tryParse(_msCtl.text) ?? 0;
    _setIfDiff(_mCtl, _pad2(m));
    _setIfDiff(_sCtl, _pad2(s));
    _setIfDiff(_msCtl, _pad3(ms));
  }

  void _syncToTarget() {
    final m = int.tryParse(_mCtl.text) ?? 0;
    final s = int.tryParse(_sCtl.text) ?? 0;
    final ms = int.tryParse(_msCtl.text) ?? 0;
    final norm = _toMMSsMs(m, s, ms);
    if (widget.target.text != norm) {
      widget.target.text = norm;
    }
  }

  InputDecoration _dec(String label, String hint, ColorScheme cs) =>
      InputDecoration(
        isDense: true,
        labelText: widget.compact ? null : label,
        hintText: widget.compact ? label : hint,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        filled: false,
        contentPadding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 6 : 10,
            vertical: widget.compact ? 6 : 8),
      );

  Widget _numField(
    TextEditingController ctl, {
    required FocusNode fn,
    required String label,
    required String hint,
    required int maxLen,
    double width = 72,
  }) {
    ColorScheme cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.compact ? width * 0.7 : width,
      child: TextField(
        controller: ctl,
        focusNode: fn,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLen),
        ],
        onChanged: (_) => _syncToTarget(),
        // 타이핑 중 실시간 동기화
        onEditingComplete: _syncToTarget,
        // 키보드 완료
        onSubmitted: (_) => _syncToTarget(),
        // 제출(엔터)
        onTapOutside: (_) => _syncToTarget(),
        // 필드 밖 탭
        decoration: _dec(label, hint, cs),
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.compact) ...[
          Text(widget.label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 6),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _numField(_mCtl,
                    fn: _mFn, label: '분', hint: '00', maxLen: 2, width: 64),
                SizedBox(width: widget.compact ? 2 : 8),
                const Text(':'),
                SizedBox(width: widget.compact ? 2 : 8),
                _numField(_sCtl,
                    fn: _sFn, label: '초', hint: '00', maxLen: 2, width: 64),
                SizedBox(width: widget.compact ? 2 : 8),
                const Text('.'),
                SizedBox(width: widget.compact ? 2 : 8),
                _numField(_msCtl,
                    fn: _msFn, label: '밀리초', hint: '000', maxLen: 3, width: 84),
              ],
            ),
            if (widget.action != null) widget.action!,
          ],
        ),
        if (widget.showGuide) const SizedBox(height: 6),
        if (widget.showGuide)
          Text(
            '형식: mm:ss.mmm (00:04.230) • 범위: 초 0–59 / 밀리초 0–999',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );
  }
}

/// helpers
String _pad2(int v) => v.toString().padLeft(2, '0');

String _pad3(int v) => v.toString().padLeft(3, '0');

String _toMMSsMs(int minutes, int seconds, int millis) {
  seconds = seconds.clamp(0, 59);
  millis = millis.clamp(0, 999);
  minutes = minutes < 0 ? 0 : minutes;
  return '${_pad2(minutes)}:${_pad2(seconds)}.${_pad3(millis)}';
}

({int m, int s, int ms}) _fromMMSsMs(String? v) {
  final re = RegExp(r'^(\d{2}):(\d{2})\.(\d{3})$');
  final m = re.firstMatch((v ?? '').trim());
  if (m == null) return (m: 0, s: 0, ms: 0);
  return (
    m: int.parse(m.group(1)!),
    s: int.parse(m.group(2)!),
    ms: int.parse(m.group(3)!),
  );
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// 학습 기록과 연결하기 전, 먹이와 꾸미기 흐름을 확인하는 별도 시안.
class NestPreview extends StatefulWidget {
  const NestPreview({super.key});

  @override
  State<NestPreview> createState() => _NestPreviewState();
}

class _NestPreviewState extends State<NestPreview>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final idle =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));
  late final happy = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  int meals = 0;
  ui.Image? sprite;
  bool foreground = true;
  bool reducedMotion = false;
  bool visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadSprite();
  }

  Future<void> loadSprite() async {
    try {
      final bytes = await rootBundle
          .load('assets/characters/nest_parrot/blink-v3-sheet.png');
      final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      try {
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        setState(() => sprite = frame.image);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // 파일을 읽지 못하면 기존 코드 그림을 표시한다.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reducedMotion = MediaQuery.disableAnimationsOf(context);
    visible = TickerMode.of(context);
    syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    syncAnimation();
  }

  void syncAnimation() {
    if (foreground && visible && !reducedMotion) {
      if (!idle.isAnimating) idle.repeat();
    } else {
      idle.stop();
      happy.stop();
    }
  }

  void feed() {
    if (happy.isAnimating || meals >= 10) return;
    setState(() => meals++);
    if (!reducedMotion) happy.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sprite?.dispose();
    idle.dispose();
    happy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF334E65);
    const muted = Color(0xFF7A909D);
    final message = meals == 0
        ? '네가 공부하는 동안, 여기서 기다릴게.'
        : meals < 3
            ? '냠냠. 오늘도 함께해 줘서 고마워!'
            : meals < 6
                ? '우리 둥지에 작은 꽃이 피었어.'
                : meals < 10
                    ? '조금씩, 우리 공간이 되어 가네.'
                    : '우리의 첫 번째 둥지가 완성됐어!';
    final next = meals < 1
        ? 1
        : meals < 3
            ? 3
            : meals < 6
                ? 6
                : 10;
    final reward = meals < 1
        ? '작은 새싹'
        : meals < 3
            ? '데이지 꽃'
            : meals < 6
                ? '따뜻한 조명'
                : '꽃 가랜드';
    return Container(
      color: const Color(0xFFF3F8FD),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 18),
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Icon(Icons.spa_outlined, size: 18, color: muted),
            SizedBox(width: 8),
            Text('나의 작은 둥지',
                style: TextStyle(
                    color: ink, fontSize: 16, fontWeight: FontWeight.w700)),
            Spacer(),
            Text('첫 번째 보금자리', style: TextStyle(color: muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration:
              reducedMotion ? Duration.zero : const Duration(milliseconds: 300),
          child: Text(message,
              key: ValueKey(message),
              textAlign: TextAlign.center,
              style: const TextStyle(color: ink, fontSize: 14)),
        ),
        SizedBox(
          height: 280,
          width: double.infinity,
          child: Semantics(
            label: '작은 둥지의 앵무새. 먹이 $meals번, $reward까지 $next번.',
            child: AnimatedBuilder(
              animation: Listenable.merge([idle, happy]),
              builder: (context, _) => CustomPaint(
                  painter: NestScenePainter(
                phase: reducedMotion ? 0 : idle.value,
                joy: happy.isAnimating ? happy.value : 0,
                meals: meals,
                sprite: sprite,
              )),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Row(children: [
              const Text('함께 보낸 시간',
                  style: TextStyle(
                      color: ink, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$meals / 10',
                  style: const TextStyle(color: muted, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: meals / 10,
                  minHeight: 5,
                  color: const Color(0xFF9CBCCE),
                  backgroundColor: const Color(0xFFE2EBF1),
                )),
            const SizedBox(height: 10),
            Text(
                meals >= 10
                    ? '꽃과 빛으로 가득한 우리의 둥지'
                    : '$reward까지 먹이 ${next - meals}번',
                style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: meals < 10 ? feed : null,
              icon: const Icon(Icons.grass_rounded, size: 18),
              label: Text(meals < 10 ? '학습 완료 · 먹이 주기' : '첫 둥지 완성!'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: ink,
                side: const BorderSide(color: Color(0xFFCADBE5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
            ),
            const SizedBox(height: 8),
            const Text('먹이를 눌러보는 시안이에요 · 실제 학습 기록과 연결되지 않아요',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }
}

class NestScenePainter extends CustomPainter {
  NestScenePainter(
      {required this.phase,
      required this.joy,
      required this.meals,
      this.sprite});
  final ui.Image? sprite;
  final double phase;
  final double joy;
  final int meals;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, 0);
    final scale = math.min(size.width / 360, size.height / 280);
    canvas.scale(scale);
    void oval(Rect rect, Color color) =>
        canvas.drawOval(rect, Paint()..color = color);
    void line(Offset a, Offset b, Color color, double width) => canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round);
    const branch = Color(0xFFB59379);
    // 바닥과 둥지는 매번 그대로. 소품만 학습 횟수에 따라 더해진다.
    oval(const Rect.fromLTWH(-139, 220, 278, 23), const Color(0xFFE4EDF2));
    oval(const Rect.fromLTWH(-118, 211, 236, 14), const Color(0xFFF8FCFE));
    if (meals >= 1) {
      line(const Offset(-105, 218), const Offset(-105, 179),
          const Color(0xFF91AD8D), 3);
      canvas.save();
      canvas.translate(-105, 194);
      canvas.rotate(-0.5);
      oval(const Rect.fromLTWH(-19, -11, 20, 10), const Color(0xFFABC6A0));
      oval(const Rect.fromLTWH(0, -16, 22, 11), const Color(0xFF91B394));
      canvas.restore();
    }
    if (meals >= 3) {
      line(const Offset(108, 218), const Offset(108, 171),
          const Color(0xFF9DB599), 3);
      for (var i = 0; i < 7; i++) {
        final angle = i * math.pi * 2 / 7;
        canvas.save();
        canvas.translate(108, 169);
        canvas.rotate(angle);
        oval(const Rect.fromLTWH(-5, -19, 10, 18), const Color(0xFFFFFFFF));
        canvas.restore();
      }
      canvas.drawCircle(
          const Offset(108, 169), 6, Paint()..color = const Color(0xFFE6C878));
    }
    if (meals >= 6) {
      line(const Offset(-143, 214), const Offset(-143, 112), branch, 4);
      line(const Offset(-143, 112), const Offset(-117, 112), branch, 4);
      line(const Offset(-117, 112), const Offset(-117, 123), branch, 2);
      canvas.drawCircle(const Offset(-117, 137), 25,
          Paint()..color = const Color(0xFFFFE8AA).withValues(alpha: 0.23));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-127, 124, 20, 27), const Radius.circular(7)),
          Paint()..color = const Color(0xFFF1D18F));
      line(const Offset(-126, 124), const Offset(-108, 124), branch, 3);
    }
    if (meals >= 10) {
      final garland = Path()
        ..moveTo(-150, 48)
        ..quadraticBezierTo(0, 105, 150, 48);
      canvas.drawPath(
          garland,
          Paint()
            ..color = const Color(0xFFBBCBB4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      for (var i = 0; i < 7; i++) {
        final x = -126.0 + i * 42;
        final y = 76 - 28 * math.pow(x / 150, 2);
        canvas.drawCircle(
            Offset(x, y.toDouble()),
            5,
            Paint()
              ..color =
                  i.isEven ? const Color(0xFFE9BCB2) : const Color(0xFFDED3A0));
      }
    }
    // 겹겹이 엮인 작은 둥지.
    oval(const Rect.fromLTWH(-68, 194, 136, 35), const Color(0xFFB99B7F));
    oval(const Rect.fromLTWH(-62, 191, 124, 22), const Color(0xFFD6BE9F));
    oval(const Rect.fromLTWH(-46, 193, 92, 15), const Color(0xFFA68A71));
    for (var i = 0; i < 8; i++) {
      final x = -55.0 + i * 14;
      line(Offset(x, 213 + i % 2 * 4), Offset(x + 24, 208),
          const Color(0xFFDECAAF), 2);
    }
    canvas.save();
    final bounce =
        joy > 0 ? math.sin(joy * math.pi * 4).abs() * (1 - joy) * 13 : 0.0;
    canvas.translate(0, -bounce);
    final sheet = sprite;
    if (sheet != null) {
      // 몸은 고정하고 눈만 짧게 깜빡인다.
      final t = ((phase * 12000) % 4240).floor();
      const ends = [3000, 3070, 3170, 3240, 4240];
      final step = ends.indexWhere((end) => t < end);
      final index = const [0, 1, 2, 1, 0][step];
      final cellWidth = sheet.width / 3;
      final cellHeight = sheet.height.toDouble();
      final fitted = applyBoxFit(
          BoxFit.contain, Size(cellWidth, cellHeight), const Size(216, 216));
      final destination = Alignment.bottomCenter.inscribe(
          fitted.destination, const Rect.fromLTWH(-108, 12, 216, 216));
      canvas.drawImageRect(
        sheet,
        Rect.fromLTWH(index * cellWidth, 0, cellWidth, cellHeight),
        destination,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      // 꼬리, 몸, 날개.
      final tail = Path()
        ..moveTo(23, 171)
        ..quadraticBezierTo(66, 179, 64, 214)
        ..quadraticBezierTo(31, 205, 17, 191)
        ..close();
      canvas.drawPath(tail, Paint()..color = const Color(0xFF79A9A4));
      oval(const Rect.fromLTWH(-42, 123, 84, 80), const Color(0xFF91BEB0));
      oval(const Rect.fromLTWH(-29, 142, 59, 58), const Color(0xFFD7E5C4));
      canvas.save();
      canvas.translate(-29, 157);
      canvas.rotate(-0.22 - bounce * 0.025);
      oval(const Rect.fromLTWH(-12, -12, 23, 43), const Color(0xFF78A99D));
      canvas.restore();
      // 얼굴을 조금 돌리고 눈동자만 옮겨 두리번거린다.
      final look = math.sin(phase * math.pi * 2);
      canvas.save();
      canvas.translate(0, 123);
      canvas.rotate(look * 0.045);
      canvas.translate(0, -123);
      oval(const Rect.fromLTWH(-45, 76, 90, 81), const Color(0xFFA6CCB9));
      final crest = Path()
        ..moveTo(-13, 83)
        ..quadraticBezierTo(-20, 57, -4, 62)
        ..quadraticBezierTo(4, 65, 4, 78)
        ..quadraticBezierTo(11, 59, 19, 68)
        ..lineTo(19, 85)
        ..close();
      canvas.drawPath(crest, Paint()..color = const Color(0xFF91BEB0));
      final blink =
          (phase > 0.23 && phase < 0.245) || (phase > 0.72 && phase < 0.735);
      for (final x in [-19.0, 19.0]) {
        if (blink || joy > 0) {
          final eye = Path()
            ..moveTo(x - 5, 112)
            ..quadraticBezierTo(x, joy > 0 ? 105 : 116, x + 5, 112);
          canvas.drawPath(
              eye,
              Paint()
                ..color = const Color(0xFF3E5D57)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..strokeCap = StrokeCap.round);
        } else {
          oval(Rect.fromLTWH(x - 6, 103, 12, 17), const Color(0xFFFFFEF7));
          oval(Rect.fromLTWH(x - 3 + look * 2, 107, 6, 9),
              const Color(0xFF3E5D57));
        }
        oval(Rect.fromLTWH(x - 7, 124, 14, 6),
            const Color(0xFFE8C5AE).withValues(alpha: 0.75));
      }
      final beak = Path()
        ..moveTo(-7, 119)
        ..quadraticBezierTo(0, 113, 8, 119)
        ..quadraticBezierTo(5, 132, 0, 134)
        ..close();
      canvas.drawPath(beak, Paint()..color = const Color(0xFFE2B373));
      canvas.restore();
    }
    canvas.restore();
    if (joy > 0) {
      canvas.save();
      canvas.translate(0, 65 - joy * 30);
      canvas.scale(1 - joy * 0.35);
      final heart = Path()
        ..moveTo(0, 8)
        ..cubicTo(-30, -8, -15, -26, 0, -13)
        ..cubicTo(15, -26, 30, -8, 0, 8);
      canvas.drawPath(heart,
          Paint()..color = const Color(0xFFDDA59C).withValues(alpha: 1 - joy));
      canvas.restore();
      final seed = Offset(28 * (1 - joy), 169 - math.sin(joy * math.pi) * 40);
      oval(Rect.fromCenter(center: seed, width: 9, height: 13),
          const Color(0xFFD8B983));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NestScenePainter oldDelegate) =>
      phase != oldDelegate.phase ||
      joy != oldDelegate.joy ||
      meals != oldDelegate.meals ||
      sprite != oldDelegate.sprite;
}

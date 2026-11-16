import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/video_subtitle_style.dart';

class SubtitleOverlay extends StatelessWidget {
  const SubtitleOverlay({
    super.key,
    required this.ja,
    required this.pron,
    required this.ko,
  });

  final String ja;
  final String pron;
  final String ko;

  @override
  Widget build(BuildContext context) {
    // 그림자와 발음 색은 쇼츠 자막과 같은 값을 쓴다(5차). 예전에는 한 겹
    // 그림자에 발음이 white70이라 밝은 영상 위에서 거의 안 보였다.
    TextStyle base(double size,
            {FontWeight w = FontWeight.w600, Color c = Colors.white}) =>
        TextStyle(
          fontSize: size,
          fontWeight: w,
          color: c,
          height: 1.25,
          shadows: videoSubtitleShadows,
        );

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ja.isNotEmpty)
                Text(ja, textAlign: TextAlign.center, style: base(18)),
              // 빈 줄에도 사이를 띄워 자막이 위로 떠 보이던 것을 막는다.
              if (pron.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  pron,
                  textAlign: TextAlign.center,
                  style: base(14,
                      w: FontWeight.w500, c: videoSubtitlePronColor),
                ),
              ],
              if (ko.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(ko, textAlign: TextAlign.center, style: base(16)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 영상 위에 얹는 자막의 공통 규칙.
///
/// 쇼츠와 클립 플레이어가 자막을 따로 그리다 보니 한쪽(쇼츠)만 고쳐져
/// 플레이어의 발음 줄은 밝은 영상 위에서 거의 안 보였다(5차). 같은 값을
/// 한 곳에서 가져다 쓴다. 글자 크기는 화면마다 달라 각자 정한다.
///
/// 가까운 진한 그림자와 넓은 옅은 그림자를 겹쳐, 흰 바탕 위에서도 글자
/// 테두리가 살아난다.
const List<Shadow> videoSubtitleShadows = [
  Shadow(blurRadius: 2, color: Colors.black87, offset: Offset(0, 1)),
  Shadow(blurRadius: 10, color: Colors.black54),
];

/// 발음 줄 색. 원문·해석보다 살짝 여리지만 흐릿하지는 않다.
/// 예전 `Colors.white70`은 밝은 영상에서 바탕에 묻혔다.
const Color videoSubtitlePronColor = Color(0xE6FFFFFF);

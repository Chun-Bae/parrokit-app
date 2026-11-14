---
name: native-tabbar-platform-view
description: 아래 탭 바가 네이티브 iOS UITabBar(UiKitView)라서 생기는 화면 문제를 다룬다. 바텀시트나 전체 화면 위에 희미한 가로선·띠·그림자가 비칠 때, 탭 바 위에 뭔가 덮이지 않을 때, 탭 바 흐림·배경을 Flutter에서 바꿔도 아무 변화가 없을 때 사용한다.
---

# 네이티브 탭 바(UiKitView)에서 오는 화면 문제

## 핵심 사실

아래 탭 바는 **Flutter 위젯이 아니다**.

- `AppBottomNavBar` → `NativeGlassNavBar`(`native_glass_navbar` 1.0.0)
- 그 안은 `UiKitView(viewType: 'NativeTabBar')`로 띄운 **진짜 iOS `UITabBarController`**
- 높이는 `49 + 하단 안전영역`. iPhone에서 34이면 **83pt**
- `_GlassFallbackNavBar`(Flutter로 그린 유리 흉내)는 **iOS 26에서는 쓰이지 않는다**.
  `LiquidGlassHelper.isLiquidGlassSupported()`가 true면 네이티브 쪽으로 간다

## 그래서 생기는 일

### 1. 시트 위에 비치는 희미한 가로선 (5차에서 고침)

증상: 탭 바가 있는 화면에서 바텀시트를 열면, 화면 아래에서 82pt 되는 자리에
위로 번지는 옅은 띠와 또렷한 경계가 보인다. 라이트에서만 보인다.

원인: 네이티브 탭 바는 자기 프레임(아래 83pt) **바깥 위쪽 약 23pt**에 그림자를
드리운다. Flutter는 플랫폼 뷰 위로 올라가는 내용을 **그 뷰의 프레임 안쪽에만**
오버레이로 덮는다. 프레임 밖 그림자는 안 덮여서 시트 위로 비친다.

고친 방법(`app_bottom_sheet.dart`, `app_shell.dart`): 시트가 떠 있는 동안
셸이 탭 바를 숨긴다. 전역 `openAppSheetCount`를 `showAppSheet`가 올리고
내리며, 셸은 `ValueListenableBuilder` + `Visibility(maintainSize: true)`로
자리만 남기고 감춘다. 공통 시트를 안 쓰는 곳은
`withNavBarHiddenForSheet(() => showModalBottomSheet(...))`로 감싼다.

### 2. 다이얼로그는 그대로 둔다

`showDialog`는 탭 바를 가리지 않으므로 숨기면 오히려 어색하다.

## 진단 순서 (헛걸음 줄이기)

여기서 헤맸던 순서 그대로 적어 둔다. 1~3은 **전부 소용없다**.

1. ~~Flutter 쪽 `BackdropFilter`·blur sigma를 0으로~~ → 폴백 코드라 안 쓰인다
2. ~~공통 시트의 면·그림자 제거~~ → 관계없다
3. ~~`debugPaintLayerBordersEnabled`~~ → Flutter가 그린 게 아니라 경계가 안 나온다
4. **다크에서도 보이나?** 안 보이면 검은 그림자가 흰 바탕에만 보이는 것이다
5. **탭 바가 없는 화면에도 있나?** 없으면 탭 바 쪽이다
6. **가로로 재 본다.** 화면 가장자리(x=8, x=1312px)까지 가면 전체 폭,
   안 가면 떠 있는 알약 폭이다 → 플랫폼 뷰
7. **결정적 확인**: `AppBottomNavBar`가 네이티브 대신 폴백만 쓰게 임시로 바꿔
   빌드한다. 증상이 사라지면 네이티브 탭 바가 원인이다. 확인 뒤 되돌린다

```dart
// 임시 확인용. 커밋하지 않는다.
return _GlassFallbackNavBar(currentIndex: currentIndex, onTap: onTap);
```

## 픽셀로 재는 법

시뮬레이터 화면은 1320x2868px = 440x956pt (3배). 1~2 차이의 옅은 띠는
눈으로 안 보이니 값을 직접 읽는다.

```bash
python3 -c "
from PIL import Image
im=Image.open('<screenshot.png>').convert('RGB')
for y in range(2546, 2650, 6):
    print(y, [im.getpixel((x,y))[0] for x in (8,40,660,1200,1280,1312)])
"
```

## 고칠 때 주의

- 패키지는 `~/.pub-cache`에 있다. 거기를 고치면 `flutter pub get`에 날아간다.
  Swift를 바꿔야 하면 패키지를 저장소 안으로 복사해야 하고, 그건 사용자에게
  먼저 묻는다
- 앱 코드(셸·시트)에서 피할 수 있으면 그쪽이 낫다
- 플랫폼 뷰를 껐다 켜면 `UITabBarController`를 다시 만든다(비싸고 깜빡인다).
  숨길 때는 `Visibility`로 트리에 두고 감춘다

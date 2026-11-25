#!/usr/bin/env python3
"""Android 적응형 아이콘의 전경 그림을 만든다(5차).

왜 따로 만드나:
    안드로이드 런처는 아이콘의 바깥 25%를 잘라 동그라미·네모·물방울 등
    제 모양으로 깎는다. 그래서 배경까지 들어간 꽉 찬 그림을 전경으로 주면
    새의 발과 꼬리가 잘린다.

무엇을 하나:
    배경 없는 원본(new_app_icon.png)을 캔버스의 58%로 줄여 가운데 놓는다.
    안전 영역은 66%지만 꽉 채우면 마스크 모양에 따라 아슬아슬해서 여유를
    둔다.

원본 그림이나 비율을 바꾸면 이 스크립트를 다시 돌리고 아이콘을 다시
만든다:

    python3 tool/make_adaptive_foreground.py
    dart run flutter_launcher_icons
"""

import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow가 필요하다: python3 -m pip install Pillow")

# 배경이 없는(알파가 있는) 원본이어야 한다.
SRC = "assets/icons/new_app_icon.png"
OUT = "assets/icons/new_app_icon_foreground.png"
CANVAS = 1024
# 안전 영역(66%)보다 작게 둬서 어떤 마스크에도 여유가 있게 한다.
SUBJECT_RATIO = 0.58


def main():
    src = Image.open(SRC)
    if src.mode != "RGBA":
        sys.exit(
            f"{SRC}에 알파가 없다(mode={src.mode}). 배경을 뺀 그림이어야 한다."
        )

    box = src.getbbox()
    if box is None:
        sys.exit(f"{SRC}이 비어 있다.")

    bird = src.crop(box)
    target = int(CANVAS * SUBJECT_RATIO)
    scale = min(target / bird.width, target / bird.height)
    bird = bird.resize(
        (int(bird.width * scale), int(bird.height * scale)), Image.LANCZOS
    )

    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    out.paste(bird, ((CANVAS - bird.width) // 2, (CANVAS - bird.height) // 2), bird)
    out.save(OUT)

    print(
        f"{OUT} 만듦 - 새가 가로 {100 * bird.width / CANVAS:.0f}%, "
        f"세로 {100 * bird.height / CANVAS:.0f}%를 차지한다"
    )


if __name__ == "__main__":
    main()

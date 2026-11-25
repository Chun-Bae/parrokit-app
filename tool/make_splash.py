#!/usr/bin/env python3
"""스플래시 그림의 새만 갈아 끼운다(5차, 사용자 요청).

왜 통째로 다시 그리지 않나:
    스플래시는 **새 + 'Parrokit' 글자 + 한 줄 설명**이 한 장에 구워져 있다.
    글자를 다시 그리면 글꼴과 자간이 어긋난다. 그래서 새가 있던 자리만
    비우고 새 그림을 끼운다. 글자 픽셀은 건드리지 않는다.

무엇을 만드나:
    - pa_splash.png / pa_splash_dark.png (998x532)
      왼쪽 새(x 0~418, y 0~469)만 갈아 끼운다. 밝은 쪽과 어두운 쪽은
      글자 색만 다르고 자리는 같다.
    - pa_splash_android12.png (2048x2048)
      안드로이드 12+는 가운데 아이콘만 쓰고 동그라미로 깎는다. 흰 바탕에
      새를 가운데 두되 원본과 같은 비율(가로 33%)로 둔다.

스플래시 파일을 **제자리에서 고친다.** 글자 픽셀을 그대로 쓰려면 원본을
바탕으로 삼아야 하기 때문이다. 여러 번 돌려도 결과는 같다(새 자리를 비우고
다시 끼운다). 옛 그림이 필요하면 git에서 되돌린다.

원본(new_app_icon.png)이 바뀌면 다시 돌리고 스플래시를 다시 만든다:

    python3 tool/make_splash.py
    dart run flutter_native_splash:create
"""

import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow가 필요하다: python3 -m pip install Pillow")

BIRD = "assets/icons/new_app_icon.png"

# 가로형 스플래시에서 새가 차지하던 칸.
WIDE_BIRD_BOX = (0, 0, 419, 470)
WIDE_BIRD_TOP = 98
WIDE_BIRD_BOTTOM = 460
WIDE_BIRD_RIGHT = 415

# 안드로이드 12 스플래시. 원본에서 머리가 가로 33%를 차지했다.
A12_SIZE = 2048
A12_RATIO = 0.33
A12_BACKGROUND = (255, 255, 255, 255)


def load_bird():
    bird = Image.open(BIRD)
    if bird.mode != "RGBA":
        sys.exit(f"{BIRD}에 알파가 없다(mode={bird.mode}). 배경을 뺀 그림이어야 한다.")
    box = bird.getbbox()
    if box is None:
        sys.exit(f"{BIRD}이 비어 있다.")
    return bird.crop(box)


def make_wide(src_path, bird):
    """가로형 스플래시의 새만 갈아 끼운다. 글자는 그대로 둔다."""
    im = Image.open(src_path).convert("RGBA")
    px = im.load()
    x0, y0, x1, y1 = WIDE_BIRD_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)

    height = WIDE_BIRD_BOTTOM - WIDE_BIRD_TOP
    scale = height / bird.height
    sized = bird.resize((int(bird.width * scale), height), Image.LANCZOS)
    left = max(0, WIDE_BIRD_RIGHT - sized.width)
    im.paste(sized, (left, WIDE_BIRD_TOP), sized)
    im.save(src_path)
    print(f"{src_path} - 새 {sized.size}, 왼쪽 {left}")


def make_android12(path, bird):
    """가운데에 새만 둔다. 런처가 동그라미로 깎으므로 여백을 넉넉히 둔다."""
    target = int(A12_SIZE * A12_RATIO)
    scale = min(target / bird.width, target / bird.height)
    sized = bird.resize(
        (int(bird.width * scale), int(bird.height * scale)), Image.LANCZOS
    )
    out = Image.new("RGBA", (A12_SIZE, A12_SIZE), A12_BACKGROUND)
    out.paste(
        sized,
        ((A12_SIZE - sized.width) // 2, (A12_SIZE - sized.height) // 2),
        sized,
    )
    out.save(path)
    print(f"{path} - 새 {sized.size} (가로 {100 * sized.width / A12_SIZE:.0f}%)")


def main():
    bird = load_bird()
    make_wide("assets/splash/pa_splash.png", bird)
    make_wide("assets/splash/pa_splash_dark.png", bird)
    make_android12("assets/splash/pa_splash_android12.png", bird)


if __name__ == "__main__":
    main()

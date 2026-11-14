#!/usr/bin/env python3
"""화면 어디서도 만들지 않는 위젯을 찾는다(5차 반복 169).

파일 단위로 보는 .claude/dead-code-candidates.md와 달리, **쓰이는 파일 안에
섞여 있는** 위젯을 잡는다. 오늘 목표를 바꾸는 길이 끊겨 있던 것
(TodayPracticeSummary, 반복 168)이 이 방식으로만 보였다.

쓰는 법: python3 tool/find_unused_widgets.py
결과는 후보일 뿐이다. 지우거나 다시 잇기 전에 grep으로 한 번 더 확인한다
(같은 파일 안에서만 쓰는 위젯은 여기서도 '선언만'으로 보일 수 있다).
"""
import os
import re
import subprocess

DECL = re.compile(r'^class\s+(\w+)\s+extends\s+(?:StatelessWidget|StatefulWidget)\b', re.M)


def widget_declarations(root='lib'):
    found = {}
    for base, _dirs, files in os.walk(root):
        for name in files:
            if not name.endswith('.dart'):
                continue
            path = os.path.join(base, name)
            with open(path, encoding='utf-8') as f:
                source = f.read()
            for match in DECL.finditer(source):
                widget = match.group(1)
                if widget.startswith('_'):
                    continue  # 파일 안에서만 쓰는 위젯은 분석기가 잡아 준다
                found[widget] = path
    return found


def files_mentioning(widget):
    done = subprocess.run(
        ['grep', '-rln', rf'\b{widget}\b', 'lib', 'test'],
        capture_output=True, text=True)
    return [p for p in done.stdout.split() if p]


def main():
    declarations = widget_declarations()
    unused = []
    for widget, path in sorted(declarations.items(), key=lambda kv: kv[1]):
        others = [p for p in files_mentioning(widget) if p != path]
        if not others:
            unused.append((widget, path))
    print(f'위젯 {len(declarations)}개 중 선언 파일 밖에서 안 쓰이는 것 {len(unused)}개')
    for widget, path in unused:
        print(f' - {widget} | {path}')


if __name__ == '__main__':
    main()

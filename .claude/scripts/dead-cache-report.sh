#!/bin/bash
# 시뮬레이터 Dead 캐시(지워진 앱 컨테이너 찌꺼기)를 기기별로 잰다.
# 설치를 반복하면 여기 쌓여서 맥 디스크를 다 먹는다(2026-11-14: 67GB, 11-16: 78GB).
# 켜져 있는 기기는 BOOTED로 표시한다. 켜진 기기의 Dead는 끄고 지워야 한다.

booted=$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | tr '\n' ' ')
echo "free_space=$(df -h / | tail -1 | awk '{print $4}')"
for dir in ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/com.apple.containermanagerd/Dead; do
  [ -d "$dir" ] || continue
  udid=$(echo "$dir" | sed -E 's#.*/Devices/([^/]+)/.*#\1#')
  size=$(du -sk "$dir" 2>/dev/null | awk '{printf "%.1f", $1/1048576}')
  state="shutdown"
  case " $booted " in *" $udid "*) state="BOOTED";; esac
  echo "device=$udid state=$state dead_gb=$size"
done

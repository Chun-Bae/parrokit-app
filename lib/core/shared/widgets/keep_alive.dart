// 탭을 옮겨도 그 화면을 살려 둔다(5차 466).
//
// TabBarView는 화면 밖으로 넘긴 탭을 버리고, 돌아오면 처음부터 다시
// 만든다. 그러면 목록을 다시 읽느라 탭을 옮길 때마다 빈 화면이 잠깐
// 보이고 스크롤 위치도 맨 위로 돌아간다.
//
// 보관함이 쓰던 것을 꺼내 커뮤니티에서도 쓴다.

import 'package:flutter/material.dart';

class TabKeepAlive extends StatefulWidget {
  const TabKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<TabKeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<TabKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

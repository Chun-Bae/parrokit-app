import 'package:flutter/material.dart';

class StudioHubProvider extends ChangeNotifier {
  String? _pendingCaptionFilePath;
  String? get pendingCaptionFilePath => _pendingCaptionFilePath;

  int? _requestedTabIndex;
  int? get requestedTabIndex => _requestedTabIndex;

  void sendAudioToCaptioning(String filePath) {
    _pendingCaptionFilePath = filePath;
    _requestedTabIndex = 0; // 자막 화면 탭
    notifyListeners();
  }

  void consumePendingCaptionFile(Function(String) onConsume) {
    if (_pendingCaptionFilePath != null) {
      onConsume(_pendingCaptionFilePath!);
      _pendingCaptionFilePath = null;
    }
  }

  /// 탭마다 '잃을 작업이 있는지' 묻는 함수. 예전엔 아무것도 안 했어도 나갈 때
  /// 확인 창을 띄웠다(5차). 나갈 때 한 번 물어서 하나라도 있으면 확인한다.
  final Map<String, bool Function()> _workChecks = {};

  void setWorkCheck(String tab, bool Function() hasWork) =>
      _workChecks[tab] = hasWork;

  bool get hasUnsavedWork => _workChecks.values.any((check) {
        try {
          return check();
        } catch (_) {
          return true; // 확인하지 못하면 묻는 쪽이 안전하다.
        }
      });

  void clearRequestedTabIndex() {
    if (_requestedTabIndex != null) {
      _requestedTabIndex = null;
    }
  }
}

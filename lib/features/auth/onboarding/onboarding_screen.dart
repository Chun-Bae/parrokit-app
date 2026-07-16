import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nicknameController = TextEditingController();
  
  bool _isNicknameAvailable = false;
  bool _hasCheckedNickname = false;
  String? _nicknameCheckMessage;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  bool get _isLoading => context.watch<UserProvider>().isLoading;

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() {
        _nicknameCheckMessage = '닉네임을 입력해주세요.';
        _isNicknameAvailable = false;
        _hasCheckedNickname = true;
      });
      return;
    }

    final isAvailable = await context.read<UserProvider>().isNicknameAvailable(nickname);
    setState(() {
      _isNicknameAvailable = isAvailable;
      _hasCheckedNickname = true;
      _nicknameCheckMessage = isAvailable ? '사용 가능한 닉네임입니다.' : '이미 사용 중인 닉네임입니다.';
    });
  }

  Future<void> _onSubmit() async {
    final nickname = _nicknameController.text.trim();
    
    if (nickname.isEmpty) {
      showToast('닉네임을 입력해주세요.');
      return;
    }
    
    if (!_hasCheckedNickname || !_isNicknameAvailable) {
      showToast('닉네임 중복 확인을 먼저 해주세요.');
      return;
    }

    try {
      await context.read<UserProvider>().updateDisplayName(nickname);
      if (!mounted) return;
      showToast('닉네임 설정이 완료되었습니다!');
      // 명시적으로 메인(대시보드)으로 이동
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      showToast('오류가 발생했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final WidgetStateColor iconColor =
        WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return const Color(0xFF0066FF);
      }
      return Colors.grey.shade500;
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '프로필 설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // 뒤로가기 방지 (필수 관문)
        automaticallyImplyLeading: false, 
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '환영합니다! 🎉',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '커뮤니티에서 사용할 멋진 닉네임을 설정해주세요.',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 48),
                  // 닉네임 입력칸
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nicknameController,
                          onChanged: (val) {
                            setState(() {
                              _hasCheckedNickname = false;
                              _nicknameCheckMessage = null;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: '닉네임',
                            labelStyle: TextStyle(
                                color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                            floatingLabelStyle: const TextStyle(
                                color: Color(0xFF0066FF), fontWeight: FontWeight.bold),
                            prefixIconColor: iconColor,
                            prefixIcon: const Icon(Icons.badge),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF0066FF), width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton(
                          onPressed: _nicknameController.text.trim().isEmpty ? null : _checkNickname,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0066FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('중복 확인'),
                        ),
                      ),
                    ],
                  ),
                  if (_hasCheckedNickname && _nicknameCheckMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _nicknameCheckMessage!,
                          style: TextStyle(
                            color: _isNicknameAvailable ? Colors.green : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              '시작하기',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

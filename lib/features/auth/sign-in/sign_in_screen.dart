import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAutoLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isLoading => context.watch<UserProvider>().isLoading;

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final userProvider = context.read<UserProvider>();

    try {
      await userProvider.signInWithEmail(email: email, password: password);
      if (!mounted) return;
      showToast('로그인에 성공했습니다.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          showToast('이메일 또는 비밀번호가 올바르지 않아요.');
        case 'user-not-found':
          showToast('등록되지 않은 이메일이에요.');
        case 'too-many-requests':
          showToast('요청이 너무 많아요. 잠시 후 다시 시도해 주세요.');
        default:
          showToast('오류가 발생했습니다: ${e.message}');
      }
    }
  }

  Future<void> _onGoogleSignIn() async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.signInWithGoogle();
      if (!mounted) return;
      // If userProvider.currentUser is set, sign in was successful
      if (userProvider.currentUser != null) {
        showToast('구글 로그인에 성공했습니다.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showToast('구글 로그인 오류: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showToast('구글 로그인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _onKakaoSignIn() async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.signInWithKakao();
      if (!mounted) return;
      if (userProvider.currentUser != null) {
        showToast('카카오 로그인에 성공했습니다.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showToast('카카오 로그인 오류: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showToast('카카오 로그인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _onNaverSignIn() async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.signInWithNaver();
      if (!mounted) return;
      if (userProvider.currentUser != null) {
        showToast('네이버 로그인에 성공했습니다.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showToast('네이버 로그인 오류: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showToast('네이버 로그인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _onAppleSignIn() async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.signInWithApple();
      if (!mounted) return;
      if (userProvider.currentUser != null) {
        showToast('애플 로그인에 성공했습니다.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showToast('애플 로그인 오류: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      showToast('애플 로그인 중 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 로고 영역
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logos/pa_logo.png',
                          width: 64, height: 64),
                      const SizedBox(width: 8),
                      const Text(
                        '패로킷',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  // 입력 폼
                  Form(
                    key: _formKey,
                    child: _buildFormFields(),
                  ),
                  const SizedBox(height: 16),
                  // 자동 로그인
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _isAutoLogin,
                          onChanged: (val) =>
                              setState(() => _isAutoLogin = val ?? true),
                          activeColor: const Color(0xFF0066FF),
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '자동 로그인',
                        style: TextStyle(
                          color: Color(0xFF0066FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // 로그인 버튼
                  _buildSubmitButton(),
                  const SizedBox(height: 32),
                  // 비밀번호 재설정 | 회원가입
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => context.pushNamed(AppRoutes.findPw),
                        child: const Text(
                          '비밀번호를 잊으셨나요?',
                          style: TextStyle(
                              color: Color(0xFF0066FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('|', style: TextStyle(color: Colors.grey)),
                      ),
                      GestureDetector(
                        onTap: () => context.pushNamed(AppRoutes.signUp),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                              color: Color(0xFF0066FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // 또는 구분선
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('또는',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // 소셜 로그인 아이콘
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialIcon('assets/icons/google_icon.png',
                          onTap: _onGoogleSignIn),
                      const SizedBox(width: 32),
                      _buildSocialIcon('assets/icons/kakao_icon.png',
                          onTap: _onKakaoSignIn),
                      const SizedBox(width: 32),
                      _buildSocialIcon('assets/icons/naver_icon.png',
                          onTap: _onNaverSignIn),
                      const SizedBox(width: 32),
                      _buildSocialIcon('assets/icons/apple_icon.png',
                          onTap: _onAppleSignIn),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    final WidgetStateColor iconColor =
        WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return const Color(0xFF0066FF);
      }
      return Colors.grey.shade500;
    });

    return Column(
      children: [
        // 이메일
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: '이메일',
            labelStyle: TextStyle(
                color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            floatingLabelStyle: const TextStyle(
                color: Color(0xFF0066FF), fontWeight: FontWeight.bold),
            prefixIconColor: iconColor,
            prefixIcon: const Icon(Icons.person),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF0066FF), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return '이메일을 입력해주세요.';
            if (!value.contains('@')) return '올바른 이메일 형식이 아닙니다.';
            return null;
          },
        ),
        const SizedBox(height: 16),
        // 비밀번호
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: '비밀번호',
            labelStyle: TextStyle(
                color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            floatingLabelStyle: const TextStyle(
                color: Color(0xFF0066FF), fontWeight: FontWeight.bold),
            prefixIconColor: iconColor,
            prefixIcon: const Icon(Icons.lock),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF0066FF), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
            if (value.length < 6) return '비밀번호는 6자 이상이어야 합니다.';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0066FF), // 파란색
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
                '로그인',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildSocialIcon(String assetPath, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

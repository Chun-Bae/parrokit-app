import 'package:parrokit/core/shared/utils/user_error_message.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/infrastructure/services/sso/naver_sso_service.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
          showToast(
              userErrorMessage(e, fallback: '로그인하지 못했어요. 잠시 후 다시 시도해 주세요.'));
      }
    } catch (e) {
      // FirebaseAuthException만 잡고 있었다. Firestore 쓰기 실패나 타임아웃처럼
      // 다른 예외가 나면 아무 데도 안 잡혀서 토스트도 안 뜬다. 사용자 눈에는
      // 버튼을 눌러도 아무 일이 없는 것으로 보인다. SSO 경로는 이미 이렇게
      // 일반 catch를 두고 있다.
      AppLogger.e('[Auth] 이메일 로그인 실패', error: e);
      if (!mounted) return;
      showToast('로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
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
      // Firebase 영어 원문을 그대로 보였다(5차). 코드에 맞는 안내로.
      showToast(userErrorMessage(e, fallback: '구글 로그인 중 오류가 발생했습니다.'));
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
      // Firebase 영어 원문을 그대로 보였다(5차). 코드에 맞는 안내로.
      showToast(userErrorMessage(e, fallback: '카카오 로그인 중 오류가 발생했습니다.'));
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
    } on NaverEmailInUseException catch (e) {
      if (!mounted) return;
      showToast(e.message);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Firebase 영어 원문을 그대로 보였다(5차). 코드에 맞는 안내로.
      showToast(userErrorMessage(e, fallback: '네이버 로그인 중 오류가 발생했습니다.'));
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
      // Firebase 영어 원문을 그대로 보였다(5차). 코드에 맞는 안내로.
      showToast(userErrorMessage(e, fallback: '애플 로그인 중 오류가 발생했습니다.'));
    } catch (e) {
      if (!mounted) return;
      showToast('애플 로그인 중 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.surface,
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
                      Text(
                        '패로킷',
                        style: context.texts.headlineLarge
                            .copyWith(letterSpacing: -1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  // 입력 폼
                  Form(
                    key: _formKey,
                    child: _buildFormFields(),
                  ),
                  // '자동 로그인' 체크 상자가 있었지만 값이 어디에도 쓰이지
                  // 않았다. 꺼 두어도 로그인 상태는 그대로 남아서, 끄면 안
                  // 남는 줄 알았던 사람에게는 거짓말이었다. 지금 로그인은
                  // 늘 유지되므로 상자를 뺀다(5차).
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
                        child: Text(
                          '비밀번호를 잊으셨나요?',
                          style: context.texts.labelMedium
                              .copyWith(color: context.tokens.primary),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('|',
                            style:
                                TextStyle(color: context.tokens.textTertiary)),
                      ),
                      GestureDetector(
                        onTap: () => context.pushNamed(AppRoutes.signUp),
                        child: Text(
                          '회원가입',
                          style: context.texts.labelMedium
                              .copyWith(color: context.tokens.primary),
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
                            style: context.texts.bodyMedium
                                .copyWith(color: context.tokens.textTertiary)),
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
                          label: '구글로 로그인', onTap: _onGoogleSignIn),
                      const SizedBox(width: 32),
                      _buildSocialIcon('assets/icons/kakao_icon.png',
                          label: '카카오로 로그인', onTap: _onKakaoSignIn),
                      const SizedBox(width: 32),
                      _buildSocialIcon('assets/icons/naver_icon.png',
                          label: '네이버로 로그인', onTap: _onNaverSignIn),
                      const SizedBox(width: 32),
                      _buildSocialIcon('assets/icons/apple_icon.png',
                          label: '애플로 로그인', onTap: _onAppleSignIn),
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
    final WidgetStateColor iconColor = WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return context.tokens.primary;
      }
      return context.tokens.textTertiary;
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
                color: context.tokens.textTertiary,
                fontWeight: FontWeight.w500),
            floatingLabelStyle: TextStyle(
                color: context.tokens.primary, fontWeight: FontWeight.bold),
            prefixIconColor: iconColor,
            prefixIcon: const Icon(Icons.person),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.tokens.borderStrong),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.tokens.primary, width: 2),
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
                color: context.tokens.textTertiary,
                fontWeight: FontWeight.w500),
            floatingLabelStyle: TextStyle(
                color: context.tokens.primary, fontWeight: FontWeight.bold),
            prefixIconColor: iconColor,
            prefixIcon: const Icon(Icons.lock),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.tokens.borderStrong),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.tokens.primary, width: 2),
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
          backgroundColor: context.tokens.primary, // 파란색
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
            : Text(
                '로그인',
                style: context.texts.titleMedium,
              ),
      ),
    );
  }

  /// 소셜 로그인 단추. 그림만 있어서 화면 읽기로는 무엇인지 알 수 없었고
  /// 길게 눌러도 이름이 안 떴다(5차, 다른 아이콘 단추와 같게 맞춘다).
  Widget _buildSocialIcon(String assetPath,
      {required String label, VoidCallback? onTap}) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
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
        ),
      ),
    );
  }
}

import 'package:parrokit/core/shared/utils/user_error_message.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class FindPwScreen extends StatefulWidget {
  const FindPwScreen({super.key});

  @override
  State<FindPwScreen> createState() => _FindPwScreenState();
}

class _FindPwScreenState extends State<FindPwScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _isLoading => context.watch<UserProvider>().isLoading;

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final userProvider = context.read<UserProvider>();

    try {
      await userProvider.sendPasswordResetEmail(email);
      if (!mounted) return;
      showToast('비밀번호 재설정 메일을 전송했습니다.');
      context.pop(); // Go back to sign in
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'user-not-found':
          showToast('등록되지 않은 이메일이에요.');
        case 'invalid-email':
          showToast('이메일 형식이 올바르지 않아요.');
        case 'too-many-requests':
          showToast('요청이 너무 많아요. 잠시 후 다시 시도해 주세요.');
        default:
          showToast(userErrorMessage(e,
              fallback: '메일을 보내지 못했어요. 잠시 후 다시 시도해 주세요.'));
      }
    } catch (e) {
      // FirebaseAuthException만 잡고 있었다. 그 밖의 예외는 아무 데도 안
      // 잡혀서 토스트조차 안 뜬다. 버튼이 먹통인 것으로 보인다.
      AppLogger.e('[Auth] 비밀번호 재설정 메일 전송 실패', error: e);
      if (!mounted) return;
      showToast('메일 전송 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.surface,
      appBar: AppBar(
        backgroundColor: context.tokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.tokens.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '비밀번호 재설정',
          style: context.texts.titleLarge
              .copyWith(color: context.tokens.textPrimary),
        ),
        centerTitle: true,
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
                  Text(
                    '비밀번호 재설정',
                    style: context.texts.headlineSmall
                        .copyWith(letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '가입하신 이메일 주소를 입력하시면 비밀번호 재설정 링크를 보내드립니다.',
                    style: context.texts.bodyMedium.copyWith(
                        color: context.tokens.textSecondary,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: _buildFormFields(),
                  ),
                  const SizedBox(height: 48),
                  _buildSubmitButton(),
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
                '메일 전송',
                style: context.texts.titleMedium,
              ),
      ),
    );
  }
}

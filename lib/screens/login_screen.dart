import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty) {
      setState(() {
        _error = 'اكتب البريد الإلكتروني';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _error = 'اكتب كلمة المرور';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await _auth.signIn(email, password);

      final user = cred.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'تعذر الحصول على بيانات المستخدم',
        );
      }

      await FirestoreService().ensureUserProfile(
        uid: user.uid,
        name: user.displayName,
        email: user.email,
        phone: user.phoneNumber,
      );

      if (!mounted) return;

      context.go('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'البريد الإلكتروني غير صحيح';
          break;

        case 'user-not-found':
          message = 'لا يوجد حساب بهذا البريد الإلكتروني';
          break;

        case 'wrong-password':
          message = 'كلمة المرور غير صحيحة';
          break;

        case 'invalid-credential':
          message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
          break;

        case 'user-disabled':
          message = 'تم تعطيل هذا الحساب';
          break;

        case 'too-many-requests':
          message = 'تمت محاولات تسجيل دخول كثيرة، حاول لاحقًا';
          break;

        case 'network-request-failed':
          message = 'تحقق من اتصال الإنترنت وحاول مرة أخرى';
          break;

        case 'operation-not-allowed':
          message =
              'تسجيل الدخول بالبريد الإلكتروني غير مفعّل في Firebase';
          break;

        default:
          message = 'تعذر تسجيل الدخول. رمز الخطأ: ${e.code}';
      }

      setState(() {
        _error = message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'حدث خطأ غير متوقع أثناء تسجيل الدخول';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: AppColors.gold,
                ),
              ),

              const SizedBox(height: 22),

              Text(
                'أهلًا بعودتك',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 6),

              const Text(
                'سجّل الدخول للمتابعة من حيث توقفت',
                style: TextStyle(
                  color: AppColors.muted,
                ),
              ),

              const SizedBox(height: 26),

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _passCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_loading) {
                    _submit();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => context.push('/forgot-password'),
                  child: const Text('نسيت كلمة المرور؟'),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.ink,
                          ),
                        )
                      : const Text('تسجيل الدخول'),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => context.push('/signup'),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'ليس لديك حساب؟ ',
                        ),
                        TextSpan(
                          text: 'إنشاء حساب جديد',
                          style: TextStyle(
                            color: AppColors.emeraldDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

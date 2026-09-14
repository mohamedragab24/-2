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
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await _auth.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      // Existing platform customers (registered through the website) may
      // already have a Firebase Auth account but no `users/{uid}` doc yet
      // — this fills it in on first app login without overwriting
      // anything the website already stored.
      final user = cred.user;
      if (user != null) {
        await FirestoreService().ensureUserProfile(
          uid: user.uid,
          name: user.displayName,
          email: user.email,
          phone: user.phoneNumber,
        );
      }
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = 'تعذّر تسجيل الدخول — تأكد من البريد وكلمة المرور');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                width: 52, height: 52,
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.school_outlined, color: AppColors.gold),
              ),
              const SizedBox(height: 22),
              Text('أهلًا بعودتك', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text('سجّل الدخول للمتابعة من حيث توقفت', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 26),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'البريد الإلكتروني أو رقم الهاتف')),
              const SizedBox(height: 14),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5)),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('نسيت كلمة المرور؟'),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                    : const Text('تسجيل الدخول'),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/signup'),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                      children: [
                        TextSpan(text: 'ليس لديك حساب؟ '),
                        TextSpan(text: 'إنشاء حساب جديد', style: TextStyle(color: AppColors.emeraldDark, fontWeight: FontWeight.w700)),
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

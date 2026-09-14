import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = AuthService();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await _auth.signUp(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
      final user = cred.user;
      if (user != null) {
        await FirestoreService().ensureUserProfile(
          uid: user.uid,
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
        );
      }
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = 'تعذّر إنشاء الحساب — تأكد من البيانات المدخلة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إنشاء حساب جديد', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text('خطوة وحدة وتبدأ رحلة التعلّم', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 22),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              const SizedBox(height: 14),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'البريد الإلكتروني أو رقم الهاتف')),
              const SizedBox(height: 14),
              TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                    : const Text('إنشاء الحساب'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

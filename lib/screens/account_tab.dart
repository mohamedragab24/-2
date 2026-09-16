import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/role_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  Future<void> _switchLearningRole(BuildContext context, String currentRole) async {
    final targetRole = currentRole == 'instructor' ? 'student' : 'instructor';
    final targetLabel = targetRole == 'instructor' ? 'مُفهّم' : 'مستفهم';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير نوع الحساب'),
        content: Text('هل تريد التبديل إلى $targetLabel؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await RoleService().switchLearningRole(targetRole);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم التبديل إلى $targetLabel بنجاح')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تغيير نوع الحساب حاليًا')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      child: StreamBuilder<UserProfile?>(
        stream: FirestoreService().watchUserProfile(user.uid),
        builder: (context, snap) {
          // Falls back to the Auth record while the Firestore profile doc
          // is still loading (or if it genuinely doesn't exist yet).
          final profile = snap.data;
          final name = profile?.name.isNotEmpty == true ? profile!.name : (user.displayName ?? 'طالب مسار');
          final email = profile?.email.isNotEmpty == true ? profile!.email : (user.email ?? '');
          final phone = profile?.phone ?? '';

          return ListView(
            children: [
              Container(
                color: AppColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.gold,
                      child: Text(name.isNotEmpty ? name[0] : 'م',
                          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 22)),
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: const TextStyle(color: AppColors.paper, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(email, style: const TextStyle(color: Color(0xFFA9BAC0), fontSize: 12.5)),
                    if (phone.isNotEmpty)
                      Text(phone, style: const TextStyle(color: Color(0xFFA9BAC0), fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('كورساتي المشتراة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {},
              ),
              if (profile?.role == 'admin') ...[
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.gold),
                  title: const Text('لوحة التحكم — الأدمن'),
                  subtitle: const Text('مراجعة واعتماد الكورسات'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/admin'),
                ),
                const Divider(height: 1),
              ],
              if (profile?.role == 'instructor' || profile?.role == 'student') ...[
                ListTile(
                  leading: Icon(
                    profile?.role == 'instructor' ? Icons.school_outlined : Icons.psychology_outlined,
                  ),
                  title: Text(
                    profile?.role == 'instructor' ? 'أنت الآن مُفهّم' : 'أنت الآن مستفهم',
                  ),
                  subtitle: Text(
                    profile?.role == 'instructor'
                        ? 'يمكنك التبديل إلى مستفهم'
                        : 'يمكنك التبديل إلى مُفهّم',
                  ),
                  trailing: const Icon(Icons.swap_horiz),
                  onTap: () => _switchLearningRole(context, profile!.role),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('الإعدادات'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('تغيير كلمة المرور'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.coral),
                title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.coral)),
                onTap: () async {
                  await AuthService().signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

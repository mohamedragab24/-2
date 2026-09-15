import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

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
                  title: const Text('لوحة الأدمن — مراجعة الكورسات'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/admin'),
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

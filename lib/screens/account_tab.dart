import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';
import 'instructor_dashboard_screen.dart';

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
          final profile = snap.data;
          final name = profile?.name.isNotEmpty == true
              ? profile!.name
              : (user.displayName?.isNotEmpty == true ? user.displayName! : 'طالب مسار');
          final email = profile?.email.isNotEmpty == true ? profile!.email : (user.email ?? '');
          final photoUrl = profile?.photoUrl ?? '';
          final isMofahhem = profile?.isMofahhem ?? false;

          return ListView(
            children: [
              Container(
                color: AppColors.ink,
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: AppColors.gold,
                      child: photoUrl.isEmpty
                          ? Text(name.isNotEmpty ? name[0] : 'م',
                              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 25))
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: const TextStyle(color: AppColors.paper, fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(email, style: const TextStyle(color: Color(0xFFA9BAC0), fontSize: 12.5)),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.paper,
                        side: const BorderSide(color: AppColors.paperDim),
                      ),
                      onPressed: profile == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile))),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('تعديل الملف الشخصي'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Text('نوع استخدام الحساب', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.school_outlined), label: Text('مستفهم')),
                    ButtonSegment(value: true, icon: Icon(Icons.co_present_outlined), label: Text('مُفهّم')),
                  ],
                  selected: {isMofahhem},
                  onSelectionChanged: (values) async {
                    final next = values.first;
                    try {
                      await FirestoreService().updateUserProfile(
                        uid: user.uid,
                        mode: next ? 'mofahhem' : 'mostafhem',
                      );
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تغيير نوع الحساب: $e')));
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: Text(
                  isMofahhem
                      ? 'وضع المُفهّم: يمكنك إنشاء كورسات وإرسالها للمراجعة.'
                      : 'وضع المستفهم: يمكنك تصفح الكورسات والتعلّم منها.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ),
              if (isMofahhem)
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('لوحة التحكم'),
                  subtitle: const Text('إنشاء ونشر كورساتك ومتابعة حالتها'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: profile == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstructorDashboardScreen(profile: profile))),
                ),
              if (profile?.role == 'admin')
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.gold),
                  title: const Text('لوحة الأدمن — مراجعة الكورسات'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/admin'),
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('كورساتي المشتراة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('تغيير كلمة المرور'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/change-password'),
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

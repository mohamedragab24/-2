class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final DateTime? joinedAt;
  final String role;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.joinedAt,
    this.role = 'student',
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      joinedAt: map['joinedAt']?.toDate(),
      role: (map['role'] ?? 'student').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
      };
}

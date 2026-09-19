class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  final DateTime? joinedAt;
  final String role;
  final String mode;
  final bool isAdmin;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl = '',
    this.joinedAt,
    this.role = 'student',
    this.mode = 'mostafhem',
    this.isAdmin = false,
  });

  bool get isMofahhem => mode == 'mofahhem';

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final rawMode = (map['mode'] ?? map['accountType'] ?? 'mostafhem').toString();
    return UserProfile(
      uid: uid,
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      photoUrl: (map['photoUrl'] ?? map['imageUrl'] ?? '').toString(),
      joinedAt: map['joinedAt']?.toDate(),
      role: (map['role'] ?? 'student').toString(),
      mode: rawMode == 'mofahhem' ? 'mofahhem' : 'mostafhem',
      isAdmin: map['isAdmin'] == true || (map['role'] ?? '').toString() == 'admin',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'mode': mode,
      };
}

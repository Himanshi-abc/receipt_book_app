class AppUser {
  final String id;
  final String? name;
  final String? phone;
  final String? email;
  final DateTime createdAt;

  AppUser({
    required this.id,
    this.name,
    this.phone,
    this.email,
    required this.createdAt,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      name: map['name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      createdAt: (map['createdAt'] is DateTime)
          ? map['createdAt'] as DateTime
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };
}

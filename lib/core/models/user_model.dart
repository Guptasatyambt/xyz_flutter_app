class UserModel {
  final String id;
  final String phone;
  final String? email;
  final String? fullName;
  final String gender;   // MALE | FEMALE | OTHER | UNSPECIFIED
  final String role;     // RIDER | DRIVER | ADMIN
  final String status;   // ACTIVE | SUSPENDED | DELETED
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.phone,
    this.email,
    this.fullName,
    required this.gender,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String?,
        fullName: j['fullName'] as String?,
        gender: j['gender'] as String? ?? 'UNSPECIFIED',
        role: j['role'] as String,
        status: j['status'] as String? ?? 'ACTIVE',
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        if (email != null) 'email': email,
        if (fullName != null) 'fullName': fullName,
        'gender': gender,
        'role': role,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return parts[0][0].toUpperCase();
    }
    return phone.isNotEmpty ? phone[phone.length - 1] : '?';
  }
}

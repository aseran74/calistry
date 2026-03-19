import 'dart:convert';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.role,
    this.username,
  });

  final String id;
  final String email;
  final String role;
  final String? username;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      username: json['username']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'username': username,
    };
  }
}

class AdminSession {
  const AdminSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AdminUser user;

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      user: AdminUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }

  String encode() => jsonEncode(toJson());

  static AdminSession decode(String raw) {
    return AdminSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
}

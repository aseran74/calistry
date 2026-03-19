String userDisplayNameFromJson(
  Map<String, dynamic>? user, {
  String fallback = 'Usuario',
}) {
  if (user == null) return fallback;

  final username = user['username']?.toString().trim() ?? '';
  final displayName = user['display_name']?.toString().trim() ?? '';
  final fullName = user['full_name']?.toString().trim() ?? '';
  final name = user['name']?.toString().trim() ?? '';
  final email = user['email']?.toString().trim() ?? '';

  if (username.isNotEmpty) return username;
  if (displayName.isNotEmpty) return displayName;
  if (fullName.isNotEmpty) return fullName;
  if (name.isNotEmpty) return name;
  if (email.isNotEmpty) {
    final localPart = email.split('@').first.trim();
    if (localPart.isNotEmpty) return localPart;
    return email;
  }
  return fallback;
}

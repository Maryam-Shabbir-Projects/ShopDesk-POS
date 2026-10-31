/// Roles are ready for multi-user. Today only [owner] is used.
enum UserRole {
  owner,
  manager,
  cashier;

  String get label => name[0].toUpperCase() + name.substring(1);
}

class AppUser {
  const AppUser({required this.id, required this.email, this.role = UserRole.owner});
  final String id;
  final String email;
  final UserRole role;

  bool get isOwner => role == UserRole.owner;
}

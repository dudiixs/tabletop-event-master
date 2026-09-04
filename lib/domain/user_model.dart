enum AuthProviderType {
  email('E-mail'),
  google('Google'),
  apple('Apple');

  const AuthProviderType(this.label);
  final String label;
}

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.authProvider,
    required this.favoriteTcgs,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final AuthProviderType authProvider;
  final Set<String> favoriteTcgs;
  final DateTime createdAt;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    AuthProviderType? authProvider,
    Set<String>? favoriteTcgs,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authProvider: authProvider ?? this.authProvider,
      favoriteTcgs: favoriteTcgs ?? this.favoriteTcgs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'authProvider': authProvider.name,
      'favoriteTcgs': favoriteTcgs.toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      authProvider: AuthProviderType.values.firstWhere(
        (e) => e.name == json['authProvider'],
        orElse: () => AuthProviderType.email,
      ),
      favoriteTcgs: (json['favoriteTcgs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {},
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

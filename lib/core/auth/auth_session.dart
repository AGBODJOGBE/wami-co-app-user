import 'package:equatable/equatable.dart';

/// Session du passager connecté, telle que renvoyée par `POST /api/passengers/login`.
/// Le jeton du back dure un an et n'a pas de renouvellement : quand il expire, on se reconnecte.
class AuthSession extends Equatable {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.passengerId,
    required this.walletId,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.email,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        userId: json['userId'] as String,
        passengerId: json['passengerId'] as String,
        walletId: json['walletId'] as String,
        phone: json['phone'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        email: json['email'] as String?,
      );

  final String token;
  final String userId;
  final String passengerId;
  final String walletId;
  final String phone;
  final String firstName;
  final String lastName;
  final String? email;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
        'token': token,
        'userId': userId,
        'passengerId': passengerId,
        'walletId': walletId,
        'phone': phone,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
      };

  @override
  List<Object?> get props => [token, userId, passengerId, walletId, phone, firstName, lastName, email];
}

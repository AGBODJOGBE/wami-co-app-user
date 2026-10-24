import 'package:equatable/equatable.dart';

/// Ce que le serveur sait d'un numéro une fois son code validé.
class PhoneCheck extends Equatable {
  const PhoneCheck({required this.hasPassengerAccount});

  /// `true` : un compte passager existe, on demande le mot de passe. `false` : on crée le compte.
  final bool hasPassengerAccount;

  @override
  List<Object?> get props => [hasPassengerAccount];
}

enum Gender { male, female }

class RegisterData extends Equatable {
  const RegisterData({
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.gender,
    this.email,
    this.referralCode,
  });

  final String phone;
  final String firstName;
  final String lastName;
  final String password;
  final Gender gender;
  final String? email;
  final String? referralCode;

  @override
  List<Object?> get props => [phone, firstName, lastName, password, gender, email, referralCode];
}

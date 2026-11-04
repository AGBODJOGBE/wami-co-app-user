import 'package:equatable/equatable.dart';

class SavedPlace extends Equatable {
  const SavedPlace({required this.label, required this.address});
  final String label;
  final String address;

  @override
  List<Object?> get props => [label, address];
}

enum Gender {
  female('FEMALE', 'Femme'),
  male('MALE', 'Homme');

  const Gender(this.api, this.label);
  final String api;
  final String label;

  static Gender? fromApi(String? s) => values.where((g) => g.api == s).firstOrNull;
}

/// Adresse de résidence du passager (ville et quartier obligatoires).
class PostalAddress extends Equatable {
  const PostalAddress({required this.city, required this.quarter, this.street, this.landmark});
  final String city;
  final String quarter;
  final String? street;
  final String? landmark;

  String get summary => [street, quarter, city].where((s) => s != null && s.trim().isNotEmpty).join(', ');

  @override
  List<Object?> get props => [city, quarter, street, landmark];
}

enum VerificationKind { email, phone }

class UserProfile extends Equatable {
  const UserProfile({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.tier,
    required this.rating,
    this.savedPlaces = const [],
    this.emergencyContact,
    this.gender,
    this.address,
    this.emailVerified = false,
    this.phoneVerified = true,
  });

  final String fullName;
  final String phone;
  final String email;

  /// Niveau de fidélité (règles à valider).
  final String tier;
  final double rating;
  final List<SavedPlace> savedPlaces;
  final String? emergencyContact;
  final Gender? gender;
  final PostalAddress? address;
  final bool emailVerified;
  final bool phoneVerified;

  UserProfile copyWith({String? fullName, String? phone, String? email}) => UserProfile(
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        tier: tier,
        rating: rating,
        savedPlaces: savedPlaces,
        emergencyContact: emergencyContact,
        gender: gender,
        address: address,
        emailVerified: emailVerified,
        phoneVerified: phoneVerified,
      );

  @override
  List<Object?> get props => [
        fullName,
        phone,
        email,
        tier,
        rating,
        savedPlaces,
        emergencyContact,
        gender,
        address,
        emailVerified,
        phoneVerified,
      ];
}

class FaqItem extends Equatable {
  const FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  List<Object?> get props => [question, answer];
}

import 'package:equatable/equatable.dart';

class SavedPlace extends Equatable {
  const SavedPlace({required this.label, required this.address});
  final String label;
  final String address;

  @override
  List<Object?> get props => [label, address];
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.tier,
    required this.rating,
    this.savedPlaces = const [],
    this.emergencyContact,
  });

  final String fullName;
  final String phone;
  final String email;

  /// Niveau de fidélité (règles à valider).
  final String tier;
  final double rating;
  final List<SavedPlace> savedPlaces;
  final String? emergencyContact;

  UserProfile copyWith({String? fullName, String? phone, String? email}) => UserProfile(
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        tier: tier,
        rating: rating,
        savedPlaces: savedPlaces,
        emergencyContact: emergencyContact,
      );

  @override
  List<Object?> get props => [fullName, phone, email, tier, rating, savedPlaces, emergencyContact];
}

class FaqItem extends Equatable {
  const FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  List<Object?> get props => [question, answer];
}

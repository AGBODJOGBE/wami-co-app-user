import 'package:equatable/equatable.dart';

enum AppThemeMode {
  dark('Sombre'),
  light('Clair'),
  system('Auto');

  const AppThemeMode(this.label);
  final String label;
}

enum AppLanguage {
  fr('Français'),
  fon('Fon'),
  yo('Yoruba'),
  en('English');

  const AppLanguage(this.label);
  final String label;
}

/// Préférences de l'utilisateur. Langues locales : traductions à valider.
class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.language = AppLanguage.fr,
    this.notifyTrips = true,
    this.notifyWallet = true,
    this.notifyPromos = false,
    this.autoShareTrip = true,
    this.biometrics = true,
    this.location = true,
    this.personalized = true,
    this.partnerSharing = false,
  });

  final AppThemeMode themeMode;
  final AppLanguage language;
  final bool notifyTrips;
  final bool notifyWallet;
  final bool notifyPromos;
  final bool autoShareTrip;
  final bool biometrics;
  final bool location;
  final bool personalized;
  final bool partnerSharing;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    bool? notifyTrips,
    bool? notifyWallet,
    bool? notifyPromos,
    bool? autoShareTrip,
    bool? biometrics,
    bool? location,
    bool? personalized,
    bool? partnerSharing,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      notifyTrips: notifyTrips ?? this.notifyTrips,
      notifyWallet: notifyWallet ?? this.notifyWallet,
      notifyPromos: notifyPromos ?? this.notifyPromos,
      autoShareTrip: autoShareTrip ?? this.autoShareTrip,
      biometrics: biometrics ?? this.biometrics,
      location: location ?? this.location,
      personalized: personalized ?? this.personalized,
      partnerSharing: partnerSharing ?? this.partnerSharing,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        language,
        notifyTrips,
        notifyWallet,
        notifyPromos,
        autoShareTrip,
        biometrics,
        location,
        personalized,
        partnerSharing,
      ];
}

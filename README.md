# WAMI — application mobile Flutter

Super app WAMI : **Mobilité** (moto, tricycle, standard, confort, VIP, van), **Livraison**,
**Billets de bus** et **Hébergement** (hôtel, chambre, appartement), avec **Portefeuille**,
**Activités** et **Compte**.

Le code reprend le prototype validé (direction futuriste) et le design system WAMI :
- les couleurs et la typographie viennent de `tokens.json` ;
- les illustrations 3D et les logos sont en SVG ;
- les polices Unbounded et DM Sans sont incluses.

---

## Démarrer

Prérequis : Flutter **3.27 ou plus** (Dart 3.6+).

```bash
# 1. Générer les dossiers natifs (android/, ios/…) sans toucher à lib/ ni test/
flutter create --org bj.wami --project-name wami --platforms android,ios .

# 2. Dépendances
flutter pub get

# 3. Lancer avec le faux backend (par défaut)
flutter run

# 4. Lancer sur une vraie API
flutter run --dart-define=WAMI_FAKE_BACKEND=false --dart-define=WAMI_API_URL=https://api.wami.bj

# Tests et analyse
flutter analyze
flutter test
```

> ⚠️ Ce code n'a pas pu être compilé là où il a été écrit : aucun SDK Flutter n'y était disponible.
> Il a été vérifié par analyse syntaxique et par contrôle des imports et des symboles.
> **Lancez `flutter analyze` en premier** : quelques ajustements mineurs restent possibles.

---

## Architecture : Clean Architecture par feature

```
lib/
├── main.dart                 Point d'entrée : config → injection → runApp
├── app.dart                  MaterialApp.router + blocs globaux (thème, profil, portefeuille)
├── app/                      Racine de composition (seule couche qui connaît tout)
│   ├── di/injection.dart     Enregistrements get_it, choix faux backend / API
│   └── router/               go_router : onglets + un ShellRoute par parcours
├── core/                     Transverse, ne dépend d'aucune feature
│   ├── config/               AppConfig (--dart-define)
│   ├── data/                 guard() exceptions → Failure, FakeBackend
│   ├── di/service_locator.dart
│   ├── domain/service_type.dart  Les 4 univers + illustrations 3D
│   ├── error/                Exceptions (data) et Failures (domain/UI)
│   ├── network/              ApiClient (Dio) + AuthInterceptor
│   ├── router/routes.dart    Constantes de chemins
│   ├── theme/                Tokens WAMI → ThemeData (sombre futuriste + clair)
│   ├── usecase/              Contrats UseCase / StreamUseCase
│   ├── utils/                Result<T>, LoadStatus, formatage F CFA / heures
│   └── widgets/              Composants du design system (boutons, verre, carte…)
└── features/
    ├── home/  mobility/  delivery/  bus/  lodging/  wallet/  account/  activities/
    │   ├── domain/           Entités, interfaces de repository, cas d'usage (Dart pur)
    │   ├── data/             Modèles JSON, sources (API + simulée), repository impl
    │   └── presentation/     Bloc/Cubit, pages, widgets
```

### Règles de dépendance

| Couche | Peut importer | Ne doit jamais importer |
|---|---|---|
| `domain` | `core/` (utils, error, usecase, domain) | Flutter UI, Dio, `data`, `presentation` |
| `data` | son `domain`, `core/` | `presentation`, une autre feature |
| `presentation` | son `domain`, `core/` | `data` (passe par les cas d'usage) |
| `app/` | tout | — |

- **Une feature n'importe jamais une autre feature.** Pour passer d'un service à l'autre, on navigue avec une route et un paramètre simple. Exemple : le billet de bus propose une course vers la gare.
- Les erreurs ne traversent pas les couches sous forme d'exceptions :
  1. la source de données lève une exception ;
  2. `guard()` la convertit en `Failure` ;
  3. le domaine renvoie un `Result<T>` (`Ok` / `Err`).
- Les règles métier sont testables sans Flutter. Elles vivent dans `domain` :
  - `WaitingPolicy` : facturation de l'attente et de la pause ;
  - `TripRanking` / `TripComparison` : tri et comparatif des bus ;
  - `TransferMoney` : contrôle du solde ;
  - `SearchLodgings` : classement selon les priorités de l'utilisateur.

### Gestion d'état (flutter_bloc)

- **Blocs globaux**, fournis dans `app.dart` :
  - `SettingsCubit` (thème) ;
  - `ProfileCubit` ;
  - `WalletBloc` (le solde sert à tous les paiements).
- **Bloc de parcours**, fourni par le `ShellRoute` du parcours et détruit à la sortie :
  - `RideBloc` ;
  - `DeliveryCubit` ;
  - `BusBookingCubit` ;
  - `LodgingCubit`.
- **Bloc d'écran** : `HomeCubit`, `ActivitiesCubit`, `SupportCubit`.
- Convention :
  - un **Bloc** (événements) quand il y a un flux temps réel ou des événements concurrents. C'est le cas de la course et du portefeuille.
  - un **Cubit** pour un formulaire en étapes.
  - L'état éphémère d'un seul écran (montant choisi, étoiles) reste dans un `StatefulWidget`.

### Brancher la vraie API

Chaque feature a une interface `XRemoteDataSource` avec deux implémentations :
- `XApiDataSource` : HTTP via `ApiClient` ;
- `XFakeDataSource` : données simulées.

`app/di/injection.dart` choisit l'une ou l'autre selon `WAMI_FAKE_BACKEND`. Pour brancher l'API :
1. Ajuster les chemins d'endpoint et les clés JSON dans `XApiDataSource`. Ils sont marqués *à valider*.
2. Lancer avec `WAMI_FAKE_BACKEND=false`.

Le suivi d'une course ou d'un colis se fait aujourd'hui par **polling**. Il est prévu de le remplacer par un WebSocket (Socket.io) dans `watchRide` / `track`, sans toucher au domaine ni à l'UI.

---

## Parcours implémentés

| Service | Étapes |
|---|---|
| Accueil | Carrousel publicitaire auto (pause au toucher), recherche, raccourcis, grille des 4 services |
| Mobilité | Destination → prix par véhicule → recherche chauffeur → chauffeur en route → **arrivé, attente gratuite puis facturée** → **course en cours, appel et message masqués** → **pause affichée et facturée** → note, pourboire et paiement |
| Livraison | Envoyer / faire récupérer → colis (taille, fragile, encaissement) → mode adapté à la taille, qui paie → suivi en 4 étapes avec code de remise |
| Bus | Recherche (inversion, date, voyageurs) → résultats triables avec « Meilleur choix » → comparatif de 2 à 3 départs → plan des sièges → billet QR et ventes croisées |
| Hébergement | Hôtel / chambre : résultats classés selon vos priorités → fiche et chambres → paiement → code. Appartement : fiche → créneaux de visite → demande envoyée |
| Portefeuille | Solde masquable, recharge (Mobile Money / carte), transfert avec contrôle du solde, historique |
| Compte | Profil, paramètres (thème appliqué en direct, notifications, langue), assistance (FAQ, urgence), confidentialité |

---

## À valider avant la mise en production

Ces éléments sont des emplacements dans le code, signalés par `[à valider]` ou par un commentaire.

**Règles et montants**
- Grille tarifaire mobilité et livraison.
- Durée d'attente gratuite et tarif par minute (`WaitingPolicy`).
- Facturation de la pause.
- Plafonds de recharge et de transfert.
- Frais de recharge, de transfert et de service.
- Opérateurs Mobile Money et agrégateur de paiement.
- Règles du programme de fidélité et du parrainage.

**Contenus**
- Compagnies, hôtels et prix (les données simulées sont des exemples).
- Textes juridiques : confidentialité, CGU, suppression de compte.
- Traductions fon et yoruba.

**Briques techniques à ajouter**
- Carte réelle : `google_maps_flutter` avec un style sombre, à la place de `RouteMapView`.
- Géolocalisation : `geolocator`.
- Vrai QR code : `qr_flutter`.
- Stockage des préférences et du jeton : `shared_preferences` et `flutter_secure_storage`.
- Notifications push : Firebase Cloud Messaging.
- Authentification par OTP SMS.
- Photo de colis et de profil : `image_picker`.
- Contacts.

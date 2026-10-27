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

Prérequis : Flutter **3.27 ou plus** (Dart 3.6+). Les dossiers `android/` et `ios/` sont déjà générés.

```bash
flutter pub get

# Faux backend (par défaut) : tout fonctionne sans serveur. Le code SMS est toujours 123456.
flutter run

# Back wami-co (https://github.com/AGBODJOGBE/wami-co)
flutter run --dart-define=WAMI_FAKE_BACKEND=false --dart-define=WAMI_API_URL=https://api.exemple.bj

flutter analyze
flutter test
```

Autre réglage : `--dart-define=WAMI_GEOCODER_URL=…` (service de recherche d'adresses, voir plus bas).

---

## Branchement sur le back wami-co

Avec `WAMI_FAKE_BACKEND=false`, ces modules parlent au vrai back. Tout le reste reste simulé.

| Module | Routes utilisées | Notes |
|---|---|---|
| Connexion | `POST /api/passengers/send-otp`, `verify-otp`, `register`, `login` | Numéro → code SMS → mot de passe ou inscription. Le jeton (1 an, sans renouvellement) est rangé dans le trousseau de l'appareil ; un 401 renvoie vers la connexion. |
| Portefeuille | `GET/POST /api/wallets/:walletId/{balance,transactions,recharge,transfer}`, `GET /api/payment/status/:id` | Recharge Mobile Money asynchrone suivie jusqu'à sa validation. Transfert par numéro de téléphone. |
| Compte | `GET /api/passengers/profile`, `PATCH /api/users/:id/{name,email,phone}` | Identité réelle ; niveau, lieux enregistrés et contact d'urgence restent côté app. |
| Activités | `GET /api/passenger/delivery` | Livraisons seulement : le back n'expose pas l'historique des courses. |
| Livraison | `POST /api/passenger/delivery/estimate`, `POST /api/passenger/delivery`, `GET /api/passenger/delivery/:id` | Véhicules proposés selon le colis (règle du back). Adresses géocodées, livraison programmée avec date et heure. Encaissement et « le destinataire paie » transmis mais ignorés par le back. |
| Mobilité | `POST /api/passenger/rides/estimate`, `POST /api/passenger/rides`, `GET/DELETE /api/passenger/rides/:id`, `POST …/rating` | Suivi par polling toutes les 3 s (résilient aux coupures). Paiement `MIXED` : portefeuille, puis espèces. |

**Encore simulés** (pas d'équivalent côté back, ou décision produit à prendre) : accueil, bus, hébergement, paramètres.

### Fonctions du mobile que le back ne gère pas

Règle du projet : **les fonctions prévues dans le mobile sont conservées** ; le back s'adapte ensuite.
Tout ce que le back doit corriger ou ajouter est dans [`docs/BACKEND_A_FAIRE.md`](docs/BACKEND_A_FAIRE.md)
(pourboire, code de sécurité, bénéficiaires, moyens de recharge, points, géocodage, livraison, bus, hébergement…).

À savoir en attendant :
- **Recherche d'adresses** : Nominatim (OpenStreetMap), limité au Bénin, usage léger seulement. Réglable par `WAMI_GEOCODER_URL`.
- **Paiement d'une course** : prélevé par le back à l'arrivée ; le pourboire est envoyé mais ignoré par le back.
- **Idempotence** : l'app ignore les doubles appuis, mais un retry réseau peut dupliquer un paiement.

### Tester contre un back local

```bash
WAMI_LIVE_API=http://localhost:3000 WAMI_LIVE_PHONE=+2290197123456 WAMI_LIVE_PASSWORD=Motdepasse1 flutter test
```

Les tests de `test/integration/` s'ignorent sans ces variables. Le compte doit exister (inscription par code SMS).
Sur une base neuve, le back demande d'abord ses tarifs et sa configuration de portefeuille (voir `docs/BACKEND_A_FAIRE.md`, points 1 et 2).

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

### Brancher une API

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

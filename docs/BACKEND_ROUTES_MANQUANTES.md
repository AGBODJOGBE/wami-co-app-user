# Routes et logique métier à ajouter au back (`wami-co`)

Document écrit **à partir des écrans de l'app mobile**. Il liste, par module, les routes qui n'existent pas dans le back et la
logique métier que chaque écran suppose. L'app garde ces fonctions (simulées pour l'instant) : dès qu'une route existe, il suffit de
brancher la source de données du module (fichier indiqué à chaque fois).

Conventions à respecter, comme le reste du back :
- réponses `{ success: true, data }` ou `{ success: false, error: { code, message } }` (message en français) ;
- listes dans `data.items` ;
- montants en **entiers de FCFA** (XOF), jamais de décimaux ;
- authentification par le JWT passager ; un seul appareil actif ;
- toute route qui débite un portefeuille accepte `Idempotency-Key`.

Priorités : **P1** bloque un écran déjà visible dans l'app · **P2** améliore l'écran · **P3** confort.

Les écarts de routes qui existent déjà (champ manquant, message en anglais…) sont dans `BACKEND_A_FAIRE.md`.

---

## 1. Accueil — `lib/features/home/data/datasources/home_remote_data_source.dart`

L'écran affiche : « Bonjour {prénom} », un carrousel de bannières, trois raccourcis de destination (Maison, Travail, dernière
destination) et la grille des services.

| Priorité | Route | Contenu |
|---|---|---|
| P1 | `GET /api/passengers/home` | `{ firstName, promos: [{ id, title, subtitle, ctaLabel, service, promoCode? }], quickDestinations: [{ id, label, address, lat, lng, kind }] }` |
| P2 | `GET/PUT /api/passengers/saved-places` | lieux enregistrés `{ kind: HOME\|WORK\|CUSTOM, label, address, lat, lng }` |
| P2 | `GET /api/passengers/rides/frequent-destinations?limit=3` | destinations les plus fréquentes ou les plus récentes |
| P2 | CRUD admin `/api/admin/banners` | gestion des bannières depuis le back-office |

Logique métier :
- `service` ∈ `MOBILITY | DELIVERY | BUS | LODGING` : ouvre le module correspondant. Si `promoCode` est présent, l'app le pré-applique à la première estimation.
- Une bannière a une période de validité (`startsAt`, `endsAt`), un ordre, une cible (tous, nouveaux clients, ville) et n'est renvoyée que si elle est active.
- Un **nouveau client** reçoit en tête la bannière de bienvenue liée à un vrai code promo (`GET /api/passenger/promo-codes`).
- `quickDestinations` : « Maison » et « Travail » viennent des lieux enregistrés (absents tant que le passager ne les a pas définis) ;
  les `recent` sont les destinations des courses terminées, sans doublon, 3 au maximum, la plus récente d'abord.
- Les adresses renvoyées portent toujours des coordonnées : le raccourci lance directement l'estimation.

## 2. Bus — `lib/features/bus/data/datasources/bus_data_sources.dart`

Parcours : recherche (départ, arrivée, date, voyageurs) → liste des départs (tri, comparatif de 2 à 3 départs) → plan des sièges →
paiement → billet avec QR code.

| Priorité | Route | Contenu |
|---|---|---|
| P1 | `GET /api/bus/trips?from&to&date&passengers` | départs : `{ id, company, departure "HH:mm", arrival "HH:mm", durationMinutes, price, rating, comfort, seatsLeft, station }` |
| P1 | `GET /api/bus/trips/:id/seats?date` | plan : `{ rows: [[{ code, taken } \| null]] }` (`null` = allée, 4 sièges par rangée : A B · C D) |
| P1 | `POST /api/bus/bookings` | `{ tripId, date, seats[] }` → `{ reference, total, qr, status }` |
| P1 | `GET /api/bus/bookings` et `GET /api/bus/bookings/:id` | mes billets (le billet se rouvre depuis l'historique) |
| P2 | `POST /api/bus/trips/:id/seat-holds` | réserve les sièges choisis 10 minutes → `{ holdId, expiresAt }` |
| P2 | `DELETE /api/bus/bookings/:id` | annulation avec remboursement selon la politique de la compagnie |
| P2 | `GET /api/bus/cities` | villes desservies (liste de choix pour départ et arrivée) |
| P3 | `POST /api/partner/bus/tickets/validate` | la compagnie scanne le QR à l'embarquement |

Logique métier :
- `comfort` ∈ `STANDARD | AIR_CONDITIONED | VIP`. `price` est le prix **par siège**, en FCFA entiers. `rating` est la note moyenne de la compagnie (0–5).
- Ne renvoyer que les départs de la date demandée, à venir, avec `seatsLeft >= passengers`. Le billet demande d'être à la gare 30 min avant :
  ne pas proposer un départ qui part dans moins de 30 minutes.
- Le classement « Recommandé », le tri et le comparatif sont calculés **dans l'app** à partir de ces champs : le back n'a rien à faire de plus.
- Réservation : le nombre de sièges doit être égal au nombre de voyageurs ; refuser (`409 SEAT_TAKEN`) si un siège est déjà vendu ; `total = price × nombre de sièges` ;
  débit du portefeuille du passager (l'écran propose « Payer · montant » sans autre choix), crédit de la compagnie au portefeuille `PARTNER`
  moins la commission de Wami ; solde insuffisant → `400 INSUFFICIENT_FUNDS`.
- `reference` lisible (ex. `WB-7K2P9Q`), `qr` = contenu à encoder (référence + sièges + signature) vérifiable hors ligne par la compagnie.
- Entre le choix des sièges et le paiement, les sièges sont retenus (`seat-holds`) pour qu'un autre client ne les achète pas ; fin de la retenue = sièges libérés.
- Annulation : délai et remboursement définis par la compagnie (`[à valider]`) ; remboursement vers le portefeuille du passager.
- Une compagnie (profil `PARTNER`) gère ses lignes, ses horaires, ses bus (plan de sièges) et ses prix depuis le back-office.

## 3. Hébergement — `lib/features/lodging/data/datasources/lodging_data_sources.dart`

Trois types : hôtel et chambre (à la nuit, réservation immédiate), appartement (au mois, avec visite préalable).

| Priorité | Route | Contenu |
|---|---|---|
| P1 | `GET /api/stays?type&city&guests&nights&checkIn&amenities` | `{ id, type, name, area, rating, price, amenities[], verified }` |
| P1 | `GET /api/stays/:id/rooms` | `{ id, name, description, pricePerNight }` |
| P1 | `POST /api/stays/:id/bookings` | `{ roomId, checkIn, nights, guests, payment }` → `{ reference, total, status }` |
| P1 | `GET /api/stays/:id/visit-slots` | `{ id, day, time, available }` (appartements) |
| P1 | `POST /api/stays/:id/visits` | `{ slotId }` → demande de visite |
| P2 | `GET /api/stays/bookings`, `DELETE /api/stays/bookings/:id` | mes réservations, annulation |
| P2 | `GET/PUT/DELETE /api/passengers/favorites/stays/:id` | favoris (le cœur de l'écran, aujourd'hui local) |
| P2 | `GET /api/stays/:id` | fiche : photos, description, adresse, coordonnées, règles |

Logique métier :
- `type` ∈ `HOTEL | ROOM | APARTMENT`. `price` = par nuit (hôtel, chambre) ou **par mois** (appartement) ; l'app affiche « / nuit » ou « / mois » selon le type.
- `amenities` ∈ `AIR_CONDITIONING, WIFI, GENERATOR, SECURITY, PARKING, FURNISHED, RUNNING_WATER`. Le filtre `amenities` est une **préférence** :
  ne pas exclure les logements qui n'ont pas tout, mais les classer (plus d'équipements voulus d'abord).
- `verified` : établissement visité et validé par Wami (badge « Vérifié par WAMI »).
- ⚠️ L'écran actuel ne demande **pas de date d'arrivée** (seulement le nombre de nuits). Le back doit exiger `checkIn` ; l'app l'ajoutera au formulaire dès que la route existe.
- Réservation : `total = pricePerNight × nights + frais de service` (frais `[à valider]`) ; vérifier la disponibilité de la chambre sur toute la période (`409 NOT_AVAILABLE`).
  `payment` ∈ `WALLET` (débit immédiat), `MOBILE_MONEY` (via FedaPay, réservation confirmée au paiement), `ON_SITE` (aucun débit, confirmée par l'établissement).
- Annulation gratuite jusqu'à un délai avant l'arrivée (`[à valider]`), remboursée sur le portefeuille.
- Appartement : pas de réservation directe. Le passager demande une visite sur un créneau `available` ; le propriétaire confirme ou refuse ;
  le passager est notifié (« Vous recevrez une notification »). Un créneau pris devient `available: false`.
  Caution et avance (`[conditions à valider avec le propriétaire]`) : à publier dans la fiche.
- Le code de réservation (`reference`) est présenté à la réception : court, lisible, unique.
- Un établissement (profil `PARTNER`) gère ses chambres, ses prix, ses disponibilités et les visites depuis le back-office.

## 4. Paramètres du compte — `lib/features/account/data/datasources/account_data_sources.dart` (`InMemorySettingsDataSource`)

Aujourd'hui les réglages ne sont gardés qu'en mémoire : ils sont perdus à la fermeture de l'app.

| Priorité | Route | Contenu |
|---|---|---|
| P1 | `GET/PUT /api/passengers/settings` | `{ language, notifyTrips, notifyWallet, notifyPromos, autoShareTrip, partnerSharing, personalized }` |

Logique métier :
- `language` ∈ `fr | …` (langues locales : `[à valider]`) : le back s'en sert pour les push, SMS et e-mails.
- `notifyTrips`, `notifyWallet`, `notifyPromos` : le module notifications **n'envoie pas** les push du type refusé (courses/livraisons, portefeuille, offres).
  Valeurs par défaut : `true`, `true`, `false` (consentement explicite pour les offres).
- `partnerSharing` (défaut `false`) : sans consentement, aucune donnée du passager n'est transmise aux compagnies de bus ni aux hôtels ; seul le nom du billet l'est.
- `personalized` : active les destinations et offres adaptées (voir « Accueil »).
- `autoShareTrip` : avec un contact d'urgence enregistré, partage automatique du lien de suivi à chaque course (voir « Course »).
- `themeMode`, `biometrics` et `location` restent **sur le téléphone** : pas de route.

## 5. Course — fonctions affichées « bientôt disponible » (`ride_tracking_page.dart`)

| Priorité | Route | Contenu |
|---|---|---|
| P1 | `POST /api/passenger/rides/:id/sos` | `{ lat, lng }` → alerte au contact d'urgence et à l'exploitation |
| P1 | `POST /api/passenger/rides/:id/share` | → `{ url, expiresAt }` lien public de suivi |
| P1 | `GET /api/public/rides/share/:token` | lecture seule : position du chauffeur, véhicule, plaque, statut, arrivée |
| P2 | `POST /api/passenger/rides/:id/call` | numéro relais anonymisé → `{ phone, expiresAt }` |
| P2 | `GET/POST /api/passenger/rides/:id/messages` + événement `ride:message` | messagerie passager ↔ chauffeur |
| P2 | `GET/PUT /api/passengers/emergency-contact` | `{ name, phone }` (aussi dans le profil, voir `BACKEND_A_FAIRE.md`) |

Logique métier (règles déjà validées dans l'app) :
- **Appel et message** : possibles seulement quand la course est `DRIVER_ASSIGNED` ou `DRIVER_ARRIVED`. Refusés (`409`) une fois la course démarrée et après la fin.
- **Partage du trajet et urgence** : disponibles de `DRIVER_ASSIGNED` jusqu'à la fin de la course.
- Le lien de partage expire à la fin de la course (+1 h) et ne montre ni numéro de téléphone ni données du passager.
- SOS : horodaté, journalisé, notifie le contact d'urgence (SMS avec le lien de suivi) et l'équipe d'exploitation ; l'app n'appelle jamais les secours à la place de l'utilisateur.
- La messagerie est conservée avec la course (litiges) et chiffrée au repos ; le message arrive par WebSocket dans la salle `ride:{id}` et par push si l'app est fermée.

## 6. Autres routes déjà listées

Les tâches ci-dessous sont déjà détaillées dans `BACKEND_A_FAIRE.md` (section « Fonctions du mobile que le back ne gère pas ») :
pourboire, code de sécurité de la course, bénéficiaires et moyens de recharge du portefeuille, points de fidélité, niveau et note du passager,
export des données, FAQ, tarifs d'attente, délai d'arrivée du chauffeur, suivi de livraison en temps réel, recherche d'adresses,
encaissement à la livraison, « le destinataire paie », code de remise.

## Ordre conseillé pour le back

1. **Paramètres** (`/settings`) et **accueil** (`/home`, bannières) : petits, visibles dès l'ouverture de l'app.
2. **Course** : SOS, partage, puis appel et messagerie.
3. **Bus**, puis **hébergement** : nouveaux modules complets (partenaires, back-office, paiements, remboursements).

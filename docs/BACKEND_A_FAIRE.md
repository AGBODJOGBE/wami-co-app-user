# Ce que le back `wami-co` doit corriger ou ajouter

Document tenu à jour au fil du branchement de l'app. Principe : **les fonctions prévues dans le mobile sont conservées**.
Quand le back ne les gère pas, l'app les garde (simulées ou masquées proprement) et la demande est notée ici.

Légende : 🔴 empêche l'app de fonctionner · 🟠 fonction du mobile sans équivalent côté back · 🟡 amélioration

---

## 🔴 À corriger avant la mise en ligne

### 1. Les tarifs de course ne sont pas initialisés au démarrage
- **Constat** : `POST /api/passenger/rides/estimate` répond `500 "[PricingService] No active pricing config for vehicleType=MOTO"`
  sur une base neuve (`ride_pricing_configs` vide), et `POST /api/passenger/rides` répond `400` avec le même message.
  Un `500` empêche l'app de masquer le seul véhicule sans tarif : c'est toute l'estimation qui échoue.
- **Cause** : `PricingService` lit la collection `ride_pricing_configs` (taux, part chauffeur, attente). Son seed
  (`src/modules/ride/infrastructure/persistence/mongodb/seeds/seedRidePricingConfigs.ts`) n'est appelé nulle part ; seul
  `seedPricingProfiles` est lancé au démarrage (`pricing_profiles`, qui contient bien les 16 profils actifs).
- **À faire** : lancer ce seed au démarrage comme les autres, ou documenter la commande de déploiement. Le message d'erreur devrait aussi nommer la collection manquante.

### 2. La configuration du portefeuille n'est pas créée par défaut
- **Constat** : `POST /api/wallets/:id/transfer` répond `500` (« Service de portefeuille temporairement indisponible »).
- **Cause** : `walletConfigRepository.getConfig()` renvoie `null` tant qu'un admin n'a pas enregistré la configuration.
- **À faire** : créer `WalletConfig.createDefault('system')` au démarrage si absente, comme `GetWalletConfigUseCase` le fait en lecture. Et répondre `503` plutôt que `500`.

### 3. Deux routes de recharge, une seule utilisable
- `POST /api/wallets/:walletId/recharge` répond `202 { status: "PENDING", hint: "Poll GET /api/payment/status/:paymentIntentId" }` **sans `paymentIntentId`** : impossible de suivre le paiement.
- `POST /api/payment/recharge` répond `202 { paymentIntentId, status: "PROCESSING" }` (ou `502 { status: "FAILED" }`). L'app utilise celle-ci.
- **À faire** : supprimer la première ou lui faire renvoyer `paymentIntentId`.

### 4. `cross-env` n'est pas déclaré
- `npm run dev` et `npm run dev:worker` appellent `cross-env`, absent de `package.json` : `sh: cross-env: not found` après `npm ci`.
- **À faire** : `npm i -D cross-env`.

### 5. L'historique des courses plante sur les anciens numéros de course
- **Constat** : `GET /api/passengers/rides` (au pluriel) répond `500 "Invalid ride number format: FY-RD-…"` dès qu'une course
  porte un ancien numéro `FY-RD-…`. Le renommage ForYou → Wami n'accepte plus que `WM-RD-…`. Avec un filtre
  (`?status=COMPLETED`), la route répond 200 : seules les courses non converties posent problème.
- **À faire** : convertir les numéros existants (`FY-` → `WM-`, y compris les livraisons `FY-B2C-`) ou accepter les deux préfixes
  à la lecture. Sans vraies données, rien à faire.
- **Autre écart** : le Swagger documente `page` et `limit`, mais le contrôleur ne lit que `status` et renvoie tout l'historique.
  L'app n'a pas de pagination pour l'instant.

### 6. Changement de numéro de téléphone sans vérification
- `PATCH /api/users/:id/phone { newPhoneNumber }` modifie le numéro de connexion sans code SMS sur le nouveau numéro.
  Quiconque détient un jeton peut rediriger le compte. L'écran Profil de l'app appelle cette route.
- **À faire** : exiger un code OTP envoyé au nouveau numéro (`send-otp` puis `verify-otp` avant le changement).

### 7. La suppression du compte plante après avoir supprimé le profil
- **Constat** : `DELETE /api/passengers/profile { password }` avec le bon mot de passe répond `500`, mais le profil est bien supprimé
  (ensuite `GET /api/passengers/profile` répond 404 et la connexion échoue avec « Passenger profile not found not found »).
- **Cause** : `passenger.routes.ts:219` appelle `user.deactivatePassengerProfile()`, méthode qui n'existe pas dans `User`
  (il n'y a que `activatePassengerProfile`). L'indicateur `hasPassengerProfile` de l'utilisateur reste donc à `true`.
- **À faire** : ajouter `deactivatePassengerProfile()` à `User` (et la traiter de façon atomique avec la suppression du profil).
  Corriger aussi la faute dans le message : « not found not found ».
- **Côté app** : en cas de 500, l'app vérifie si le profil existe encore et, s'il a disparu, déconnecte l'utilisateur.
### 8. La liste des codes promo disponibles expose des données internes
- **Constat** : `GET /api/passenger/promo-codes` renvoie `PromoCode.toObject()` en entier au passager, dont `realCostAccrued`,
  `marginResidualPct`, `commissionBase`, `budgetedLossCampaign`, `sponsoredBudget`, `dailySpendingLimit`, `affiliateId`,
  `affiliateCommissionRate` et **`targetUserIds`** (identifiants d'autres utilisateurs ciblés par un code).
- **À faire** : renvoyer un objet public : `id`, `code`, `displayText`, `endDate`, `discountType`, `discountValue`, `minOrderAmount`.
  L'app n'utilise que `code` et `displayText`.

### 9. Les notifications d'un utilisateur sont lisibles par tous les autres
- **Constat** : `GET /api/notifications?recipientId=<id d'un autre>` rend les notifications de cet autre utilisateur, avec n'importe quel jeton
  valide (`const recipientId = req.query.recipientId || req.userId` dans `GetNotificationHistoryController`). Testé en réel.
- **À faire** : ignorer `recipientId` pour les non-administrateurs et lire uniquement `req.userId`. Réserver l'usage de `recipientId` à une
  route d'administration.
- **Côté app** : elle n'envoie jamais `recipientId`.

### 10. Les positions exactes des chauffeurs sont publiques
- **Constat** : `GET /api/passengers/rides/nearby-drivers?latitude=&longitude=&vehicleType=` n'exige aucun jeton (« Route PUBLIQUE — comportement
  historique conservé » dans le code) et renvoie le `driverId`, la position exacte (`latitude`, `longitude`), la note et la distance de
  chaque chauffeur disponible. N'importe qui peut donc suivre les chauffeurs d'une ville sans compte.
- **À faire** : exiger l'authentification, ne pas renvoyer `driverId`, arrondir les positions (ou ne renvoyer que distance et délai d'arrivée).
  L'app n'utilise que le nombre de chauffeurs et le plus petit `estimatedArrivalMin`.

---

## 🔴 Trajets interurbains (`/api/passenger/offers`, `/api/passenger/bookings`)

Vérifié sur le back local (une offre insérée en base, réservations réelles). L'app a un parcours « Interurbain » complet (recherche, détail, réservation,
annulation) ; ces points l'empêchent de fonctionner en production ou exposent des données.

1. **BLOQUANT : `GET /api/passenger/offers` ne renvoie pas l'identifiant de l'offre.** La réponse est `DriverOffer.toObject()`, qui contient `offerNumber`
   mais pas `id` ; or `POST /offers/:offerId/book` cherche par `id` (réservation par `offerNumber` → `Offer not found.`). Le passager ne peut donc pas réserver.
   Ajouter `id` à la réponse. L'app le lit déjà (`id` ou `offerId`) et désactive « Réserver » tant qu'il manque.
2. **Données internes exposées au passager** : `driverId`, `vehicleId`, `platformShareRate`, `driverShareRate`, `totalRevenue`, `driverEarnings`,
   `platformCommission`, `confirmedBookingCount`. Renvoyer un DTO passager (id, numéro, véhicule, villes, adresses, horaires, places, prix par place, étapes, description).
3. **Le passager ne sait pas avec qui il voyage** : ni prénom du chauffeur, ni note, ni photo, ni véhicule (marque, modèle, couleur, plaque). À ajouter dans le DTO ;
   l'app affichera ces champs dès qu'ils existent.
4. **Paiement `WALLET` non contrôlé** : une réservation de 8 000 FCFA avec un portefeuille à 0 est acceptée (`CONFIRMED`), le solde ne bouge pas, et l'annulation
   répond `refundAmount: 8000` alors que rien n'a été débité. Constaté avec le worker d'événements arrêté (le gel du montant passe par l'événement `OfferSeatBooked`) :
   vérifier le solde et geler le montant **avant** de confirmer, ou ne confirmer qu'après le gel ; ne rembourser que ce qui a été débité.
5. **Pas de liste « mes réservations »** ni de détail : `GET /api/passenger/bookings` et `GET /api/passenger/bookings/:id` (avec offre, chauffeur, statut).
   Sans eux, l'app ne peut annuler que la réservation faite pendant la session, et ne l'affiche pas dans l'onglet Activités.
   `GET /api/passenger/offers/:id` manque aussi (détail d'une offre).
6. **Villes** : le filtre compare `originCity` / `destinationCity` tel quel (sensible à la casse et aux accents). Fournir `GET /api/cities` (liste officielle) et
   normaliser la comparaison. L'app propose une liste fixe de villes en attendant.
7. **Date de recherche** : `setHours(0,0,0,0)` utilise le fuseau du serveur ; fixer `Africa/Porto-Novo` pour que « demain » soit le même partout.
8. **Messages d'erreur en anglais** (`Offer not found.`, `Only 4 seat(s) available, requested 9`, `You already have an active booking on this offer.`,
   `Cannot cancel a booking in status …`) : l'app les traduit en cherchant des mots ; préférer des codes stables (`OFFER_NOT_FOUND`, `NOT_ENOUGH_SEATS`, `ALREADY_BOOKED`, `CANNOT_CANCEL`).
9. **Point de montée / descente** : la route accepte `pickupLat/Lng/Address` et `dropoffLat/Lng/Address` ; l'app n'envoie pas encore de point personnalisé
   (elle utilise ceux de l'offre). Dire si la contrainte est de rester proche du trajet du chauffeur.
10. **Trajets quotidiens (`/api/passenger/daily-routes/:id/pause|resume`)** : le passager peut mettre en pause ou reprendre, mais aucune route ne liste ses trajets
    quotidiens ni n'en crée côté passager (la création est réservée au chauffeur). L'app n'a donc pas d'écran pour eux.

---

## 🟡 Retrait des gains d'affilié (`POST /api/wallets/:id/withdraw`)

Vérifié sur le back local (gains d'affilié mis à 20 000 en base, vraie demande de retrait, puis nettoyage).

1. **Swagger faux** : il dit « uniquement EARNINGS et PARTNER, 403 pour PAYMENT ». En réalité un wallet passager peut retirer, mais seulement son sous-solde `AFFILIATE`
   (message `Insufficient AFFILIATE balance…`). Corriger la documentation ; l'app ne propose le retrait que s'il y a des gains d'affilié.
2. **Messages en anglais** (`Minimum withdrawal for MOBILE_MONEY is 1000 FCFA — requested: 200 FCFA`, `Insufficient AFFILIATE balance…`,
   `A withdrawal is already in progress for this wallet`) : l'app les traduit ; prévoir des codes stables.
3. **Minimums** : l'app affiche 1 000 F (Mobile Money) et 5 000 F (virement), les valeurs par défaut du back. Ils sont modifiables par l'administration :
   exposer `GET /api/wallets/config` (ou l'inclure dans `GET /balance`) pour que l'app affiche les vrais.
4. **Suivi du retrait** : pas de `GET /api/wallets/:id/withdrawals` (statut `PENDING` → `COMPLETED` / `REJECTED`, motif). L'app ne peut pas dire au passager où en est sa demande ;
   elle ne sait que lire le solde réservé. Un retrait en cours bloque les suivants (`409`), sans moyen de l'annuler côté passager.
5. **Notification** de fin de retrait (virement fait ou refusé) à envoyer par le module notifications.

---

## 🟡 Profil : e-mail, civilité, adresse, vérification (`/api/users/:id/*`)

Vérifié sur le back local.

1. **`GET /api/passengers/profile` et `GET /api/users/:id` ne renvoient ni l'`email` ni l'`address`**, alors qu'ils sont bien enregistrés en base (constaté après `add-email`
   et `address`). L'écran « Mon profil » ne peut donc pas les afficher à la réouverture ; l'app garde ce qu'elle vient de saisir pendant la session seulement.
   Ajouter `email` et `address` (`city`, `quarter`, `street`, `landmark`) aux deux réponses. Corrige aussi l'e-mail vide dans le profil.
2. **`add-email` et `PATCH /email` font doublon** : `add-email` répond `409 User already has an email. Use updateEmail to change it.` quand un e-mail existe. Comme le profil ne
   renvoie pas l'e-mail (point 1), l'app tente `add-email` puis `PATCH`. Une seule route (`PUT /api/users/:id/email`) suffirait.
3. **`resend-verification` renvoie toujours les deux codes (SMS et e-mail)**, même si le téléphone est déjà vérifié. Prévoir `?channel=email|phone`. Le code source lit
   `user.address!` et `user.gender!` : à vérifier qu'il ne plante pas (500) pour un compte sans adresse ou sans civilité, ce que je n'ai pas pu reproduire.
4. **Codes de vérification illisibles en développement** (`SMS_PROVIDER=mock`) : aucune trace du code dans les logs ni en base, donc impossible de tester une vérification réussie
   sans accès aux messages. Journaliser le code en `NODE_ENV=development`.
5. **Messages d'erreur en anglais ou mélangés** (`Valid gender (MALE or FEMALE) is required`, `Address with city and quarter is required`, `User already has an email…`) :
   l'app valide avant l'appel et traduit le refus de code ; préférer des codes stables.
6. **Changement de téléphone** (`PATCH /phone`) : dire s'il remet `isPhoneVerified` à `false` et envoie un code ; l'app affiche « Téléphone non vérifié » dès que le profil le dit.

---

## 🟠 Fonctions du mobile que le back ne gère pas

> Les modules entiers qui n'ont aucune route (accueil, bus, hébergement, paramètres, SOS/partage/messagerie de course) sont spécifiés
> écran par écran dans [`BACKEND_ROUTES_MANQUANTES.md`](BACKEND_ROUTES_MANQUANTES.md).

L'app les conserve. Quand le back les proposera, il suffira de brancher la source de données.

| Fonction du mobile | Aujourd'hui côté back | Demande |
|---|---|---|
| **Pourboire** en fin de course | rien | `POST /api/passenger/rides/:id/rating` accepte `tip` (entier FCFA ≥ 0) et le débite du portefeuille vers le chauffeur. L'app envoie déjà `tip` s'il est > 0. |
| **Code de sécurité** de la course (à donner au chauffeur) | rien | `GET /rides/:id` renvoie `securityCode` (4 chiffres) tant que la course n'a pas démarré ; le chauffeur le saisit pour démarrer. L'app l'affiche dès que le champ est présent. |
| **Bénéficiaires** du portefeuille | rien | `GET/POST/DELETE /api/wallets/:id/beneficiaries` → `{ id, name, phone }`. Liste vide en réel : le destinataire se saisit par son numéro. |
| **Moyens de recharge enregistrés** (Mobile Money, cartes) | rien | `GET /api/wallets/:id/top-up-sources` → `{ id, kind: MOBILE_MONEY\|CARD, label, masked, phone? }`. En réel, l'app propose le numéro du compte ; les cartes restent simulées. |
| **Points de fidélité** (`wallet.points`) | rien | champ `points` dans `GET /wallets/:id/balance`. Affiché à 0 en réel. |
| **Niveau de fidélité, note passager, lieux enregistrés, contact d'urgence** (compte) | rien | `GET/PUT /api/passengers/profile` étendu (`tier`, `rating`, `savedPlaces[]`, `emergencyContact`). Nom, e-mail et téléphone sont réels ; niveau et note sont masqués, lieux et contact d'urgence gardés en mémoire de l'app (perdus au redémarrage). |
| **Export des données personnelles** | rien | `POST /api/passengers/data-export`. Le bouton de l'app n'a pas d'effet réel. |
| **FAQ du support** | rien | `GET /api/support/faq`. Contenu écrit dans l'app. |
| **Tarif d'attente et franchise** affichés avant et pendant la course | `waitingFeePerMinute` en base, non exposé | exposer `waitingFeePerMinute`, `freeWaitingMinutes`, `pauseFreeMinutes`, `pauseFeePerMinute` dans `GET /rides/:id` (et dans l'estimation). L'app déduit le tarif de ce qui a déjà été facturé. |
| **Délai d'arrivée du chauffeur** (« Chauffeur à 4 min ») | absent de `GET /rides/:id` ; présent une seule fois dans l'événement WebSocket `ride:driver_en_route` (`etaToPickupSeconds`) | `driverEtaMinutes` et la position `driverLocation` dans `GET /rides/:id`, pour qu'un écran rouvert ou reconnecté les retrouve. L'écran affiche « Chauffeur en route ». |
| **Livraison en temps réel** | le WebSocket n'envoie au passager que `b2c:driver:location` (salle `order:{id}`) | émettre aussi les changements de statut de la commande (coursier trouvé, colis récupéré, livré, annulé) dans `order:{id}`. L'app les écoutera comme pour la course ; en attendant elle interroge le suivi toutes les 3 s. |
| **Recherche d'adresses** | aucun géocodage | `GET /api/places/search?q=` → `[{ id, name, address, lat, lng }]` limité au Bénin. L'app utilise Nominatim public (usage léger seulement). |
| **Livraison** : encaissement à la livraison | rien (`B2cPaymentMethod` = CASH \| WALLET) | `codAmount` à la commande, encaissé par le coursier et reversé. |
| **Livraison** : « le destinataire paie » | rien | `payer: SENDER \| RECIPIENT`. |
| **Livraison** : code de remise visible par l'expéditeur | OTP vérifié par le coursier, non exposé | `handoverCode` dans le suivi, envoyé au destinataire. |
| **Livraison** : véhicules proposés | `B2cVehiclePolicy` : un grand colis ne peut partir qu'en `VAN`, un colis moyen en `STANDARD`/`CONFORT`/`VAN` | L'app propose maintenant ce que le back autorise (moto, tricycle, voiture, van). La règle « grand colis en tricycle » du mobile n'est plus appliquée : à confirmer côté produit. |
| **Livraison** : adresse choisie dans une liste | pas de géocodage | l'app géocode le texte saisi et prend le premier résultat (risque d'erreur). Il faut `GET /api/places/search` et un choix d'adresse dans l'écran. |
| **Livraison** : annulation depuis le suivi | `DELETE /api/passenger/delivery/:id` existe | pas de bouton « annuler » dans l'écran de suivi de l'app : à ajouter côté mobile. |
| **Accueil** : bannières promotionnelles | codes promo existent, pas de flux d'accueil | `GET /api/passenger/home` → `{ promos[] }`. |
| **Activités** : historique unifié (courses, livraisons, bus, hébergement) | historiques séparés par module | `GET /api/passenger/activities` paginé, ou l'app agrège elle-même. |
| **Notifications** : nombre de non lues, « tout marquer comme lu » | `GET /api/notifications` ne donne pas de compteur ; pas de route pour tout marquer | `unreadCount` dans la réponse, `POST /api/notifications/read-all`. La cloche compte seulement les non lues déjà chargées (première page). |
| **Notifications** : une seule ligne par événement | une notification par canal (SMS, push, temps réel) pour le même événement | `GET /api/notifications?channel=PUSH`, ou une notification « boîte de réception » distincte. L'app regroupe côté mobile (même type, même objet lié, à moins d'une minute). |
| **Notifications push** (jeton FCM) | `PATCH /api/passengers/fcm-token` fonctionne (testé) | côté mobile, il manque Firebase (`google-services.json`, `GoogleService-Info.plist`) : à fournir pour recevoir les notifications hors de l'app. |
| **Paramètres** (langue fr/fon/yoruba, notifications) | rien | `GET/PUT /api/passengers/settings`. Stockés sur l'appareil pour l'instant (non persistés après redémarrage). |
| **Messagerie, appel, partage de trajet, urgence** | rien (« bientôt » dans l'app) | à définir. |
| **Bus** : recherche, sièges, billets QR | aucun module | module complet. |
| **Hébergement** : hôtels, chambres, appartements, visites | aucun module | module complet. |

---

## 🟡 Améliorations

- **Mise à jour obligatoire, identifiants incohérents** : l'app s'identifie par `appType=PASSENGER` + `platform` (route `check-version`).
  Les configurations de version ne portent pas les mêmes identifiants de paquet partout : `com.wamico.client` dans le seed, `com.foryou.client`
  (et des liens `foryou-passenger`) dans une base créée avant le renommage — le seed ne remplace pas l'existant — et `bj.wami.wami` dans l'app.
  Résultat : `GET /api/app/version?package=bj.wami.wami` répond 404. À aligner avant la mise en ligne (migration des configurations, vrais liens
  Play Store / App Store).
- **Mise à jour obligatoire, version de départ** : le seed fixe `minSupportedVersion` à `1.0.0`. Une version de développement (`0.1.0`) est donc
  refusée : l'app se bloque sur l'écran de mise à jour. Pour développer contre un back réel : `--dart-define=WAMI_CHECK_VERSION=false`,
  ou publier la version 1.0.0 côté app.

- **Mot de passe oublié** : le code part par un événement que traite le *worker* (`npm run dev:worker` / `start:worker`). Sans lui, aucun SMS
  n'est envoyé (contrairement à `send-otp`, synchrone). À prévoir dans le déploiement (`start:all`).
- **Mot de passe oublié, numéro inconnu** : le back répond « un code a été envoyé » même sans compte (bien), mais la réponse du cas connu
  contient `phoneNumber`, ce qui permet de distinguer les deux. À aligner.
- **Codes promo, texte affiché** : `displayText` promet « 300 F offerts » alors que la remise réelle est plafonnée par le garde-fou de marge
  (137 F sur une course de 1 529 F). L'app affiche donc le prix réel (`finalEstimatedPrice`), pas le texte. Idéal : renvoyer la remise
  réelle dans la liste, ou un texte généré après plafonnement.
- **Codes promo, erreur technique** : `PromoCode with id 'X' not found` pour un code inconnu (l'app la traduit en « Code promo inconnu. »).
  Renvoyer un code d'erreur stable (`PROMO_CODE_NOT_FOUND`) et un message en français.
- **Création d'un code promo (admin)** : sans les tableaux `targetZones`, `vehicleTypes`, `timeWindows`, la route plante
  (`Cannot read properties of undefined (reading 'length')`) alors que le Swagger les donne comme facultatifs.
- **Parrainage, barème** : le montant de la récompense n'est publié nulle part avant le premier parrainage. L'app l'affiche seulement après avoir
  vu un parrainage (« [à valider] » avant). Proposer `GET /api/passenger/referrals/config` → `{ referrerReward, referredReward, actionsRequired }`.
- **Parrainage, doublon** : `GET /api/passengers/referrals` et `GET /api/passenger/referrals/my` renvoient la même chose ; en garder une.
- **Parrainage, messages** : `Referral code 'X' does not exist not found` (« not found » deux fois), `Cannot refer yourself`,
  `User has already been referred`. L'app les traduit ; mieux vaut des codes stables.

- **Idempotence** : aucune route d'écriture n'accepte `Idempotency-Key` (recharge, transfert, demande de course, commande de livraison). Un retry réseau après timeout peut dupliquer un paiement. L'app ignore les doubles appuis mais ne peut rien contre un retry.
- **Erreurs** : réponses mêlant `{ error: "texte" }` et `{ error: { code, message } }`, en anglais pour la plupart. Proposition : toujours `{ success:false, error:{ code, message } }` avec un `code` stable et `message` en français. L'app traduit pour l'instant les refus du portefeuille et la limite de tentatives.
- **Une session par appareil** : une nouvelle connexion invalide l'ancienne (`SESSION_EXPIRED`). L'app renvoie vers la connexion ; prévenir l'utilisateur est une décision produit.
- **Limite de connexion** : 5 tentatives par 15 minutes (`429`). Renvoyer un `Retry-After` exploitable (déjà présent) et un code `RATE_LIMITED` stable.
- **Statut `PENDING` d'un transfert/une recharge** : exposer `GET /api/wallets/:id/transactions?status=PENDING` pour afficher les opérations en cours.
- **Tests** : `npm run test:unit|integration|e2e` ne trouvent aucun test (voir `CLAUDE.md` du back) et sortent en succès.
- **Changement de destination, réponse du chauffeur** : `GET /api/passenger/rides/:id` n'expose pas `pendingDestinationChange`. L'app ne voit
  donc que l'acceptation (l'adresse d'arrivée `dropoff.address` change) ; un **refus** est invisible tant que le WebSocket
  `ride:destination_change_rejected` n'est pas écouté. Proposition : renvoyer `pendingDestinationChange` (ou son dernier état `ACCEPTED|REJECTED` et le motif) dans `GET /rides/:id`.
- **Répartition du paiement** : `PATCH …/payment-split` n'est accepté que pour `paymentMethod=MIXED` ; l'app crée toutes les courses en `MIXED`.
- **Historique des codes promo** : `GET /api/passenger/promo-codes/usages` mêle les usages de toutes les verticales (`sourceType`) sans libellé ni date de course ; ajouter un titre lisible.

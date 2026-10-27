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

### 5. L'historique des courses du passager n'est branché sur aucune route
- **Constat** : `GET /api/passenger/rides` répond `404 Route not found`. `GetRideHistoryController` et `GetRideHistoryUseCase` existent
  (avec une option `status`) mais `rideRoutes.ts` ne les monte pas.
- **Effet** : l'écran Activités n'affiche que les livraisons ; aucune course passée n'apparaît.
- **À faire** : `GET /api/passenger/rides?status=` → `{ success, data: { rides[], total } }` (le contrôleur est prêt).

### 6. Changement de numéro de téléphone sans vérification
- `PATCH /api/users/:id/phone { newPhoneNumber }` modifie le numéro de connexion sans code SMS sur le nouveau numéro.
  Quiconque détient un jeton peut rediriger le compte. L'écran Profil de l'app appelle cette route.
- **À faire** : exiger un code OTP envoyé au nouveau numéro (`send-otp` puis `verify-otp` avant le changement).

---

## 🟠 Fonctions du mobile que le back ne gère pas

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
| **Délai d'arrivée du chauffeur** (« Chauffeur à 4 min ») | absent de `GET /rides/:id` | `driverEtaMinutes` et la position `driverLocation`. L'écran affiche « Chauffeur en route ». |
| **Recherche d'adresses** | aucun géocodage | `GET /api/places/search?q=` → `[{ id, name, address, lat, lng }]` limité au Bénin. L'app utilise Nominatim public (usage léger seulement). |
| **Livraison** : encaissement à la livraison | rien (`B2cPaymentMethod` = CASH \| WALLET) | `codAmount` à la commande, encaissé par le coursier et reversé. |
| **Livraison** : « le destinataire paie » | rien | `payer: SENDER \| RECIPIENT`. |
| **Livraison** : code de remise visible par l'expéditeur | OTP vérifié par le coursier, non exposé | `handoverCode` dans le suivi, envoyé au destinataire. |
| **Livraison** : véhicules proposés | `B2cVehiclePolicy` : un grand colis ne peut partir qu'en `VAN`, un colis moyen en `STANDARD`/`CONFORT`/`VAN` | L'app propose maintenant ce que le back autorise (moto, tricycle, voiture, van). La règle « grand colis en tricycle » du mobile n'est plus appliquée : à confirmer côté produit. |
| **Livraison** : adresse choisie dans une liste | pas de géocodage | l'app géocode le texte saisi et prend le premier résultat (risque d'erreur). Il faut `GET /api/places/search` et un choix d'adresse dans l'écran. |
| **Livraison** : annulation depuis le suivi | `DELETE /api/passenger/delivery/:id` existe | pas de bouton « annuler » dans l'écran de suivi de l'app : à ajouter côté mobile. |
| **Accueil** : bannières promotionnelles | codes promo existent, pas de flux d'accueil | `GET /api/passenger/home` → `{ promos[] }`. |
| **Activités** : historique unifié (courses, livraisons, bus, hébergement) | historiques séparés par module | `GET /api/passenger/activities` paginé, ou l'app agrège elle-même. |
| **Paramètres** (langue fr/fon/yoruba, notifications) | rien | `GET/PUT /api/passengers/settings`. Stockés sur l'appareil pour l'instant (non persistés après redémarrage). |
| **Messagerie, appel, partage de trajet, urgence** | rien (« bientôt » dans l'app) | à définir. |
| **Bus** : recherche, sièges, billets QR | aucun module | module complet. |
| **Hébergement** : hôtels, chambres, appartements, visites | aucun module | module complet. |

---

## 🟡 Améliorations

- **Idempotence** : aucune route d'écriture n'accepte `Idempotency-Key` (recharge, transfert, demande de course, commande de livraison). Un retry réseau après timeout peut dupliquer un paiement. L'app ignore les doubles appuis mais ne peut rien contre un retry.
- **Erreurs** : réponses mêlant `{ error: "texte" }` et `{ error: { code, message } }`, en anglais pour la plupart. Proposition : toujours `{ success:false, error:{ code, message } }` avec un `code` stable et `message` en français. L'app traduit pour l'instant les refus du portefeuille et la limite de tentatives.
- **Une session par appareil** : une nouvelle connexion invalide l'ancienne (`SESSION_EXPIRED`). L'app renvoie vers la connexion ; prévenir l'utilisateur est une décision produit.
- **Limite de connexion** : 5 tentatives par 15 minutes (`429`). Renvoyer un `Retry-After` exploitable (déjà présent) et un code `RATE_LIMITED` stable.
- **Statut `PENDING` d'un transfert/une recharge** : exposer `GET /api/wallets/:id/transactions?status=PENDING` pour afficher les opérations en cours.
- **Tests** : `npm run test:unit|integration|e2e` ne trouvent aucun test (voir `CLAUDE.md` du back) et sortent en succès.

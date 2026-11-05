# Harmony — contexte complet du projet

> Document de référence pour l'équipe **et** pour Claude Code. À lire avant de coder.
> État au **5 novembre 2026**. Le rapport officiel (anglais, IEEE) est `docs/main.tex` ;
> ce document-ci explique le *pourquoi* et le *comment* plus en détail.
> Plan de travail ordonné : `docs/TODO.md`.

---

## 0. En bref

- **Quoi** : une app iPhone qui joue une courte file (3 à 5 morceaux) tirée de la bibliothèque
  Spotify de l'utilisateur, adaptée au moment : réveil, stress, coup de fatigue, endormissement.
- **Comment** : chaque morceau a deux scores (énergie, positivité). Un petit modèle estime, à partir
  de la fréquence cardiaque, des pas, du sommeil (Apple Watch) et de l'heure, si la personne est
  *plus ou moins activée que d'habitude*. Des règles simples construisent une file qui part de
  l'état actuel et va progressivement vers le but de la situation.
- **Données d'entraînement** : EmoPhone (297 étudiants coréens, Fitbit, humeur notée ~7 fois par jour).
- **Résultat actuel** : AUROC 0,573 sur la vague D-1 (personnes jamais vues), au niveau des
  meilleurs modèles publiés, mais modeste dans l'absolu. On le dit honnêtement.
- **Où ça tourne** : tout sur le téléphone, sauf un petit **Cloudflare Worker** qui garde la clé
  de l'API LLM.

---

## 1. Le projet côté cours

| Élément | Valeur |
|---|---|
| Cours | CSE 406 Software Engineering, Hanyang University (automne 2026) |
| Groupe | G02 « FireStarter » |
| Dépôt | https://github.com/SkaosDev/Harmony |
| Membres | Clément Royer, Cyprien Vanden Abeele, Lucas Miskulin, Riad Mekideche |
| Langue des rendus | Anglais, format IEEE (LaTeX) |

**Rôles** (pas de chef de groupe ; décisions prises ensemble à la réunion hebdomadaire) :

| Rôle | Qui | En pratique |
|---|---|---|
| User | Cyprien | Utilise l'app tous les jours, note si les morceaux collent, remonte les bugs, mène le pilote |
| Customer | Cyprien | Valide que chaque fonction répond aux besoins, valide maquettes et démos |
| Software developer | Riad | App iPhone : Spotify, lecture des données montre, écrans, lecture |
| Software developer | Lucas | Données et IA : scores des morceaux, modèle d'état, règles, scripts d'évaluation |
| Software developer | Clément | App (Swift) et IA, relectures, dépôt, documents, comptes Apple et Spotify |

**Rendus** : A (proposition, rendu), B (spécification, rendu le 6 nov.), puis les phases suivantes
(conception, implémentation, rapport final). Le rendu B a reporté la **répartition détaillée des
tâches** à la phase de conception.

**Jalons** (rendu B) :

| Jalon | Date | Contenu |
|---|---|---|
| M1 | 15 nov. | Connexion Spotify et import testés avec un vrai compte, lecture Apple Health, mode démo |
| M2 | 29 nov. | Scores des morceaux ; modèle d'état entraîné sur EmoPhone, testé sur personnes et vague tenues à part |
| M3 | 6 déc. | Construction de la file, lecture, feedback, explication, écran données |
| M4 | 7 déc. → fin du semestre | Pilote (~2 semaines, ≤ 5 comptes), évaluation, rapport final, démo |

---

## 2. L'idée de l'app

### 2.1 Le problème
Réveil, stress, coup de barre de l'après-midi, endormissement : la bonne musique aide, mais
personne n'a envie de la chercher à ce moment-là. Les plateformes personnalisent selon
l'historique et l'heure, jamais selon le corps. Endel utilise le corps, mais génère ses propres sons.

### 2.2 Les besoins (N1–N4)
- **N1 Zéro effort** : un tap suffit.
- **N2 Ma musique** : surtout la bibliothèque de l'utilisateur, jamais de musique générée.
- **N3 Adapté à mon corps et ma journée.**
- **N4 Contrôle de mes données** : je sais ce qui est lu, je peux tout supprimer.

### 2.3 Les quatre situations

| Situation | Moment typique | But (énergie cible en fin de file) |
|---|---|---|
| Wake-up | matin, après le sommeil | plus d'énergie, doucement (≈ 0,7) |
| Stress | n'importe quand | plus calme (≈ 0,3), morceaux positifs |
| Low energy | creux de l'après-midi | plus d'énergie (≈ 0,7), morceaux positifs |
| Wind-down | soir, nuit | calme, propice au sommeil (≈ 0,2) |

### 2.4 Parcours utilisateur
1. **Premier lancement** : connexion Spotify, choix des données Apple Health autorisées (une phrase
   d'explication par donnée), import de la bibliothèque, scores des morceaux en arrière-plan.
2. **Écran d'accueil** : 4 grands boutons, celui qui est suggéré est mis en avant.
3. **Un tap** → la file démarre dans Spotify ; l'écran montre la pochette, la raison de la file
   (« nuit courte, matin : d'abord calme, puis plus d'énergie ») et trois actions : passer, aimer,
   « ça collait ? ».
4. **Réglages** : liste des données stockées, export, suppression totale.

### 2.5 Exemple
23 h 30, l'utilisateur tape *Wind-down*. Sa fréquence cardiaque est au-dessus de son habitude du
soir → les deux premiers morceaux ont une énergie moyenne, les suivants sont de plus en plus calmes.
S'il passe un morceau, c'est enregistré pour les prochaines files.

---

## 3. Décisions déjà prises (ne pas revenir dessus sans en parler)

| Décision | Pourquoi |
|---|---|
| Pas de caméra, pas de reconnaissance faciale | Trop contraignant, pas utilisable au lit ou en mouvement |
| Pas de musique générée | Besoin N2 |
| Pas d'*audio features* Spotify (valence, energy) | Supprimées pour les nouvelles apps le 27 nov. 2024 |
| Pas d'entraînement sur chaque utilisateur | Mauvais premier jour ; on compare plutôt chacun à sa propre moyenne |
| Modèle entraîné sur EmoPhone | 297 personnes, étiquettes « du moment », étudiants coréens |
| Sortie = plus/moins activé que d'habitude, jamais une émotion | Honnêteté, pas de prétention médicale |
| Entrées du modèle : heure, FC, pas, sommeil | Choix d'équipe. Sur D-1, pas et sommeil n'apportent pas de gain mesurable (voir §6.5) ; on les garde, et on repasse au modèle heure + FC si les vagues D-2/D-3 et le pilote ne montrent rien |
| HRV lue mais hors modèle | Absente d'EmoPhone ; sert seulement à l'explication |
| Météo retirée | Localisations EmoPhone anonymisées ; plafond mesuré à 0,53 AUROC pour tout effet partagé |
| Évaluation par personnes entières tenues à part | Un split aléatoire donne des résultats trop optimistes |
| Un seul composant cloud : Cloudflare Worker | La clé API LLM ne doit jamais être dans l'app |
| Spotify en mode développement (5 utilisateurs) | Le quota étendu est réservé aux entreprises ; l'app est un démonstrateur |
| Pas de leader | Décision d'équipe |

---

## 4. Architecture

### 4.1 Vue d'ensemble

```
                 ┌──────────────────────── iPhone (tout local) ────────────────────────┐
 Apple Watch ──► │ HealthProvider ──► summaries + baselines (SwiftData)                 │
                 │                         │                                            │
 Spotify ◄─────► │ MusicProvider ──► tracks (SwiftData) ──► SongScorer ──► scores       │
 (Web API + app) │                                               │ (MuSe table locale)  │
                 │                                               └─► LLM via Worker ────┼──► Cloudflare Worker ──► API LLM
                 │ FeatureBuilder ──► StateEstimator (Core ML) ──► état 0..1             │     (clé API, allowlist)
                 │                                     │                                 │
                 │ user tape une situation ──► QueueBuilder + Explainer ──► file         │
                 │                                     │                                 │
                 │ Player (App Remote) ──► Spotify app      skip/like ──► feedback        │
                 └───────────────────────────────────────────────────────────────────────┘
 Ordinateurs de l'équipe : entraînement Python sur EmoPhone ──► StateModel (+ paramètres JSON) ──► embarqué dans l'app
```

### 4.2 Ce qui tourne où

| Où | Quoi | Données |
|---|---|---|
| iPhone | toute l'app, le modèle (Core ML), le stockage | santé, bibliothèque, feedback (jamais envoyés ailleurs) |
| Cloudflare Worker | proxy LLM : garde la clé, vérifie l'utilisateur, limite les requêtes | titres + artistes seulement |
| Spotify | auth, bibliothèque, lecture | ce que Spotify a déjà |
| PC/Mac de l'équipe | entraînement, évaluation, construction de la table MuSe | EmoPhone (local, jamais sur Git) |

### 4.3 Modules de l'app (cible)

| Module | Rôle | Exigences |
|---|---|---|
| `MusicProvider` (protocole) + `SpotifyProvider` + `DemoMusicProvider` | connexion, import, recherche d'un titre, lecture, sauvegarde | FR1, FR2, FR9, FR14 |
| `HealthProvider` (protocole) + `HealthKitProvider` + `DemoHealthProvider` | consentements, nouveaux échantillons | FR3, FR14 |
| `SummaryStore` / `BaselineCalculator` | résumés horaires et nocturnes, moyennes personnelles | FR4, NFR4 |
| `SongScorer` | MuSe puis LLM via Worker, cache | FR6 |
| `FeatureBuilder` + `StateEstimator` | features §6, inférence Core ML | FR7 |
| `SituationSuggester` | bouton mis en avant | FR5 |
| `QueueBuilder` + `Explainer` | file et raison | FR8, FR11 |
| `PlayerController` + `FeedbackStore` | lecture, skip/like/fit | FR9, FR10 |
| `DataControl` | voir, exporter, supprimer | FR13 |

Le cœur (`SongScorer`, `FeatureBuilder`, `StateEstimator`, `QueueBuilder`) ne connaît **que** les
deux protocoles : il ne doit jamais appeler Spotify ou HealthKit directement (FR14, testabilité).

### 4.4 Arborescence cible du dépôt

```
Harmony/
├── CLAUDE.md                 consignes pour Claude Code
├── README.md
├── docs/                     main.tex (rapport), PROJECT.md, TODO.md, Submission-B.md
├── app/                      projet Xcode (Harmony.xcodeproj, Harmony/, HarmonyTests/)
│   └── Harmony/
│       ├── App/              HarmonyApp.swift, RootView
│       ├── Features/         Onboarding, Home, Player, Settings (vues SwiftUI)
│       ├── Core/             Models (SwiftData), Features, State, Queue, Scoring
│       ├── Services/         Music (Spotify, Demo), Health (HealthKit, Demo), WorkerClient
│       └── Resources/        muse.sqlite, StateModel.mlmodel, model_params.json, demo/*.json
├── ml/                       explore_d1.py, features.py, train.py, export.py, muse_build.py, llm_check.py
│   └── fixtures/             cas de test « golden » partagés Python ↔ Swift (synthétiques)
├── worker/                   Cloudflare Worker (TypeScript, wrangler)
└── data/                     EmoPhone, UC Irvine… (ignoré par Git)
```

---

## 5. Les données

### 5.1 EmoPhone (entraînement principal)
- **Source** : Harvard Dataverse, doi:10.7910/DVN/QGRVU8 ; article arXiv:2609.16581 (KAIST, 2026).
- **Accès** : accordé par les auteurs pour ce projet. **Utilisation autorisée, redistribution interdite.**
  Les fichiers restent sur les ordinateurs de l'équipe, jamais sur GitHub, jamais dans l'app,
  jamais collés dans un chat.
- **Contenu** : 3 vagues (D-1 2020, D-2 2021, D-3 2022), ~4 semaines chacune, étudiants d'une
  université coréenne, téléphones Android + **Fitbit Inspire HR**. 297 participants retenus.
- **Fichiers d'une vague** (vérifié sur D-1) : `EsmResponse.csv` (réponses d'humeur),
  `UserInfo.csv` (profil, questionnaires — **ne pas utiliser**, données sensibles hors sujet),
  `Sensor/D1_Sensor_Pxxx.tar.gz` (un CSV par capteur et par participant).
- **Ce qu'on utilise** : `Fitbit-HeartRate.csv` (1 mesure / 5 s), `Fitbit-StepCount.csv`
  (pas par minute, minutes sans pas absentes), et dans `EsmResponse.csv` : `pcode`,
  `actualTriggerTime` (ms UTC), `arousal` (−3..+3), `stress`.
- **Pièges connus** :
  - horodatages en ms **UTC** → heure locale = +9 h (Corée) ;
  - **pas de sommeil mesuré** et **pas de HRV** ;
  - localisation brouillée ; la colonne `altitude` de `Location.csv` semble contenir de vraies
    latitudes → **ne jamais l'utiliser** (et le signaler aux auteurs) ;
  - D-3 : stress et dérangement notés 0..+6 au lieu de −3..+3, et 8 adjectifs PANAS en plus ;
  - 10 participants de D-1 ont des fichiers capteurs mais aucune réponse (exclus au contrôle qualité) ;
  - la montre n'était pas portée sur ~34 % des nuits.

### 5.2 MuSe (scores des morceaux)
- Zenodo, doi:10.5281/zenodo.4281165, **CC BY 4.0** (redistribuable avec citation).
- 90 408 morceaux, valence / arousal / dominance issues des tags Last.fm, ID Spotify pour ~68 %
  (« provisoires » selon les auteurs → à vérifier avant de jouer une suggestion).
- Dans l'app : une table réduite (titre, artistes, genre, valence, arousal, spotify_id), ramenée
  sur 0–1. **Vérifier l'échelle réelle des colonnes dans le fichier** avant de normaliser.

### 5.3 UC Irvine (test secondaire, autre marque)
- Labbaf et al., Data in Brief 54 (2024), Dryad doi:10.7280/D1WH6T. 21 étudiants, Samsung + Oura.
  Optionnel ; mêmes règles de confidentialité qu'EmoPhone.

### 5.4 Ce qui ne doit jamais aller sur Git
Données brutes EmoPhone/UC Irvine, tables de features dérivées par participant, clés API,
fichiers `.env`, `.dev.vars`, données de santé réelles d'un membre. Les **résultats agrégés** sont autorisés. Le **modèle entraîné** (quelques coefficients) est
prévu dans l'app et sur GitHub : à confirmer avec les auteurs d'EmoPhone (TODO 2.14b).

---

## 6. Le modèle d'état — contrat des features

C'est la partie la plus fragile : **Python (entraînement) et Swift (app) doivent calculer
exactement la même chose.** Toute modification ici = réentraîner + mettre à jour les fixtures.

### 6.1 Ce qui existe déjà
`ml/explore_d1.py` reproduit le Table VII du rapport (vérifié le 5 nov. avec scikit-learn 1.5.2).
Il définit la version **v0** des features.

### 6.2 Étiquette
Pour chaque réponse d'humeur : `arousal_high = 1` si `arousal` > moyenne d'arousal **de ce
participant**, sinon 0. (Pour D-3, ramener d'abord les échelles 0..6 sur −3..+3.)

### 6.3 Features v0 (ce qui a produit les résultats)

| Groupe | Feature | Définition v0 |
|---|---|---|
| Heure | `hour_sin`, `hour_cos` | sin/cos(2π · heure locale décimale / 24) |
| Heure | `weekend` | 1 si samedi ou dimanche |
| FC | `z_hr_mean_15/30/60` | moyenne FC dans les 15/30/60 min avant t, z-score par participant |
| FC | `z_hr_std_30` | écart-type FC sur 30 min, z-score |
| FC | `zb_hr_mean_30` | FC 30 min moins la moyenne du participant **pour le même bloc de 3 h**, divisée par l'écart-type du participant |
| Pas | `z_log_steps_15/30/60` | log(1 + somme des pas), z-score ; montre portée sans pas = 0 ; montre non portée = inconnu |
| Sommeil | `z_sleep_min` | minutes de sommeil de la nuit (21 h → 12 h), z-score |
| Sommeil | `hours_since_wake` | heures depuis la fin du sommeil (inconnu si la réponse précède le réveil) |
| Sommeil | `sleep_unknown` | 1 si la nuit est inconnue |

Seuils v0 : moyenne FC 15 min ignorée si < 5 mesures, 30 min si < 10 mesures (adaptés au Fitbit).
Valeurs manquantes : imputées par la médiane d'entraînement. Modèle : `StandardScaler` +
`LogisticRegression(max_iter=1000)`.

**Sommeil estimé (EmoPhone n'en a pas)** : une minute est « endormie » si la montre est portée
(FC présente), aucun pas, et FC ≤ 1,05 × le 30e centile des FC/minute du participant. La nuit =
la plus longue suite de telles minutes (trous ≤ 30 min fusionnés), au moins 2 h. Si la FC couvre
moins de 60 % de la fenêtre 21 h–12 h → nuit **inconnue**.

### 6.4 Écarts v0 → app à corriger avant M2 (features **v1**)

| Écart | Problème | Correction v1 recommandée |
|---|---|---|
| Moyennes personnelles calculées sur toute la période | Utilise le futur → légèrement optimiste ; impossible dans l'app | Moyenne/écart-type sur les **14 jours précédents** uniquement (prêt à partir de 7 jours), en Python comme en Swift |
| Moyennes calculées aux instants des réponses | L'app n'a pas de réponses | Calculer la référence sur une **grille régulière** (ex. toutes les 30 min, 8 h–24 h, quand la montre est portée) des 14 derniers jours, des deux côtés |
| FC Fitbit toutes les 5 s, seuils 5/10 mesures | L'Apple Watch mesure beaucoup moins souvent au repos | Utiliser la FC **rééchantillonnée à 1 mesure / 5 min** (déjà testé : AUROC 0,575, identique) et un seuil de 1 mesure minimum par fenêtre |
| Sommeil estimé (Fitbit) vs sommeil mesuré (Apple Watch) | Pas la même mesure | Assumé ; documenter, et vérifier sur le pilote |
| `hr_std_30` | Peu de sens avec 6 mesures | Retirer en v1 |

Proposition de vecteur v1 (ordre fixe, à confirmer par Lucas) :
`hour_sin, hour_cos, weekend, z_hr_15, z_hr_30, z_hr_60, zb_hr_30, z_log_steps_15,
z_log_steps_30, z_log_steps_60, z_sleep_min, hours_since_wake, sleep_unknown` (13 entrées).

### 6.5 Résultats actuels (D-1, 92 participants, 10 259 réponses, 5 groupes par participant)

| Cible et entrées | AUROC | Balanced acc. |
|---|---|---|
| Arousal : heure seule | 0,532 | 0,509 |
| Arousal : heure + sommeil | 0,526 | 0,507 |
| Arousal : heure + FC | 0,577 | 0,547 |
| Arousal : heure + FC + pas | 0,577 | 0,547 |
| **Arousal : heure + FC + pas + sommeil (notre modèle)** | **0,573** | **0,542** |
| Même chose, gradient boosting | 0,558 | 0,533 |
| Heure + FC, 1 mesure / 5 min | 0,575 | 0,546 |
| Stress : notre modèle | 0,543 | 0,514 |
| Humeur des *autres* participants au même moment | 0,530 | – |

Lecture : la FC porte l'information ; pas et sommeil n'ajoutent rien de mesurable sur D-1
(écart < variation entre groupes ±0,015). 0,5 = hasard. Le stress est à peine prévisible → la
situation *Stress* est choisie par l'utilisateur, pas déclenchée automatiquement.

### 6.6 Protocole d'évaluation (M2)
1. Validation croisée en 5 groupes par participant sur D-1 + D-2.
2. Test unique sur **D-3** (vague tenue à part), puis sur UC Irvine si le temps le permet.
3. Toujours comparer à la référence « heure seule » ; si le modèle ne la bat pas, l'app
   utilise le mode heure seule.
4. Vérifier qu'aucun participant n'apparaît dans deux vagues.

### 6.7 Export vers l'app
- Coefficients, moyennes, écarts-types, médianes d'imputation et **ordre des features** dans
  `model_params.json` ; modèle Core ML via coremltools (comme annoncé dans le rapport).
- **Fixtures « golden »** : Python génère des séries synthétiques (FC, pas, sommeil) +
  les features et la probabilité attendues ; un test Swift doit retrouver les mêmes valeurs
  (tolérance 1e-6). C'est la meilleure protection contre les écarts Python ↔ Swift.

---

## 7. Scores des morceaux

1. Normaliser titre et artiste (minuscules, sans accents, sans « Remastered », « feat. », etc.).
2. Chercher dans la table MuSe : d'abord par ID Spotify, puis par titre + premier artiste.
3. Sinon, envoyer par lots de 50 (titre + artistes seulement) au **Worker**, qui appelle le LLM
   et renvoie `{energy, positivity}` entre 0 et 1 en JSON. Réponse invalide → 0,5 / 0,5, origine
   « LLM », utilisé en dernier.
4. Mettre en cache : chaque morceau n'est envoyé qu'une fois.
5. **Contrôle hors ligne** : le même prompt sur 2 000 morceaux MuSe (scores cachés au LLM) →
   corrélation et erreur moyenne, via l'API Batch (moitié prix).

LLM prévu : Claude Haiku 5.5 (`claude-haiku-5-5`), < 1 $ au total d'après l'estimation du
rapport. Attention : l'API est facturée à part de l'abonnement Claude Pro (compte Console +
crédit à acheter).

### 7.1 Le Worker (seul composant cloud)
- Route unique, par ex. `POST /score` avec `{songs: [{title, artists}]}` (≤ 50).
- **Authentification sans comptes à nous** : l'app envoie son jeton d'accès Spotify ; le Worker
  appelle `GET https://api.spotify.com/v1/me` et n'accepte que les ID Spotify de la liste blanche
  (les ≤ 5 comptes du pilote). Proposition à valider en équipe.
- Clé LLM : `wrangler secret put …`, jamais dans le code. Limite simple : taille des lots,
  nombre de requêtes par utilisateur et par jour.
- Offre gratuite Cloudflare : 100 000 requêtes/jour, largement suffisant.

---

## 8. Construction de la file

Paramètres de départ (à ajuster au pilote) :
- `e0` = état estimé (0..1) ; `g` = énergie cible de la situation (§2.3).
- `n = 5` si |e0 − g| > 0,3, sinon 3 ; `m` = 2 morceaux « de correspondance » si n = 5, sinon 1.
- Cibles : `m` fois `e0`, puis réparties régulièrement de `e0` à `g`.
- Pour chaque cible : morceau de la bibliothèque le plus proche en énergie, avec pénalités
  (+0,2 si positivité < 0,5 pour Stress/Low energy ; +0,3 artiste déjà dans la file ; +0,1 score LLM).
  Exclure les morceaux joués dans les 3 derniers jours et ceux passés 2 fois dans cette situation.
- Si aucun morceau à moins de 0,15 de la cible et < 2 suggestions : morceau MuSe (artiste ou genre
  présent dans la bibliothèque), ID vérifié par `GET /tracks/{id}` (titre + artiste), marqué « nouveau ».
- Explication : phrases fixes (contexte + plan), **jamais** un mot d'émotion.

Suggestion de situation (FR5) : Wake-up dans les 2 h après la fin du sommeil ; Wind-down après
21 h ; Low energy entre 13 h et 17 h si état < 0,4 ; sinon aucune suggestion. Stress jamais
suggéré automatiquement (modèle trop faible sur le stress).

---

## 9. Spotify — ce qu'il faut savoir

- **Mode développement** : 5 utilisateurs max, à ajouter par e-mail dans le dashboard ; le
  propriétaire de l'app doit avoir **Premium** ; lecture = Premium + vrai iPhone + app Spotify installée.
- **Changements de février 2026** (vérifiés le 4 nov.) : restent disponibles `GET /me/tracks`,
  `GET /me/top/tracks`, `GET /me/player/recently-played`, `GET /tracks/{id}`, `GET /me`,
  lecture et file. Supprimé : `GET /tracks` (plusieurs titres d'un coup). Sauvegarder un titre :
  `PUT /me/library` avec des URI. `GET /me` ne renvoie plus e-mail ni pays. `GET /search` : 10
  résultats max par page.
- **Scopes probables** : `user-library-read`, `user-library-modify`, `user-top-read`,
  `user-read-recently-played`, `app-remote-control` (à confirmer au premier test).
- **Authentification** : flux *Authorization Code with PKCE* (pas de secret dans l'app).
  Option sûre : le faire nous-mêmes avec `ASWebAuthenticationSession`, puis donner le jeton à
  App Remote. Le SDK semble aussi gérer PKCE sans serveur, mais ce n'est **pas confirmé** → tester en M1.
- **Lecture** : App Remote (SDK iOS 5.0.1) pilote l'app Spotify ; la connexion peut tomber quand
  l'app passe en arrière-plan → prévoir la reconnexion et le repli « ouvrir dans Spotify ».
- **Règles d'affichage** : pochette non modifiée, logo Spotify, lien vers Spotify (NFR6).

## 10. HealthKit — ce qu'il faut savoir

- Types lus : `heartRate`, `stepCount`, `heartRateVariabilitySDNN`, catégorie `sleepAnalysis`.
- `Info.plist` : `NSHealthShareUsageDescription` (texte clair) ; capacité HealthKit dans Xcode.
- **Compte développeur** : HealthKit est une capacité restreinte ; avec un compte Apple gratuit
  elle n'est probablement pas disponible sur un vrai appareil → **acheter l'Apple Developer
  Program dès le début** (déjà budgété, 99 $).
- **Lecture impossible téléphone verrouillé** → lire à l'ouverture de l'app (requêtes ancrées).
- **Un refus de lecture est invisible** : HealthKit ne dit pas si l'utilisateur a refusé, il
  renvoie juste aucune donnée → c'est le cas « inconnu », pas une erreur.
- **Sommeil** : garder seulement les échantillons de l'Apple Watch (source) et les valeurs
  `asleepCore`, `asleepDeep`, `asleepREM`, `asleepUnspecified` ; ignorer `inBed` saisi sur l'iPhone.
- **Montre portée ?** Pas de FC = montre pas portée (nuit < 60 % couverte → sommeil inconnu).
- Le simulateur n'a pas de montre : utiliser le **mode démo** (fichiers enregistrés).

## 11. Confidentialité et sécurité (résumé)
- Santé : sur le téléphone uniquement, résumés horaires/nocturnes, échantillons bruts jetés.
- Jetons Spotify dans le Keychain ; HTTPS uniquement ; aucune clé dans l'app.
- Le LLM ne reçoit que titres et artistes.
- L'utilisateur peut tout voir, exporter, supprimer (FR13).
- Pas de nom d'émotion affiché, pas de promesse médicale (NFR7).

---

## 12. Où on en est (5 novembre 2026)

**Fait**
- Rendu A ; rendu B rédigé (7 pages, `docs/main.tex`, PDF, version Markdown).
- Accès EmoPhone obtenu ; vague D-1 analysée ; résultats reproductibles (`ml/explore_d1.py`).
- Choix techniques, coûts vérifiés, API Spotify de février 2026 vérifiée sur la documentation.
- Dépôt GitHub créé (Harmony), lien et sujet dans le Google Sheet du cours.

**Pas encore fait**
- Aucun code d'app ; aucun compte développeur configuré (Apple, Spotify, Cloudflare, API LLM).
- D-2 et D-3 pas encore analysées ; features v1 (§6.4) pas encore écrites.
- Table MuSe pas encore construite ; prompt LLM pas encore testé.
- Aucun appel Spotify testé avec un vrai compte.

## 13. Risques et questions ouvertes

| Risque / question | Impact | Action |
|---|---|---|
| Qui a un Mac ? (un seul MacBook Air déclaré) | Le développement iOS ne peut se faire que sur Mac | Décider tout de suite qui code l'app où |
| HealthKit avec compte gratuit | Bloque la lecture sur un vrai iPhone | Acheter l'Apple Developer Program en premier |
| Installer l'app sur les iPhone du pilote | Sans TestFlight ou appareils enregistrés, pas de pilote | Vérifier TestFlight vs. installation Xcode (UDID) avant M3 |
| Spotify PKCE/App Remote | Bloque M1 | Prototype d'auth dès la première semaine |
| Fréquence de mesure FC Apple Watch | Features vides | Mesurer sur une vraie montre en M1 ; features v1 adaptées |
| Couverture MuSe de vos bibliothèques | Beaucoup d'appels LLM | Mesurer dès que l'import marche |
| Gain réel de pas + sommeil | Modèle plus complexe sans gain | Tester sur D-2/D-3 et au pilote ; repli heure + FC |
| Coût Claude Pro (160 $) annoncé dans le rapport | Doit correspondre à la réalité | Confirmer qui s'abonne |

---

## 14. Travailler avec Claude Code (vibe coding encadré)

### 14.1 Méthode
1. **Une tâche du TODO = une session = une branche = une PR.** Commencer en *plan mode*,
   faire valider le plan, puis implémenter.
2. Donner la section utile de ce document dans le prompt (« lis PROJECT.md §6 et §10 »).
3. Exiger la vérification de la ligne « ✔ » de la tâche (test, build, capture) avant de cocher.
4. **Tests d'abord** pour le cœur (features, baselines, file) : ce sont des fonctions pures.
5. Un autre membre relit chaque PR, même générée par Claude.
6. Ne jamais donner à Claude un accès en lecture aux fichiers EmoPhone bruts pour « regarder » :
   lui faire écrire des scripts qui affichent des **agrégats** seulement.

### 14.2 Outils recommandés
- **CLAUDE.md** du dépôt : tes consignes générales + une section projet (déjà faite).
- **XcodeBuildMCP** (MIT, maintenu par Sentry) : Claude Code peut compiler, lancer sur le
  simulateur ou l'iPhone, lancer les tests et lire les erreurs.
  Installation : `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp`
  (macOS 14.5+, Xcode 16+, Node 18+).
- **context-mode** (déjà installé) : très utile avec Xcode, dont les journaux de compilation
  sont énormes ; il garde la sortie hors du contexte.
- **Agents/skills VoltAgent** (déjà installés) : utiliser un agent Swift/iOS pour l'app, un agent
  ML/data pour `ml/`, et un agent de relecture de code avant chaque PR.
- **gh** (GitHub CLI) : Claude Code peut ouvrir les PR et lire les retours de relecture.
- **Xcode 16+ « synchronized folders »** : les fichiers ajoutés sur disque apparaissent dans le
  projet sans toucher `project.pbxproj` → beaucoup moins de conflits Git entre Riad et Clément.
- `swift format` (fourni avec Swift 6) pour un style uniforme.

### 14.3 Pièges du vibe coding sur ce projet
- Claude invente facilement des API HealthKit/Spotify qui n'existent pas → lui faire vérifier dans
  la doc (ou via XcodeBuildMCP : ça compile ou pas).
- Il « simplifie » les features en changeant une définition → c'est interdit sans mise à jour
  des fixtures (§6.7).
- Il peut proposer de mettre la clé API dans l'app « pour tester » → refuser.
- Il peut ajouter des dépendances (SPM) inutiles → n'accepter que le SDK Spotify.

---

## 15. Références utiles
- Rapport : `docs/main.tex` (références [1]–[19]).
- EmoPhone : https://arxiv.org/abs/2609.16581 — doi:10.7910/DVN/QGRVU8
- MuSe : doi:10.5281/zenodo.4281165
- Spotify Web API, changements fév. 2026 : https://developer.spotify.com/documentation/web-api/references/changes/february-2026
- Spotify iOS SDK : https://github.com/spotify/ios-sdk
- HealthKit : https://developer.apple.com/documentation/healthkit
- Cloudflare Workers (limites) : https://developers.cloudflare.com/workers/platform/limits/
- XcodeBuildMCP : https://github.com/getsentry/XcodeBuildMCP
- context-mode : https://github.com/mksglu/context-mode

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

### 2.6 Design des écrans
Tous les écrans sont déjà dessinés (18 écrans) dans le canvas
https://claude.ai/code/artifact/0daa5d2a-f709-49a4-b443-88a879845319, copié dans `docs/design/`
(voir son `README.md`). L'app les reproduit **à l'identique**. Navigation : 3 onglets
(Home, Library, Settings) ; le lecteur et la file s'ouvrent depuis Home ; l'écran Debug n'est
pas dans le design (accessible depuis Settings, en build Debug seulement).

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
| MuSe v3 (Kaggle), scores en rang centile, ID Spotify en double retirés | Seule version avec un genre ; échelle brute trop resserrée ; ID partagés souvent faux (§5.2) |
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

### Différences entre vagues (TODO 1.35)
Exploration du 10 nov. 2026 : D-1/D-2/D-3 ont respectivement 10 259/21 042/21 838 réponses
et 92/99/106 participants répondants. D-2 ajoute `intendedTriggerTime`, `valenceChange` et
`arousalChange`, remplaçant `change` ; D-3 ajoute `intendedTriggerTime` et les huit adjectifs
PANAS (happy, relaxed, cheerful, content, sad, anxious, depressed, angry), et ne contient plus
attention, mental, duration ni les items de changement. Valence et arousal restent sur −3..+3
dans les trois vagues. En D-3, stress, dérangement et les huit adjectifs sont sur 0..+6.

Les archives capteurs sont au nombre de 102/112/106 ; 10/13/0 ont un fichier capteur mais aucune
réponse, et 0/0/0 participants répondants n'ont pas d'archive. Les colonnes Fitbit restent
`timestamp,value`. D-2 ajoute `KeyEvent.csv`, `Proximity.csv` et quatre fichiers `Fitness-*` ;
D-3 a `KeyEvent.csv` mais pas `Proximity.csv` ni ces fichiers `Fitness-*`. Les médianes des
médianes d'intervalle FC sont 0,08 min (101 participants avec mesures), 0,08 min (77) et 0,08 min
(106), soit environ 5 s. Les réponses couvrent le 8 fév.–2 avr. 2020, le 7 déc. 2020–27 janv. 2021
et le 24 nov. 2021–11 janv. 2022 (heures KST, timestamps en ms UTC).

### Identité des participants entre vagues (TODO 1.36)
L'article dit « All three cohorts were drawn from the same university student population »
(annexe A.2), mais ne précise pas si des personnes reviennent d'une vague à l'autre. Les `pcode`
sont numérotés par vague ; 82/78/86 codes sont communs à D-1/D-2, D-1/D-3 et D-2/D-3, sans
permettre d'identifier les mêmes personnes. Il faut demander confirmation à l'équipe EmoPhone.
En attendant, tout entraînement combinant des vagues utilise un identifiant `vague + pcode`
(ex. `D1_P050`) pour éviter de fusionner des personnes distinctes.

### 5.2 MuSe (scores des morceaux)
- Akiki & Burghardt 2021 (doi:10.5334/johd.33), **CC BY 4.0** (redistribuable avec citation).
- **Version utilisée : v3 sur Kaggle** (`cakiki/muse-the-musical-sentiment-dataset`, version 5 du
  jeu, fichier `muse_v3.csv`), publiée par les auteurs. Contrairement à la version Zenodo
  (doi:10.5281/zenodo.4281165 : 90 408 lignes, 8 colonnes, ni genre ni nombre de tags), elle a un
  **genre** et le **nombre de tags d'émotion** de chaque morceau. Le rapport B cite 90 408
  morceaux (Zenodo) ; le rapport final citera la v3 (90 001).
- Valence / arousal / dominance issues des tags Last.fm (lexique de Warriner et al.), ID Spotify
  pour ~68 % (« provisoires » selon les auteurs → à vérifier avant de jouer une suggestion).
- Dans l'app : une table réduite (titre, artistes, genre, valence, arousal, spotify_id), ramenée
  sur 0–1 selon les décisions ci-dessous.

**Fichier vérifié le 10 nov. 2026 (TODO 1.38)** — `python ml/muse_download.py` →
`data/muse/muse_v3.csv` (ignoré par Git) : 18 200 150 octets (taille donnée par Kaggle), SHA-256
`9fdba18b43c2b05187a4136bc0c0996c2cf41a3e5d55b27015131fafd410aa07` (contrôlé par le script).

**90 001 lignes, 11 colonnes** : `lastfm_url` (unique), `track` (79 392 titres distincts),
`artist` (un seul champ texte, 26 012 valeurs), `seeds`, `number_of_emotion_tags` (1 à 50,
médiane 2 ; 28,6 % des morceaux n'ont qu'un tag), `valence_tags`, `arousal_tags`,
`dominance_tags` (remplies à 100 %), `mbid` (68,0 %, sans doublon), `spotify_id` (68,5 % :
61 630 remplis, 60 656 distincts), `genre` (92,6 %, 811 valeurs dont 107 couvrent 90 % ; en tête
indie, rock, electronic, pop, ambient).

Échelle **observée** (l'échelle théorique n'est pas documentée) :

| Colonne | min | q1 | médiane | q3 | max | moyenne |
|---|---|---|---|---|---|---|
| `valence_tags` | 0,235 | 4,277 | 5,650 | 6,697 | 8,475 | 5,454 |
| `arousal_tags` | 0,108 | 3,527 | 4,330 | 5,150 | 7,270 | 4,318 |
| `dominance_tags` (non utilisée) | 0,229 | 4,550 | 5,460 | 6,115 | 7,440 | 5,246 |

**Décisions du 10 nov. 2026, à appliquer dans `ml/muse_build.py` (1.39) :**
1. **Échelle 0–1 = rang centile** sur les 90 001 lignes, avant tout filtrage :
   `energy = arousal_tags.rank(pct=True)`, `positivity = valence_tags.rank(pct=True)` (ex aequo :
   rang moyen). Une énergie de 0,2 veut dire « plus calme que 80 % des morceaux MuSe ».
   Pourquoi : l'échelle brute n'est pas 1–9 stricte et l'arousal est très resserrée ; un min–max
   mettrait 63 % des morceaux entre 0,45 et 0,75 et seulement 4,7 % sous 0,3, si bien que
   Wind-down (0,2) et Stress (0,3) ne trouveraient presque rien. Le centile répartit les morceaux
   sur 0–1 et donne un sens aux cibles (§2.3), à la tolérance de 0,15 et au seuil de positivité
   0,5 (§8). Conséquence : les scores LLM (absolus) sont comparés à cette échelle en 2.30 ; s'ils
   s'en écartent, on les convertit en centiles MuSe (décision en 2.31).
2. **Genre = colonne `genre` de la v3.** `Track` n'a pas de genre et on n'ajoute aucun appel
   Spotify : les « genres de la bibliothèque » sont les genres MuSe des morceaux de la
   bibliothèque trouvés dans MuSe. Repli (§8, 3.5) : d'abord un morceau MuSe d'un artiste de la
   bibliothèque, sinon d'un de ces genres. 58 687 lignes ont à la fois un genre et un ID Spotify.
3. **ID Spotify en double** (889 ID sur 1 863 lignes) : l'ID est **retiré de toutes ces lignes**.
   Dans 490 cas sur 889, ce sont des morceaux différents (titre ou artiste différents après
   normalisation) : au moins une correspondance est fausse ; même pour le même morceau, les
   scores diffèrent presque toujours. Ces lignes restent trouvables par titre + artiste, mais ne
   peuvent pas être suggérées (pas d'ID sûr).
   **Clé titre + premier artiste en double** (2 097 clés et 5 544 lignes avec une normalisation
   simple) : une seule ligne par clé normalisée (fonction de 1.40), celle qui a le plus de tags
   d'émotion (scores les plus fiables) ; à égalité, la première du fichier.

**Construction (TODO 1.39)** — `ml/muse_build.py` lit 90 001 lignes, retire les ID Spotify
dupliqués (889 ID, 1 863 lignes), puis garde une ligne par clé titre/artiste : 678 clés en double
(1 410 lignes concernées ; 732 retirées). Aucune clé n'est vide. La table `songs` contient
`spotify_id`, `title`, `artists`, `genre`, `energy`, `positivity`, `match_key` ; la clé normalisée
est sa clé primaire indexée, avec un index sur `spotify_id`. 89 269 lignes sont gardées, dont
59 679 avec ID et 82 685 avec genre. Scores centiles : énergie min/médiane/max =
0,000011/0,499717/0,999000 ; positivité = 0,000011/0,500500/1,000000.
Le fichier fait 14 155 776 octets après `VACUUM`, donc dépasse 10 Mo : la tâche reste décochée.
Le stockage `WITHOUT ROWID` avec `match_key` comme clé primaire et une taille de page de 16 Kio
a réduit le fichier de 15 532 032 octets (table avec rowid, page 4 Kio) à 14 155 776 octets,
sans suffire. Une compression exigeant une extension SQLite ou une représentation qui modifie le
schéma nécessite une décision d'équipe avant d'être retenue.

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
| Sommeil estimé (Fitbit) vs sommeil mesuré (Apple Watch) | Pas la même mesure | Assumé ; documenté en §10 (sommeil « comme Santé ») ; vérifier sur le pilote |
| `hr_std_30` | Peu de sens avec 6 mesures | Retirer en v1 |

**Mesure terrain (TODO 1.33, 10 nov.)** — Apple Watch (Watch7,2) portée jour et nuit sur les
48 h mesurées, hors charge le soir, 552 FC : intervalle **médian** entre deux FC = **4,2 min la nuit**
(0–6 h, 133 intervalles) et **4,6 min le jour** (8–24 h, 360 intervalles). La FC à 1 mesure / 5 min
correspond bien à l'Apple Watch ; une fenêtre de 15 min contient ~3 mesures, donc le seuil
« 1 mesure minimum par fenêtre » tient.

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

**Résultats par vague (features v0, TODO 1.37)** — 10 nov. 2026, scikit-learn 1.5.2.

| Ligne de sortie | D-1 | D-2 | D-3 |
|---|---:|---:|---:|
| Réponses / participants | 10 259 / 92 | 21 042 / 99 | 21 838 / 106 |
| Nuits avec sommeil estimé | 0,66 | 0,41 | 0,78 |
| Heure seule — AUROC ± écart / balanced accuracy | 0,530 ± 0,013 / 0,509 | 0,538 ± 0,016 / 0,509 | 0,542 ± 0,007 / 0,500 |
| Heure + sommeil — AUROC ± écart / balanced accuracy | 0,524 ± 0,016 / 0,506 | 0,552 ± 0,026 / 0,531 | 0,540 ± 0,010 / 0,503 |
| Heure + FC — AUROC ± écart / balanced accuracy | 0,576 ± 0,009 / 0,544 | 0,570 ± 0,014 / 0,526 | 0,593 ± 0,009 / 0,547 |
| Heure + FC + pas — AUROC ± écart / balanced accuracy | 0,576 ± 0,008 / 0,544 | 0,571 ± 0,013 / 0,529 | 0,599 ± 0,012 / 0,553 |
| Notre modèle — AUROC ± écart / balanced accuracy | 0,572 ± 0,005 / 0,544 | 0,576 ± 0,017 / 0,544 | 0,598 ± 0,011 / 0,551 |
| Gradient boosting — AUROC ± écart / balanced accuracy | 0,558 ± 0,008 / 0,537 | 0,566 ± 0,024 / 0,538 | 0,589 ± 0,012 / 0,552 |
| FC toutes les 5 min — AUROC ± écart / balanced accuracy | 0,575 ± 0,008 / 0,546 | 0,567 ± 0,014 / 0,523 | 0,591 ± 0,010 / 0,544 |
| Stress, notre modèle — AUROC ± écart / balanced accuracy | 0,546 ± 0,018 / 0,516 | 0,530 ± 0,027 / 0,512 | 0,558 ± 0,010 / 0,529 |
| Humeur des autres à même date/heure — AUROC ± écart | 0,521 ± 0,012 | 0,519 ± 0,012 | 0,539 ± 0,021 |

Le modèle complet dépasse l'heure seule en AUROC sur les trois vagues.

Le contrôle D-1 du 10 nov. donne 0,530 pour l'heure seule, 0,576 pour heure + FC et 0,572 pour
le modèle complet, contre 0,532, 0,577 et 0,573 dans les résultats précédemment consignés ; le
script n'a pas été ajusté pour rapprocher ces valeurs.

Lecture : la FC porte l'information ; pas et sommeil n'ajoutent rien de mesurable sur D-1
(écart < variation entre groupes ±0,015). 0,5 = hasard. Le stress est à peine prévisible → la
situation *Stress* est choisie par l'utilisateur, pas déclenchée automatiquement.

### 6.6 Protocole d'évaluation (M2)
1. Validation croisée en 5 groupes par participant sur D-1 + D-2.
2. Test unique sur **D-3** (vague tenue à part), puis sur UC Irvine si le temps le permet.
3. Toujours comparer à la référence « heure seule » ; si le modèle ne la bat pas, l'app
   utilise le mode heure seule.
4. La documentation ne précise pas si des personnes reviennent d'une vague à l'autre (§5.1) ;
   demander confirmation. En combinant des vagues, grouper par `vague + pcode` jusque-là.

### 6.7 Export vers l'app
- Coefficients, moyennes, écarts-types, médianes d'imputation et **ordre des features** dans
  `model_params.json` ; modèle Core ML via coremltools (comme annoncé dans le rapport).
- **Fixtures « golden »** : Python génère des séries synthétiques (FC, pas, sommeil) +
  les features et la probabilité attendues ; un test Swift doit retrouver les mêmes valeurs
  (tolérance 1e-6). C'est la meilleure protection contre les écarts Python ↔ Swift.

---

## 7. Scores des morceaux

1. Normaliser titre et artiste avec les mêmes règles en Python (`ml/normalize.py`) et en Swift :
   NFKC, puis `casefold` ; couper au premier marqueur `feat.`, `ft.` ou `featuring` (et tout ce
   qui suit) ; supprimer les mentions de version seulement entre parenthèses/crochets ou en
   suffixe après un tiret/espace : `Remaster`/`Remastered` avec année avant ou après, `Radio Edit`,
   `Single Version`, `Album Version`, `Mono`, `Stereo`. Garder `Live`, `Remix`, `Acoustic`,
   `Instrumental` et `Demo`. Convertir les apostrophes typographiques en `'`, les autres signes
   de ponctuation/symboles en espaces, retirer les accents des seules lettres latines et fusionner
   les espaces. Ne pas décomposer les écritures non latines. Si le titre devient vide, reprendre
   le titre normalisé avant suppression des marqueurs featuring/version. Le premier artiste est
   la partie avant le premier marqueur featuring ; ne pas couper sur `&`, `and` ou `,`.
2. Chercher dans la table MuSe : d'abord par ID Spotify, puis par titre + premier artiste.
3. Sinon, envoyer par lots de 50 (titre + artistes seulement) au **Worker**, qui appelle le LLM
   et renvoie `{energy, positivity}` entre 0 et 1 en JSON. Réponse invalide → 0,5 / 0,5, origine
   « neutre » (`SongScore.origin = neutral`), utilisé en dernier.
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
- Si aucun morceau à moins de 0,15 de la cible et < 2 suggestions : morceau MuSe d'un artiste de la
  bibliothèque, sinon d'un genre de la bibliothèque (genres MuSe de ses morceaux, §5.2), ID vérifié
  par `GET /tracks/{id}` (titre + artiste), marqué « nouveau ».
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
- **Scopes demandés** (TODO 1.22, tous accordés au test du 10 nov.) — un par usage :

  | Scope | Pour | Testé |
  |---|---|---|
  | `user-library-read` | `GET /me/tracks` (titres aimés) | oui (1.21) |
  | `user-top-read` | `GET /me/top/tracks` | oui (1.21) |
  | `user-read-recently-played` | `GET /me/player/recently-played` | oui (1.21) |
  | `user-library-modify` | `PUT /me/library` (like, TODO 3.14) | pas encore |
  | `app-remote-control` | App Remote (lecture, TODO 3.10) | pas encore |

  `GET /me` et `GET /tracks/{id}` ne demandent aucun scope. Pas de `user-read-private` ni
  `user-read-email` : `GET /me` ne renvoie de toute façon plus ni e-mail ni pays.
- **Authentification** : flux *Authorization Code with PKCE* (pas de secret dans l'app), fait
  nous-mêmes avec `ASWebAuthenticationSession` (`Services/Music/Spotify/`), redirection
  `harmony://callback` ; **marche sur un vrai iPhone** (TODO 1.18, 10 nov.). Jetons dans le
  Keychain (`AfterFirstUnlockThisDeviceOnly`), rafraîchis 1 min avant expiration ou après un 401.
  Reste à confirmer en 3.10 : App Remote accepte ce jeton.
- **Endpoints testés avec un vrai compte** (TODO 1.21, 10 nov., iPhone 16, compte de Clément,
  écran Debug › Check endpoints) :

  | Endpoint | Résultat |
  |---|---|
  | `GET /me` | OK |
  | `GET /me/tracks` | OK |
  | `GET /me/top/tracks` | OK |
  | `GET /me/player/recently-played` | OK |
  | `GET /tracks/{id}` | OK |

- **Import** (TODO 1.23, 1.25, 1.27) : titres aimés par pages de 50, + 50 top tracks
  (`medium_term`) + 50 dernières écoutes, fusionnés par ID Spotify (priorité aimé > top > récent).
  Mesure du 10 nov. (iPhone 16, compte de Clément) : 937 titres aimés tous importés ;
  **939 titres en 4,6 s** (enregistrement SwiftData compris), soit ~10 s attendues pour 2 000
  (NFR3 : < 60 s). Pas de compte à 2 000 titres aimés sous la main : estimation acceptée pour
  1.27 (le temps croît avec le nombre de pages de 50). Un `429` attend `Retry-After` (≤ 30 s, sinon erreur), 3 essais max.
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
- **Montre portée ?** Pas de FC = montre pas portée (nuit < 60 % couverte, en créneaux de 15 min → sommeil inconnu).
- Le simulateur n'a pas de montre : utiliser le **mode démo** (fichiers enregistrés).

### Ce que fait l'app (1.APP-e, 10 nov.)
- **Apple Watch seulement**, pour les 4 types (`sourceRevision.productType` commence par `Watch`) :
  les pas de l'iPhone seraient comptés deux fois, et « pas de FC = montre non portée » doit rester vrai.
- **À chaque ouverture** (`SummaryStore.update`) : requête ancrée par type (ancre dans
  `UserDefaults`) ; à partir du plus ancien échantillon nouveau, l'app relit les échantillons et
  réécrit toutes les heures et nuits touchées (une synchronisation tardive de la montre corrige
  les heures anciennes). Premier import : 14 jours. Les échantillons bruts ne restent qu'en
  mémoire ; seuls `HourSummary` et `NightSummary` sont stockés. Échantillons supprimés dans Santé : ignorés.
- **Heure** : FC moyenne + nombre de mesures, HRV moyenne, pas répartis entre heures au prorata.
  Pas = `nil` (inconnu) si l'heure n'a ni FC ni pas ; 0 si FC sans pas. Heure sans donnée : pas de ligne.
- **Nuit** (fenêtre 21 h → 12 h, rattachée au jour du réveil), mesurée « comme Santé » :
  `sleepMinutes` = total des intervalles asleep* dans la fenêtre (comptés une fois s'ils se
  chevauchent) ; `sleepEnd` = fin du dernier. Couverture = part des créneaux de **15 min** contenant
  au moins une FC, sur la partie **écoulée** de la fenêtre (une file à 7 h connaît la nuit).
  Nuit **inconnue** si couverture < 60 % **ou** aucun intervalle asleep* (suivi du sommeil
  désactivé) : jamais 0. Différent de v0 (bloc le plus long ≥ 2 h, §6.3) : à reprendre en 2.5 (Lucas).
- **Règle 60 % (TODO 1.34, 10 nov.)** : 3 nuits portées (8, 9, 10 nov., montre en charge quelques
  dizaines de minutes le soir) → couverture **87 %, 95 %, 95 %** avec des créneaux de 15 min, mais
  seulement 68 %, 68 %, 71 % avec des créneaux de 5 min (la montre mesure toutes les 4–5 min,
  §6.4) : trop près du seuil. Seuil de 60 % **gardé**, créneau **passé de 5 à 15 min**.
- Vérifié sur iPhone 16 + Apple Watch (10 nov.) : pas du jour 4 873 (Santé 4 919, écart dû aux
  pas de l'iPhone) ; dernière HRV 181 ms (Santé 181) ; nuit 8 h 49 (Santé 8 h 51) ; premier import
  de 14 jours en 3,4 s ; à l'ouverture suivante, seule la nouvelle FC est lue.
- La suppression totale (3.19) devra aussi effacer les ancres HealthKit.

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

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
- **Modèle d'état v2 (décidé le 23 nov. 2026, pas encore implémenté)** : des questions facultatives
  en un geste (« Energy right now? ») ajustent ce modèle commun à chacun, sur l'iPhone (couche
  personnelle), et la file s'adapte aux skips et aux likes. Design :
  `docs/superpowers/specs/2026-11-23-modele-etat-v2-design.md` ; tâches : TODO Phase 6 (§6.8).
- **Données d'entraînement** : EmoPhone (282 étudiants coréens, 297 participants-vagues, Fitbit,
  humeur notée ~7 fois par jour).
- **Résultat actuel** : AUROC 0,573 sur la vague D-1 (personnes jamais vues), proche du meilleur
  résultat publié sur cette vague (0,576, avec une cible et un protocole un peu différents), mais
  modeste dans l'absolu. On le dit honnêtement.
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
| M4 | 26 nov. → 4 déc. (fin du projet) | Pilote (1 semaine, du 26 nov. au 2 déc., un participant), évaluation, rapport final, démo |

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
5. **Questions facultatives (modèle v2, §6.8)** : pendant le pilote, deux notifications par jour
   (« Quick check: energy right now? », réponse en un geste, « Not now » possible) ; la ligne
   « Energy right now? » sur Home vient après le cours. Désactivables ; l'app marche sans.

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
Les éléments des questions du modèle v2 (notification, étape d'onboarding, réglage « Questions »,
« Reset what Harmony learned », check-ins dans My Data…) ne sont pas encore dessinés : ils passent
d'abord par le canvas (design v2 §5.4, TODO 6.6).

---

## 3. Décisions déjà prises (ne pas revenir dessus sans en parler)

| Décision | Pourquoi |
|---|---|
| Pas de caméra, pas de reconnaissance faciale | Trop contraignant, pas utilisable au lit ou en mouvement |
| Pas de musique générée | Besoin N2 |
| Pas d'*audio features* Spotify (valence, energy) | Supprimées pour les nouvelles apps le 27 nov. 2024 |
| Pas de modèle par utilisateur appris de zéro ; un ajustement personnel (2 nombres) appris sur l'iPhone à partir des réponses aux questions ; jour 1 = modèle commun (D1, 23 nov. 2026, reformule « pas d'entraînement sur chaque utilisateur ») | Mauvais premier jour ; on compare plutôt chacun à sa propre moyenne. Sans réponse, le décalage vaut exactement 0 : le premier jour reste celui du modèle commun. En simulation EmoPhone, les réponses font passer l'AUROC énergie de 0,555 à 0,666 (design v2 §2, §4.4) |
| Modèle entraîné sur EmoPhone | 282 personnes (297 participants-vagues), étiquettes « du moment », étudiants coréens |
| Sortie = plus/moins activé que d'habitude, jamais une émotion ; + un agrément **interne** (plus/moins agréable que d'habitude), utilisé seulement si l'utilisateur répond à la question d'agrément, jamais affiché comme émotion (D2, 23 nov. 2026) | Honnêteté, pas de prétention médicale. La valence tirée des seuls capteurs se replie sur l'énergie (corrélation 0,71) ; avec les réponses, 0,529 → 0,704 en simulation (design v2 §2, §4.2) |
| Entrées du modèle : heure, FC, pas, sommeil ; + réponses de l'utilisateur pour la couche personnelle (23 nov. 2026) | Choix d'équipe. Sur D-1, pas et sommeil n'apportent pas de gain mesurable (voir §6.5) ; on les garde, et on repasse au modèle heure + FC si les vagues D-2/D-3 et le pilote ne montrent rien. Le modèle commun v2 garde les mêmes signaux (fenêtres brutes de FC et de pas, §6.8) |
| Modèle final : 4 entrées (13 features v1), entraîné sur D-1 + D-2 + D-3 (TODO 2.13, 20 nov. 2026). Passe à 17 features **seulement** si le critère écrit avant les résultats (TODO 6.2) est satisfait (D3, 23 nov. 2026) ; critère satisfait (6.3), modèle v3 à 17 features livré le 25 nov. 2026 (6.4) | Features v1 : bat l'heure seule et heure + FC en validation croisée D-1 + D-2 (AUROC 0,563 contre 0,535 et 0,554) et sur D-3 tenue à part (0,576 contre 0,534 et 0,570) ; gain de pas + sommeil petit mais de même sens sur les deux évaluations (§6.5). Repli heure + FC toujours possible si le pilote (sommeil Apple Watch mesuré, pas estimé) ne montre rien. Les 4 valeurs brutes de v2 donnent un gain de valence robuste et un gain d'énergie incertain (design v2 §2) |
| HRV lue mais hors modèle | Absente d'EmoPhone ; sert seulement à l'explication |
| Météo retirée | Localisations EmoPhone anonymisées ; plafond mesuré à 0,53 AUROC pour tout effet partagé |
| Évaluation par personnes entières tenues à part ; couche personnelle : évaluation **chronologique** (chaque réponse prédite avec le passé seulement), hyper-paramètres réglés sur des personnes tenues à part (D8, 23 nov. 2026) | Un split aléatoire donne des résultats trop optimistes. Le modèle commun garde la validation croisée par personnes et une seule confirmation sur D-3 par changement |
| Un seul composant cloud : Cloudflare Worker | La clé API LLM ne doit jamais être dans l'app |
| MuSe v3 (Kaggle), scores en rang centile, ID Spotify en double retirés | Seule version avec un genre ; échelle brute trop resserrée ; ID partagés souvent faux (§5.2) |
| Spotify en mode développement (5 utilisateurs) | Le quota étendu est réservé aux entreprises ; l'app est un démonstrateur |
| Pas de leader | Décision d'équipe |
| Critère UC Irvine (écrit avant les résultats) | Sur les mêmes 5 groupes par participant d'UC Irvine, le modèle 13 features entraîné sur UC Irvine remplace le modèle EmoPhone seulement si (1) son AUROC moyenne dépasse d'au moins +0,02 celle du modèle EmoPhone (fixe, `model_params.json`), (2) sa balanced accuracy moyenne n'est pas plus basse, et (3) son AUROC moyenne dépasse celle de « heure seule » entraînée sur UC Irvine. Sinon on garde le modèle EmoPhone. |
| Décision 2.31 (23 nov. 2026) : scores LLM **utilisés** pour les morceaux absents de MuSe (MuSe → LLM → neutre), **par décision d'équipe malgré la règle non atteinte** | La référence MuSe est trop peu taguée pour juger le LLM (65 % des morceaux ont ≤ 3 tags ; sur les morceaux à 4–9 tags, l'accord monte à 0,39–0,44). Règle écrite avant le contrôle (Spearman ≥ 0,4 et MAE en centiles < 0,25, par score). Essai 1 (Claude Haiku 4.5, prompt v1) : Spearman 0,277 (énergie) et 0,336 (positivité), MAE en centiles 0,275 et 0,263. Essai 2 (Claude Haiku 5.5, prompt v2, nouveau tirage) : 0,279 et 0,324 ; 0,273 et 0,266. Essai 3 (Claude Haiku 5.5, prompt v3 avec 48 morceaux de référence, échantillon test jamais vu) : 0,258 et 0,316 ; 0,280 et 0,267. Les trois font pire que la valeur neutre (§7) |
| Décision du 23 nov. 2026 : **aucune pénalité** pour un score LLM dans le choix des morceaux (§8 ; l'ancienne règle mettait +0,1) | Toute pénalité fixe ne laissait que des morceaux MuSe dans les files : sur une vraie bibliothèque (2 045 titres, 233 dans MuSe, §5.2), un morceau MuSe est presque toujours à moins de 0,01 de la cible. Simulation (233 MuSe, 1 812 LLM, 2 000 files) : 0 % de morceaux LLM avec une pénalité de 0,1, 0,05 ou 0,02 ; 0,4 % avec 0,01 ; 90,5 % sans pénalité |
| Décision 5.8/5.9 (22 nov. 2026) : modèle EmoPhone gardé, UC Irvine non intégré | Le critère ci-dessus est satisfait (+0,044 d'AUROC, +0,030 de balanced accuracy, +0,028 sur « heure seule »), mais il ne teste que sur UC Irvine, le terrain du modèle UCI. Lu dans les deux sens, chaque modèle ne gagne que sur ses propres données : sur EmoPhone D-3, le modèle EmoPhone (D-1 + D-2) fait 0,576 contre 0,528 pour UCI (§6.5). EmoPhone reste plus proche de nos utilisateurs (étiquettes du moment, étudiants coréens) et a la meilleure AUROC sur ses propres données (0,563–0,576 contre 0,538). Sur UCI, la FC n'apporte rien et le sommeil estimé n'est pas corrélé au sommeil Oura mesuré (−0,001). |
| **Modèle d'état v2 (23 nov. 2026)** : A « modèle commun soigné » + B « Harmony apprend de toi » retenus ; C (HRV, respiration, température, lumière, bruit, modèles plus gros) écarté. Design : `docs/superpowers/specs/2026-11-23-modele-etat-v2-design.md` ; preuves : `docs/research/2026-11-23-modele-etat-v2/` | Plus de capacité ou plus d'entrées montre ne change presque rien ; les réponses de l'utilisateur sont le seul levier à gain important (design v2 §2–§3). Lignes D1–D9 ci-dessus et ci-dessous |
| D4 : couche personnelle en mode **ombre** pendant le pilote (calculée et journalisée, ne pilote pas la file ; toutes les files en stratégie S1) ; mode **actif** pour la démo finale | Mesure une vraie courbe d'apprentissage sans changer les files du pilote (design v2 §4.5, §4.6) |
| D5 : consentement écrit du pilote incluant les questions, les notifications et les journaux locaux ; export limité aux agrégats et aux paires (probabilité, étiquette, jour d'utilisation) | Les check-ins sont traités comme des données de santé (§11) ; App Store 5.1.3 (design v2 §6, §15) |
| D6 : pas de smileys dans les questions | Zone grise « émotion nommée » (design v2 §5.1) |
| D7 : 3 stratégies de file par situation, S1 « progressif » (règle §8 actuelle), S2 « demi-pas », S3 « correspondance longue » ; à faire valider par le customer | Définies pour être implémentables telles quelles ; toutes partent de `e0` et respectent les règles §8 (design v2 §4.6) |
| D9 : questions facultatives, désactivables, jamais bloquantes (N1, NFR5 ≤ 2 taps) | Besoin N1 « zéro effort » ; l'absence de réponse n'est jamais une réponse « basse » (design v2 §5.3) |
| Périmètre du pilote « collecte seule » : couche personnelle en ombre, énergie seulement, 2 notifications/jour, aucun nouvel écran sur Home, file inchangée ; bandit, état 2-D et ligne énergie sur Home après le cours | Charge avant le pilote du 26 nov. (~3–4 jours après la simulation 6.5) ; le pilote mesure quand même la courbe commune vs personnelle sur de vrais utilisateurs Apple Watch (design v2 §15) |
| Pilote à une personne : Clément (décision de Clément, 23 nov. 2026), **1 semaine, du 26 nov. au 2 déc. 2026, avec les données de la montre tous les jours** (décision de Clément, 24 nov. 2026 : le projet se termine le 4 déc.) ; protocole et consentement : `docs/pilot-protocol.md` (TODO 4.1) | Reste dans les 5 comptes Spotify ; appareil et compte déjà en place, donc 4.2 et 4.3 sans objet. Test de faisabilité seulement : participant développeur, pas de file de comparaison, intervalles par bootstrap sur les **jours** et non sur les personnes ; plan d'analyse fixé avant les données |
| Pilote sur le modèle commun v3 (17 features + valence, TODO 6.4), figé du 26 nov. au 2 déc. (décision de Clément, 25 nov. 2026) ; remplace le report de l'entraînement final et du port Swift au 2 déc. | v3 a passé le critère 6.2 ; la règle de gel du design v2 (§8) l'admet dans le build du pilote s'il est prêt avant le 26 nov., fixtures golden comprises |
| LifeSnaps (Fitbit Sense, CC BY 4.0) = test externe secondaire seulement, jamais dans l'entraînement ; facultatif, après le cours (§5.5) | Signaux de nuit sans gain, effet de l'heure inversé par rapport à EmoPhone (design v2 §2) |

---

**Critères 6.2, fixés avant les résultats de WP-A1 (design §9).** Sur les mêmes
réponses, comparer v1 (mode corps si `z_hr_30` connu) et v2 (mode corps si
`raw_hr_30` connu), avec repli heure seule. Noter aussi les scores des modèles
complets sur toutes les réponses. Sur les cinq groupes déterministes D-1 + D-2,
l'AUROC énergie v2 doit être ≥ v1 − 0,002. Au test unique D-3, elle doit être
≥ v1 et ≥ heure seule + 0,02. Le modèle valence remplace la constante s'il
dépasse l'heure seule valence d'au moins 0,01 en CV et sur D-3.

**Règle de sélection 6.5, fixée avant les résultats (25 nov. 2026, D8).** `T` et `τ_E` sont
choisis par validation imbriquée sur le modèle commun livré (v3, `--v2`), 2 réponses par jour,
3 graines, étiquette à 3 niveaux. Grille : `T` ∈ {1, 2, 4} jours, `τ_E` ∈ {0,5 ; 1 ; 2 ; 3}.
Dans chacun des 5 plis externes, la paire retenue est celle de plus petite log-loss énergie
sur des plis internes formés des seuls participants d'entraînement. On adopte la paire retenue
dans le plus de plis externes (égalité : plus petite log-loss interne moyenne), sauf si sa
log-loss externe moyenne n'est pas inférieure à celle du réglage nominal (`T` = 2, `τ_E` = 1) :
on garde alors le nominal. `τ_V` reste 1,5 (pilote énergie seulement).

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

**Modèle d'état v2 (décidé le 23 nov. 2026, §3)** : trois modèles, tous sur l'iPhone. (1) Le modèle
commun « corps » ci-dessus, figé, donne l'estimation du jour 1 ; (2) une couche personnelle (deux
décalages, énergie et agrément) apprise des réponses aux questions en un geste, qui oublie en
~2 jours ; (3) un bandit de file qui choisit entre 3 stratégies selon « Did it fit? », les skips et
les likes (après le pilote). Le Worker est inchangé. Schéma et détails : design v2 §4.

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
| Modèle v2 (noms laissés au builder) : check-ins et notifications, couche personnelle, rang `e0`, bandit de file | questions facultatives, décalages `b_E`/`b_V`, départ de file, choix de stratégie (design v2 §4–§6, TODO Phase 6) | FR7, FR8, FR13, NFR5 |

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

### 4.5 Sans montre, sans réseau, sans Spotify (TODO 3.22)

Règle : l'app ne plante pas et dit ce qui se passe en une phrase (`Core/UserMessage.swift`), jamais
l'erreur brute (qui reste dans la console). Hors ligne → « No internet connection. Check it and try
again. » ; `429` trop long → « Spotify is busy. Try again in a minute. » ; le reste → « Something
went wrong. Try again. ». Essais du 23 nov. sur l'iPhone 16 de Clément (build Debug, console lue
par `devicectl`) :

| Cas | Comment | Ce que montre l'app |
|---|---|---|
| Sans montre | lecture de la FC coupée dans Santé | badge « Watch not synced », file en 0,33 s en mode heure seule, raison limitée au moment de la journée |
| Données Santé illisibles | test unitaire (`CurrentStateTests`) | même chose que sans montre (`CurrentState.computeOrTimeOnly`), au lieu de « Can't start the queue » |
| Sans réseau | mode avion, Wi‑Fi coupé | la file s'affiche (données locales), puis « Can't play this » (`-1009` sur `POST /me/playlists`) ; ⟳ de Library et « Import again » : « Something went wrong » + message hors ligne ; retour du réseau → la lecture repart |
| Sans Spotify | app Spotify déchargée (Réglages › Stockage) | « Can't play this » ; « Open Spotify » ouvre open.spotify.com dans Safari (vu par Clément, pas dans la console) |
| Premier import impossible | code relu, pas reproduit sur l'iPhone | « Loading your library » montre « The import did not finish. » + le message et « Try again » au lieu d'une barre figée |

Textes nouveaux (les trois messages ci-dessus, « The import did not finish. … » et le bouton
« Try again » de l'écran de lancement) relus par Cyprien le 23 nov.

---

## 5. Les données

### 5.1 EmoPhone (entraînement principal)
- **Source** : Harvard Dataverse, doi:10.7910/DVN/QGRVU8 ; article arXiv:2609.16581 (KAIST, 2026).
- **Accès** : accordé par les auteurs pour ce projet. **Utilisation autorisée, redistribution interdite.**
  Les fichiers restent sur les ordinateurs de l'équipe, jamais sur GitHub, jamais dans l'app,
  jamais collés dans un chat.
- **Contenu** : 3 vagues (D-1 2020, D-2 2021, D-3 2022), ~4 semaines chacune, étudiants d'une
  université coréenne, téléphones Android + **Fitbit Inspire HR**. 297 enregistrements
  participant-vague retenus, soit **282 personnes** distinctes (EmoPhone v2, §3.1).
- **Fichiers d'une vague** (vérifié sur D-1) : `EsmResponse.csv` (réponses d'humeur),
  `UserInfo.csv` (profil, questionnaires — **ne pas utiliser**, données sensibles hors sujet),
  `Sensor/D1_Sensor_Pxxx.tar.gz` (un CSV par capteur et par participant).
- **Ce qu'on utilise** : `Fitbit-HeartRate.csv` (1 mesure / 5 s), `Fitbit-StepCount.csv`
  (pas par minute, minutes sans pas absentes), et dans `EsmResponse.csv` : `pcode`,
  `actualTriggerTime` (ms UTC), `arousal` (−3..+3), `stress`.
- **Pièges connus** :
  - horodatages en ms **UTC** → heure locale = +9 h (Corée) ;
  - **pas de sommeil mesuré** et **pas de HRV** dans les données publiées (une ceinture Polar H10 a
    servi sur des sous-périodes de D-1/D-2, sans être publiée : EmoPhone v2, annexe A.3.2) ;
  - localisation brouillée ; la colonne `altitude` de `Location.csv` semble contenir de vraies
    latitudes → **ne jamais l'utiliser** (et le signaler aux auteurs) ;
  - D-3 : stress et dérangement notés 0..+6 au lieu de −3..+3, et 8 adjectifs en plus (items
    propres à EmoPhone, pas le PANAS/PANAS-X d'origine : EmoPhone v2, §3.4) ;
  - 10 participants de D-1 ont des fichiers capteurs mais aucune réponse (exclus au contrôle qualité) ;
  - la montre n'était pas portée sur ~34 % des nuits.

### Différences entre vagues (TODO 1.35)
Exploration du 10 nov. 2026 : D-1/D-2/D-3 ont respectivement 10 259/21 042/21 838 réponses
et 92/99/106 participants répondants. D-2 ajoute `intendedTriggerTime`, `valenceChange` et
`arousalChange`, remplaçant `change` ; D-3 ajoute `intendedTriggerTime` et huit adjectifs
(happy, relaxed, cheerful, content, sad, anxious, depressed, angry ; items propres à EmoPhone, pas
le PANAS d'origine), et ne contient plus
attention, mental, duration ni les items de changement. Valence et arousal restent sur −3..+3
dans les trois vagues. En D-3, stress, dérangement et les huit adjectifs sont sur 0..+6.

Les archives capteurs sont au nombre de 102/112/106 ; 10/13/0 ont un fichier capteur mais aucune
réponse, et 0/0/0 participants répondants n'ont pas d'archive. Les colonnes Fitbit restent
`timestamp,value`. D-2 ajoute `KeyEvent.csv`, `Proximity.csv` et quatre fichiers `Fitness-*` ;
D-3 a `KeyEvent.csv` et les quatre `Fitness-*` (non vides), mais ni `Proximity.csv` ni `Light.csv`
(correction du 23 nov. 2026, inventaire des 106 archives D-3 ; archive de recherche v2, rapport 1).
Les médianes des
médianes d'intervalle FC sont 0,08 min (101 participants avec mesures), 0,08 min (77) et 0,08 min
(106), soit environ 5 s. Les réponses couvrent le 8 fév.–2 avr. 2020, le 7 déc. 2020–27 janv. 2021
et le 24 nov. 2021–11 janv. 2022 (heures KST, timestamps en ms UTC).

### Identité des participants entre vagues (TODO 1.36)
L'article dit « All three cohorts were drawn from the same university student population »
(annexe A.2). Les `pcode` sont numérotés par vague ; 82/78/86 codes sont communs à D-1/D-2, D-1/D-3
et D-2/D-3, sans permettre d'identifier les mêmes personnes. **Réponse (EmoPhone v2, §3.1 et
annexe C.3, relevée le 23 nov. 2026)** : 282 personnes distinctes, dont 14 qui reviennent (13 dans
deux vagues, une dans les trois), identifiées par une table d'inscription non publiée ; les retirer
change l'AUROC entre vagues d'au plus 0,0022. On garde donc l'identifiant `vague + pcode`
(ex. `D1_P050`) pour tout entraînement combinant des vagues.

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
Le fichier fait 14 155 776 octets après `VACUUM`, donc dépasse 10 Mo. Il n'est pas versionné :
`data/` est ignoré par Git. Après téléchargement du CSV avec `python ml/muse_download.py`,
`python ml/muse_build.py` régénère cette base localement. La tâche est validée sur ce critère de
reproductibilité locale ; le dépassement de 10 Mo reste à réduire si la taille devient bloquante.
Le stockage `WITHOUT ROWID` avec `match_key` comme clé primaire et une taille de page de 16 Kio
a réduit le fichier de 15 532 032 octets (table avec rowid, page 4 Kio) à 14 155 776 octets,
sans suffire. Une compression exigeant une extension SQLite ou une représentation qui modifie le
schéma nécessite une décision d'équipe avant d'être retenue.

**Dans l'app (TODO 2.32, 23 nov. 2026)** — décision : la table est **versionnée** dans
`app/Harmony/Resources/muse.sqlite` (14 155 776 octets, licence CC BY 4.0, crédit dans `README.md`
et `app/README.md`), pour que tout clone construise l'app avec MuSe ; `data/` reste ignoré. Pour la
régénérer : `python ml/muse_build.py --out app/Harmony/Resources/muse.sqlite` (même contenu que la
copie de `data/muse/`, vérifié par empreinte des lignes). Lecture seule avec SQLite
(`Core/Scoring/MuseCatalog.swift`) : d'abord `spotify_id` (jamais un ID vide), puis `match_key`
calculée par `Core/Scoring/SongKey.swift`, portage Swift de `ml/normalize.py`. Vérifié : mêmes clés
que Python sur les 31 cas partagés, sur les 89 269 lignes MuSe et sur chaque point de code Unicode
(titre `a<c>b`). Le *case folding* de Foundation diffère de `casefold` de Python sur 181 points de
code (cherokee, variantes cyrilliques U+1C80–U+1C88) : corrigé dans `SongKey`.
**Apostrophes (décision du 23 nov. 2026)** : la clé (Python comme Swift) change l'apostrophe droite
`'` en espace mais l'apostrophe typographique `’` en `'`, donc « Don’t » ne retrouvait pas « Don't »
(MuSe : 6 595 titres avec `'`, 62 avec `’`). Règle : l'app cherche **les deux graphies, la droite
d'abord** (celle de la plupart des morceaux MuSe), puis la typographique
(`MuseCatalog.titleKeys`) ; si MuSe a le même morceau sous les deux graphies, la droite gagne. La
clé de `ml/normalize.py` et la table ne changent pas : les changer modifierait 85 clés et
fusionnerait 13 lignes, dont 2 dans le vivier des 48 morceaux de référence du prompt v3, et
rendrait les tirages des essais LLM (§7) non reproductibles.

**Couverture MuSe d'une vraie bibliothèque (TODO 2.35, 23 nov. 2026)** — iPhone 16, compte
Spotify de Clément, écran Debug › Song scores, après un import complet (2 045 titres : aimés + 50 top
+ 50 récents) :

| | Titres | Part |
|---|---|---|
| MuSe par ID Spotify | 102 | 5,0 % |
| MuSe par titre + premier artiste | 131 | 6,4 % |
| **MuSe, total** | **233** | **11,4 %** |
| LLM (Worker) | 1 812 | 88,6 % |
| Neutre / non noté | 0 / 0 | 0 % |

Premier scoring en **158 s** (MuSe < 1 s, puis ~37 requêtes de 50 au Worker, ~4,3 s chacune, à la
suite), aucune erreur. La couverture est faible : MuSe vient de tags Last.fm (surtout des morceaux
occidentaux anciens), donc l'essentiel des scores de l'app viendra du LLM (§7, décision finale). Les
scores sont gardés : les ouvertures suivantes n'envoient que les nouveaux titres. Conséquences :
le premier scoring doit tourner en arrière-plan pendant l'onboarding (3.16) ; avec 50 requêtes par
jour (§7.1), soit 2 500 titres pour le LLM, une bibliothèque de plus de ~2 800 titres (à 88,6 % hors
MuSe) finit d'être notée le lendemain. Mesure
faite sur une seule bibliothèque (décision du 23 nov.), avant la recherche des deux graphies
d'apostrophe (ci-dessus) : son effet sur cette bibliothèque n'est pas mesuré, et les titres déjà
notés par le LLM gardent leur score (cache).

### 5.3 UC Irvine (test secondaire, autre marque)
- Labbaf et al., Data in Brief 54 (2024), Dryad doi:10.7280/D1WH6T. 21 étudiants, Samsung + Oura.
  Les données brutes et les tables dérivées restent locales dans `data/`, même si le dépôt est CC0.
- Copie présente dans `data/uci/ifh_affect/` : 24 répertoires `par_N`. Agrégats du 21 nov. 2026,
  `python ml/uci_explore.py` : 24 participants avec `ema/daily.csv`, Samsung PPG et pédomètre ;
  23 avec `oura/sleep.csv` (24 avec `oura/heart_rate.csv`). EMA : 3 949 réponses, médiane 180 par
  participant, du 20 janv. 2020 au 20 mai 2022 UTC. Les 3 949 réponses ont les six items
  d'activation requis. L'article/README annonce 21 étudiants, mais les fichiers exploitables
  apparaissent dans 24 IDs `par_N` ; l'écart n'est pas expliqué. Les groupes d'évaluation utilisent
  ces 24 IDs distincts.
- EMA retenue : `ema/daily.csv`, `submission_timestamp` (epoch ms UTC) et six PANAS
  `Active, Alert, Excited, Enthusiastic, Jittery, Nervous`, échelle 0–100 ; les 14 autres PANAS,
  les deux inquiétudes, `start_timestamp` et les champs libres ne sont pas des features. La question
  porte sur l'humeur ressentie « today », une fois par jour. `ema/weekly.csv` est ignoré.
- FC retenue : Samsung `samsung/ppg.csv`, colonnes `timestamp, hr` (ms UTC, battements/minute),
  valeurs conservées seulement dans [30, 220] ; environ 8,3 % sont hors de cette plage. Intervalle
  médian échantillonné entre timestamps : 25,5 s. La FC Oura `oura/heart_rate.csv`
  (`timestamp, heart_rate, heart_rmssd`, ms UTC, battements/minute et ms) ne couvre que le sommeil ;
  elle est fusionnée à la série Samsung, puis ramenée à une moyenne par minute. L'option Samsung
  `hrv_1min.csv` (`hrv_meannn`, ms) est ignorée. Les mesures Oura de FC restent une seule série de
  FC pour représenter la montre portée.
- Sont aussi ignorés : `samsung/hrv_5min.csv`, `awake_times.csv`, `imu.csv`, `pressure.csv`,
  `oura/activity.csv`, `activity_level.csv`, `readiness.csv` et `sleep_hypnogram.csv`. Le RMSSD Oura
  ne rentre pas dans les features.
- Couverture agrégée : part moyenne des dates locales de chaque participant ayant au moins une
  mesure dans la plage 08–24 h / 00–06 h : PPG 0,975 / 0,650 ; HRV 1 min 0,528 / 0,351 ; FC Oura
  0,313 / 0,511. C'est la présence d'au moins un point par date dans la plage, pas une fraction
  des minutes couvertes. Les fichiers Oura contiennent 3 997 périodes ; une période existe pour
  3 061 des 3 559 nuits avec une réponse EMA (0,860).
- Pas : `samsung/pedometer.csv`, `timestamp` (ms UTC) et `num_total_steps` (cumul depuis le
  redémarrage) ; les différences négatives sont traitées comme un redémarrage. Sommeil mesuré de
  contrôle seulement : `oura/sleep.csv`, `date` (veille du réveil), `total` (secondes) ; le
  hypnogramme et les autres champs Oura ne servent pas aux features. Le sommeil des features reste
  estimé par `features.sleep_threshold` et `features.participant_features`, comme à l'entraînement.
- Fuseau adopté : `America/Los_Angeles`, décalage calculé à chaque horodatage et heure d'été
  comprise, puis conversion vers les coordonnées attendues par `features.py` (UTC−9 h). Le pic
  d'EMA locale est 20 h (692 soumissions), puis 0–2 h ; la FC PPG moyenne échantillonnée est
  92,3 bpm entre 00–06 h contre 93,6 bpm entre 08–24 h, un creux nocturne faible ; la présence
  relative de FC Oura est plus forte la nuit que le jour. Ces indices agrégés sont cohérents avec
  la Californie du Sud, mais la preuve par FC est faible, le fuseau n'est pas indiqué dans le
  README et reste une hypothèse. Les EMA et capteurs passent en
  coordonnées LA pour le calcul des features ; la colonne de sortie `t` garde l'epoch UTC d'origine.
- Licence : la [politique de réutilisation Dryad](https://dev.datadryad.org/help/guides/reuse)
  indique CC0 pour ses jeux de données ; la page du DOI `10.7280/D1WH6T` n'a pas pu être ouverte directement. `daily_feeling` n'est fourni que sur
  demande pour protéger la vie privée ; il n'est jamais lu. Rien de `data/` n'est ajouté à Git.
- Table UC Irvine v1 (TODO 5.5), 21 nov. 2026, `.venv/Scripts/python.exe -u
  ml/uci_build_features.py`, Python 3.12.10 : 3 949 lignes / 24 participants. Nuits connues :
  0,192 ; valeurs inconnues : `z_hr_30` 0,799, `zb_hr_30` 0,889, `z_log_steps_30` 0,293,
  `z_sleep_min` 0,883, `hours_since_wake` 0,808. Contrôle sur 1 074 nuits avec mesure Oura :
  écart médian estimé moins mesuré −344,5 min ; corrélation −0,001.
- Une première table locale a été écartée avant évaluation : les capteurs étaient convertis en
  heure LA, mais pas l'instant EMA passé aux features. La conversion EMA est corrigée dans le
  chargeur ; la table et le cache utilisés ensuite ont été reconstruits en Python 3.12.
- Doublons entre IDs (TODO 5.9, 22 nov. 2026), `uci_explore.duplicate_ids()` (lancé aussi à la
  fin de `python ml/uci_explore.py`), comptes seulement : 0 paire d'IDs avec un fichier identique
  pour `ema/daily.csv` (24 fichiers), `oura/sleep.csv` (23), `oura/heart_rate.csv` (24) et
  `samsung/pedometer.csv` (24) ; 0 paire d'IDs partageant un instant de soumission EMA. Rien ne
  montre qu'une même personne apparaisse sous deux IDs (pas de fuite entre groupes) ; l'écart
  21 étudiants / 24 IDs reste inexpliqué. Note pour une reprise éventuelle : les 3 997 périodes
  Oura ont un `bedtime_end_timestamp`, donc un sommeil et un réveil mesurés seraient utilisables.

### 5.4 Ce qui ne doit jamais aller sur Git
Données brutes EmoPhone/UC Irvine/LifeSnaps, tables de features dérivées par participant, clés API,
fichiers `.env`, `.dev.vars`, données de santé réelles d'un membre (check-ins compris). Les **résultats agrégés** sont autorisés. Le **modèle entraîné** (quelques coefficients) est
prévu dans l'app et sur GitHub : les auteurs d'EmoPhone ont confirmé par écrit que c'est autorisé (TODO 2.14b, novembre 2026 ; réponse conservée par l'équipe, hors dépôt).

### 5.5 LifeSnaps (test externe secondaire, facultatif)
- **Source** : Zenodo 7229547 (v4), **CC BY 4.0** ; 71 participants en Europe, Fitbit Sense,
  humeur choisie dans une liste 3 fois par jour (5 028 réponses utilisables, 63 participants).
- **Usage décidé (§3, 23 nov. 2026)** : test externe secondaire seulement, jamais dans
  l'entraînement, facultatif et après le cours ; partie FC et partie heure seule notées séparément.
- **Déjà mesuré** (tour de recherche du 23 nov. 2026) : les signaux de nuit n'apportent rien
  (−0,001 à −0,004 d'AUROC) ; le modèle EmoPhone figé fait 0,471 (effet de l'heure inversé),
  ses termes FC seuls 0,530. Détails : `docs/research/2026-11-23-modele-etat-v2/notes/tour2/lifesnaps.md`.
- Téléchargement : `docs/research/2026-11-23-modele-etat-v2/scripts/lifesnaps/download.sh`, en
  remplaçant `DEST` par `data/lifesnaps/` (ignoré par Git) ; ne rien exécuter depuis le dossier
  téléchargé.

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

**UC Irvine (TODO 5.4, 21 nov. 2026)** : pas d'item arousal. Score d'activation = moyenne des
six items `Active, Alert, Excited, Enthusiastic, Jittery, Nervous` (0–100), réponse gardée
seulement si les six sont présents ; `arousal_high` suit la même règle de moyenne personnelle via
`features.label_high`. L'instant t est `submission_timestamp`. Limite : cette humeur porte sur la
journée et est notée une fois par jour, contrairement à l'humeur du moment d'EmoPhone ; les
features restent calculées à l'instant de soumission. Aucun label de stress n'est construit.

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

### Features v1 (TODO 2.1–2.7)
Code : `ml/features.py` (constante `FEATURES`, ordre ci-dessus) ; table : `ml/build_features.py`.
Horodatages en ms UTC, heure locale = Corée (UTC+9). Chaque définition n'utilise que FC et pas
de la montre des 14 derniers jours, donc l'app peut la calculer à l'identique.

- **Heure** : `hour_sin`, `hour_cos` = sin/cos(2π · (heure + minutes/60) / 24) ; `weekend` = 1 le
  samedi et le dimanche.
- **Fenêtre** : une valeur à l'instant t utilise les données de `(t − w, t]`, w = 15, 30 ou 60 min.
- **FC rééchantillonnée** : première FC de chaque tranche de 5 min de l'horloge.
  `hr_w` = moyenne de ces FC dans la fenêtre ; valable dès 1 mesure, sinon inconnue.
  `hr_std_30` n'existe plus.
- **Pas** : `log_steps_w` = log(1 + pas de la fenêtre). Fenêtre sans pas mais avec ≥ 1 FC
  rééchantillonnée (montre portée) → 0 ; ni FC ni pas → inconnue.
- **Grille de référence** : points toutes les 30 min de 08:00 à 23:30 (32 par jour). À chaque point g
  on calcule les mêmes quantités `hr_15/30/60`, `log_steps_15/30/60` qu'à une réponse ; un point
  inconnu (montre non portée) n'entre pas dans la référence.
- **Référence personnelle** à t : moyenne et écart-type (n − 1) des valeurs de grille aux points
  `g ∈ [t − 14 j, t)` ; aucune donnée à ou après t. Prête seulement si ces valeurs viennent d'au
  moins **7 jours locaux distincts** ; sinon inconnue.
- **z-scores** : `z_hr_w` = (hr_w − moyenne) / écart-type, de même pour `z_log_steps_w`. Inconnu si
  la valeur ou la référence est inconnue, ou si l'écart-type vaut 0.
- **`zb_hr_30`** = (hr_30 − moyenne des points de grille du même bloc de 3 h (0–3 h, 3–6 h…)) /
  écart-type de toute la grille `hr_30`. La moyenne de bloc suit la même règle des 7 jours. Une
  réponse entre 00:00 et 05:59 n'a aucun point de grille dans son bloc → inconnue ; le bloc 06–09 h
  ne contient que les points de 08:00 et 08:30.
- **Sommeil (décision du 16 nov. 2026)** : EmoPhone n'a pas de sommeil mesuré, Python l'estime
  (l'app lit celui de l'Apple Watch). Estimateur inchangé par rapport à v0 : une minute est
  endormie si sa FC (moyenne de la minute) est présente, sans pas, et ≤ 1,05 × le 30e centile des FC
  par minute du participant **sur toute sa vague**. Ce seuil calibre l'estimateur (il remplace
  l'algorithme de la montre), ce n'est pas une référence personnelle : **exception assumée** à la
  règle des 14 jours. La nuit = la plus longue suite de minutes endormies (trous ≤ 30 min fusionnés) ;
  `sleep_min` = minutes endormies de ce bloc ; réveil = dernière minute endormie.
- **Nuit inconnue (comme `HealthSummaries.night` dans l'app)** : fenêtre 21:00 la veille → 12:00 du
  jour de la réponse. Pour une réponse avant 12:00, la fenêtre s'arrête aux minutes entières
  avant la réponse (rien après). Couverture = part des créneaux de 15 min, comptés depuis 21:00,
  contenant au moins une FC, sur la partie écoulée (le dernier créneau entamé compte). Nuit inconnue
  si couverture < 60 % ou aucun bloc ≥ 2 h : jamais 0.
- **`sleep_unknown`** = 1 si la nuit est inconnue, sinon 0. **`hours_since_wake`** = (minute de la
  réponse − minute du réveil) / 60 ; inconnu si la nuit est inconnue.
- **`z_sleep_min`** : référence = `sleep_min` des nuits **connues** (fenêtre entière) dont le jour de
  réveil est dans les 14 jours précédant le jour de la réponse ; au moins **5 nuits connues**, sinon
  inconnu.

**Tables v1 (TODO 2.5, 2.7, 19 nov. 2026)** — `python ml/build_features.py --data data/emophone
--out data/features --check-v0` ; tables locales `data/features/v1_D1.csv`… (jamais sur Git),
identifiant participant `vague + pcode` (ex. `D1_P050`).

| Ligne de sortie | D-1 | D-2 | D-3 |
|---|---:|---:|---:|
| Lignes / participants | 10 259 / 92 | 21 042 / 99 | 21 838 / 106 |
| Règles v0 : nuits comparées / écarts avec `explore_d1.py` | 1 653 / 0 | 3 006 / 0 | 3 144 / 0 |
| Règles v1 : réponses dont la nuit change de statut | 139 (2 → inconnue, 137 → connue) | 192 (2, 190) | 240 (3, 237) |
| Part de nuits connues, v0 → v1 | 0,660 → 0,674 | 0,410 → 0,419 | 0,784 → 0,794 |
| Part inconnue : `z_hr_30` / `zb_hr_30` / `z_log_steps_30` | 0,428 / 0,451 / 0,427 | 0,511 / 0,522 / 0,511 | 0,243 / 0,258 / 0,242 |
| Part inconnue : `z_sleep_min` / `hours_since_wake` | 0,608 / 0,326 | 0,695 / 0,581 | 0,377 / 0,206 |

Les nuits changent surtout d'inconnue à connue : les créneaux de 15 min tolèrent de courts trous
de FC. Beaucoup de z-scores sont inconnus parce qu'une référence demande 7 jours de données sur
des vagues d'environ 4 semaines ; ils seront imputés par la médiane d'entraînement (TODO 2.8).

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

**Features v1, validation croisée D-1 + D-2 (TODO 2.8–2.10)** — 20 nov. 2026, scikit-learn 1.5.2,
`python ml/train.py --features data/features`. 31 301 réponses, 191 participants (`vague + pcode`),
5 groupes par participant, mêmes groupes pour toutes les variantes ; modèle §6.3 (médiane,
standardisation, régression logistique, ajustées dans chaque groupe d'entraînement). Arousal ;
moyenne ± écart-type sur les 5 groupes. Chiffres refaits le 24 nov. avec les groupes déterministes
(TODO 6.1), mêmes AUROC sous Windows et sur Mac ; les anciens groupes donnaient 0,535 ± 0,017,
0,554 ± 0,012 et 0,563 ± 0,010.

| Entrées | Nombre | AUROC | Balanced accuracy |
|---|---:|---:|---:|
| Heure seule (référence) | 3 | 0,534 ± 0,014 | 0,507 ± 0,005 |
| Heure + FC | 7 | 0,554 ± 0,012 | 0,513 ± 0,006 |
| Heure + FC + pas + sommeil | 13 | 0,563 ± 0,008 | 0,538 ± 0,005 |

Les deux modèles battent l'heure seule. En v1, heure + FC est plus bas qu'en v0 (0,576/0,570 sur
D-1/D-2 seules) ; causes possibles, non mesurées une à une : FC à 1 mesure / 5 min, références sur les 14 jours précédents seulement, et
z-scores FC inconnus (puis imputés) pour 43–51 % des réponses. Pas et sommeil ajoutent +0,009
d'AUROC, du même ordre que l'écart entre groupes, mais +0,025 de balanced accuracy.

**Test unique sur D-3, vague tenue à part (TODO 2.11)** — 20 nov. 2026,
`python ml/train.py --features data/features --test-d3`, lancé une seule fois, code figé avant.
Chaque variante est ajustée sur tout D-1 + D-2 avec le même modèle fixe (aucun réglage), puis
évaluée sur D-3 : 21 838 réponses, 106 participants (aucun en commun, identifiant `vague + pcode`).

| Entrées | AUROC D-3 | Balanced accuracy D-3 |
|---|---:|---:|
| Heure seule (référence) | 0,534 | 0,511 |
| Heure + FC | 0,570 | 0,537 |
| Heure + FC + pas + sommeil | 0,576 | 0,541 |

Même ordre qu'en validation croisée : les deux modèles battent l'heure seule ; pas + sommeil
ajoutent +0,006 d'AUROC et +0,004 de balanced accuracy. Un seul chiffre par variante (pas
d'écart-type) ; rien n'a été ajusté après ce test.

**UC Irvine, test unique du modèle final (TODO 5.6)** — 21 nov. 2026,
`.venv/Scripts/python.exe ml/uci_eval.py`, Python 3.12.10, scikit-learn 1.5.2. 3 949 réponses,
24 IDs participants ; modèle final EmoPhone fixe depuis `model_params.json`. Les deux références
sont ajustées sur D-1 + D-2 + D-3.

| Modèle testé une fois sur UC Irvine | AUROC | Balanced accuracy |
|---|---:|---:|
| EmoPhone final fixe, 13 features | 0,496 | 0,499 |
| Heure seule, entraînée sur EmoPhone | 0,504 | 0,500 |
| Heure + FC, entraîné sur EmoPhone | 0,509 | 0,500 |

**UC Irvine, validation croisée (TODO 5.7)** — même commande et version, 3 949 réponses,
24 IDs, 5 groupes par participant ; moyenne ± écart-type entre groupes.

| Entrées, modèle entraîné dans les groupes UC Irvine | Nombre | AUROC | Balanced accuracy |
|---|---:|---:|---:|
| Heure seule | 3 | 0,510 ± 0,027 | 0,510 ± 0,023 |
| Heure + FC | 7 | 0,503 ± 0,015 | 0,500 ± 0,017 |
| Heure + FC + pas + sommeil | 13 | 0,538 ± 0,018 | 0,530 ± 0,014 |

**EmoPhone contre UC Irvine, mêmes groupes (TODO 5.8)** — modèle EmoPhone fixe évalué sur chacun
des mêmes 5 groupes tests que le modèle UC Irvine entraîné dans les 4 autres groupes ;
3 949 réponses, 24 IDs, 21 nov. 2026, scikit-learn 1.5.2.

| Modèle sur les mêmes groupes tests | AUROC moyenne ± écart-type | Balanced accuracy moyenne ± écart-type |
|---|---:|---:|
| EmoPhone fixe (`model_params.json`) | 0,494 ± 0,017 | 0,500 ± 0,012 |
| UC Irvine, 13 features | 0,538 ± 0,018 | 0,530 ± 0,014 |

Écarts UC Irvine moins EmoPhone : +0,044 d'AUROC et +0,030 de balanced accuracy ; le modèle
13 features dépasse aussi l'heure seule UC Irvine de +0,028 d'AUROC. Les trois conditions du
critère §3 sont satisfaites : verdict du critère « remplacer EmoPhone », sous réserve de la
validation en réunion d'équipe. Information hors critère : modèle 13 features ajusté sur les
3 949 réponses UC Irvine et testé sur EmoPhone D-3 (21 838 réponses, 106 participants) : AUROC
0,528, balanced accuracy 0,505.

**Lecture dans les deux sens (TODO 5.9, 22 nov. 2026)** — aucun nouveau calcul : chiffres repris
des tableaux ci-dessus (2.11, 5.8 et la ligne hors critère). Modèle 13 features, AUROC.

| Données de test | Modèle EmoPhone | Modèle UC Irvine |
|---|---:|---:|
| UC Irvine, mêmes 5 groupes | 0,494 (fixe, D-1 + D-2 + D-3) | 0,538 (4 autres groupes UCI) |
| EmoPhone D-3, tenue à part | 0,576 (D-1 + D-2) | 0,528 (toutes les réponses UCI) |

Chaque modèle ne gagne que sur ses propres données ; testé sur l'autre jeu de données, aucun ne
dépasse 0,53. Le critère §3 ne regardait que la ligne UC Irvine. EmoPhone a la meilleure AUROC
sur ses propres données (0,563 en validation croisée, 0,576 sur D-3, contre 0,538 pour UCI) et
ressemble plus aux utilisateurs de l'app ; sur UC Irvine, la FC n'ajoute rien (0,503 contre 0,510)
et le sommeil estimé n'est pas corrélé au sommeil Oura (§5.3). Décision : modèle EmoPhone gardé
(§3) ; l'Apple Watch et les étudiants de Hanyang restent une troisième population, que seul le
pilote mesurera (§13).

**Tour de recherche « modèle d'état v2 » (23 nov. 2026)** — D-1 + D-2 (31 301 réponses,
191 participants-vagues), 5 groupes de participants entiers de `ml/train.py`, réglages dans les
groupes d'entraînement seulement, **D-3 jamais ouverte**. Scripts et sorties agrégées :
`docs/research/2026-11-23-modele-etat-v2/` ; résumé : design v2 §2. Rien n'a changé dans l'app.
- **Mode « corps »** (`z_hr_30` connu, 51,6 % des réponses) : AUROC énergie 0,573 contre 0,524 pour
  l'heure seule sur les mêmes réponses.
- **Familles de modèles** (LR réglée, interactions, gradient boosting, MLP, ensembles) : aucune ne
  bat la régression logistique simple de plus que l'écart entre groupes. Sorties multiples :
  ≤ +0,004 ; stress pas mieux que l'heure seule (0,540 contre 0,543).
- **Nouvelles entrées** (contexte de journée, veille, FC au repos, METs, type d'activité) : ≈ 0
  chacune. Les **4 valeurs brutes** `raw_hr_30/60`, `raw_log_steps_30/60` (17 features, §6.8) :
  valence 0,559 (+0,017 ± 0,009, 5 groupes sur 5) ; énergie +0,008 ± 0,010 (4 sur 5 ; +0,003 en
  sélection imbriquée, non robuste).
- **`e0` par rang** : étale `e0` de 0,36–0,55 à 0,03–0,98, AUROC −0,005 ± 0,010 (non significatif).
- **Personnalisation simulée** (2 réponses/jour, étiquette « passé seulement ») : énergie 0,555 →
  0,666 sur la période (jours 4–7 : 0,640 contre 0,571 pour le modèle commun) ; agrément 0,529 →
  0,704. Simulé sur des étudiants EmoPhone : le gain arrivera probablement plus tard dans l'app.
- **Reproductibilité** : `train.folds()` redonne les mêmes moyennes (0,534 / 0,554 / 0,563) d'une
  machine à l'autre, mais pas les mêmes écarts-types (heure seule : 0,009 sur le Mac de Clément
  contre 0,017 dans le tableau du 20 nov.),
  car les égalités du nombre de réponses sont départagées par un tri non stable. À corriger avant
  toute nouvelle comparaison (TODO 6.1).

**6.1, CV v1 après fixation des groupes.** Tri des participants par nombre de réponses
décroissant puis identifiant croissant. Chaque groupe entier va au pli le moins chargé,
puis au pli de plus petit indice en cas d'égalité. Le test synthétique vérifie la même
affectation lorsque l'ordre des lignes est inversé. Sur les 31 301 réponses D-1 + D-2,
AUROC moyenne ± écart-type : heure seule 0,534 ± 0,014, heure + FC 0,554 ± 0,012,
modèle complet 0,563 ± 0,008. Reproduit à l'identique sur Mac le 24 nov. (Python 3.12.6,
scikit-learn 1.5.2), de même que les dix lignes CV de WP-A1 ci-dessous.

**6.3, confirmation WP-A1.** Les tables locales v2 contiennent 10 259 / 21 042 /
21 838 réponses (92 / 99 / 106 participants-vagues). La valence est lue dans
`EsmResponse.csv`, sans remise à l'échelle sur D-3. Cible valence : réponse
strictement supérieure à la moyenne de la personne. D-3 a été évaluée une fois.
Le contrôle des tables locales confirme les mêmes réponses et les mêmes valeurs
pour les 13 colonnes historiques, y compris les valeurs manquantes.
Chaque cellule donne AUROC / balanced accuracy. En CV, l'écart-type porte sur l'AUROC.

| Cible et variante | CV D-1 + D-2 | Confirmation D-3 |
|---|---:|---:|
| Énergie, heure seule | 0,5344 ± 0,0135 / 0,5070 | 0,5340 / 0,5109 |
| Énergie v1, complet | 0,5628 ± 0,0083 / 0,5382 | 0,5755 / 0,5409 |
| Énergie v1, règle app | 0,5604 ± 0,0121 / 0,5228 | 0,5780 / 0,5415 |
| Énergie v2, complet | 0,5716 ± 0,0175 / 0,5448 | 0,5970 / 0,5563 |
| Énergie v2, règle app | 0,5715 ± 0,0180 / 0,5346 | 0,5978 / 0,5557 |
| Valence, heure seule | 0,5332 ± 0,0101 / 0,5000 | 0,5263 / 0,5000 |
| Valence v1, complet | 0,5428 ± 0,0160 / 0,5139 | 0,5441 / 0,5188 |
| Valence v1, règle app | 0,5450 ± 0,0141 / 0,5135 | 0,5467 / 0,5182 |
| Valence v2, complet | 0,5560 ± 0,0175 / 0,5285 | 0,5555 / 0,5254 |
| Valence v2, règle app | 0,5561 ± 0,0172 / 0,5282 | 0,5552 / 0,5246 |

**Verdict §3.** Les deux candidats passent. Énergie v2 : +0,0111 en CV et +0,0198
sur D-3 par rapport à v1 en mode app, +0,0638 par rapport à l'heure seule sur D-3.
Valence : +0,0229 en CV et +0,0289 sur D-3 par rapport à l'heure seule.
Le fichier agrégé local `data/results/wp-a1.json` détaille les cinq plis.

**6.4.** Décision du 25 nov. (§3) : le pilote tourne sur le modèle v3, figé
pendant le pilote. Entraînement final, export Core ML, fixtures golden et port
Swift S9 sont faits avant le 26 nov.

### 6.6 Protocole d'évaluation (M2)
1. Validation croisée en 5 groupes par participant sur D-1 + D-2.
2. Test unique sur **D-3** (vague tenue à part), puis sur UC Irvine (TODO 5.6–5.8). Le critère
   écrit avant les résultats (§3) est satisfait sur les mêmes 5 groupes, mais lu dans les deux
   sens chaque modèle ne gagne que sur ses données (§6.5) : le modèle EmoPhone est gardé et
   UC Irvine n'est pas intégré à l'app (TODO 5.9, abandon explicite, 22 nov. 2026).
3. Toujours comparer à la référence « heure seule » ; si le modèle ne la bat pas, l'app
   utilise le mode heure seule.
4. 14 personnes reviennent d'une vague à l'autre, sans identifiant publié ; effet ≤ 0,0022 d'AUROC
   (§5.1). En combinant des vagues, grouper par `vague + pcode`.
5. **Modèle v2** (§6.8) : critères d'adoption écrits avant les résultats (TODO 6.2), D-3 une seule
   fois par changement, code figé avant. La couche personnelle est évaluée chronologiquement
   (chaque réponse prédite avec le passé seulement), jamais par un découpage aléatoire (§3, D8).

### 6.7 Export vers l'app
- Coefficients, moyennes, écarts-types, médianes d'imputation et **ordre des features** dans
  `model_params.json` ; modèle Core ML via coremltools (comme annoncé dans le rapport).
- **Fixtures « golden »** : Python génère des séries synthétiques (FC, pas, sommeil) +
  les features et la probabilité attendues ; un test Swift doit retrouver les mêmes valeurs
  (tolérance 1e-6). C'est la meilleure protection contre les écarts Python ↔ Swift.

**Fichiers produits (TODO 2.15–2.17, 20 nov. 2026)** — accord des auteurs d'EmoPhone obtenu (2.14b).
- `python ml/export.py --model data/models/state_model.joblib [--coreml]` → dans
  `app/Harmony/Resources/` : `model_params.json` (1,7 Ko : version, ordre des 13 features, médianes,
  moyennes, écarts-types, coefficients, intercept) et `StateModel.mlmodel` (pipeline entier :
  imputation par médiane de NaN, standardisation, régression logistique ; 13 entrées *double*, NaN =
  inconnu ; sorties `arousal_high` et `classProbability` {0, 1}). Écart Core ML (CPU) / scikit-learn
  sur 100 lignes de D-1 dont 50 avec valeurs inconnues : 1e-16 (< 1e-6).
- `python ml/make_fixtures.py` → `ml/fixtures/state_cases.json` : 10 cas synthétiques (graine fixe)
  avec séries FC/pas (minutes depuis `origin_ms`, UTC+9), features attendues (`null` = inconnu) et
  probabilité. Cas : jour de semaine, week-end, matin avant 12 h, soirée, nuit, historique < 7 jours,
  montre retirée 1 h, nuit inconnue, pas = 0 montre portée, FC constante (écart-type 0).
- **Sommeil dans les fixtures** : l'app lit le sommeil Apple Watch et ne l'estime pas ; chaque cas
  fournit donc les nuits estimées par Python (`nights`, `answer_night`). Le `FeatureBuilder` Swift
  (2.19) prend bien des `NightSummary` (confirmé) : nuit du jour coupée à t et nuits complètes des
  14 jours précédents, recalculées en mémoire par `HealthSummaries.night` (`CurrentState`).
- **FC et pas dans l'app (2.18)** : les `HourSummary` horaires ne permettent pas les fenêtres de
  15 min ni la grille de 30 min ; l'app relit donc les échantillons bruts FC et pas des 14 derniers
  jours (+ 1 h) à chaque calcul, en mémoire, sans les stocker (§11). Un échantillon de pas compte
  dans une fenêtre selon son début. Les tests Swift lisent `ml/fixtures/state_cases.json`, copié dans
  le bundle de test par une référence du projet Xcode (le fichier reste dans `ml/fixtures`).
- **Modèle « heure seule » (TODO 2.21, 22 nov. 2026)** : `train.py --final` ajuste aussi la
  variante heure seule (`hour_sin, hour_cos, weekend`, même modèle §6.3) sur les mêmes 53 139
  réponses D-1 + D-2 + D-3 ; `model_params.json` passe en version 2 avec un bloc `time_only` au
  même schéma (2,2 Ko). Le modèle 13 features est identique à la version 1 (mêmes valeurs, donc
  `StateModel.mlmodel` inchangé). C'est `prior(heure)` du rapport : l'app l'utilise sans
  référence ou sans FC sur 30 min. Les fixtures donnent sa probabilité attendue (`time_only_probability`).
- **Modèle v3 (TODO 6.4, 25 nov. 2026)** : `python ml/evaluate_v2.py --final data/results/wp-a1.json
  data/models/state_v3.joblib` (mêmes 53 139 réponses), puis `ml/export.py --model
  data/models/state_v3.joblib --coreml` : `model_params.json` version 3 (5,4 Ko : 17 features, blocs
  `time_only`, `valence` et `valence_time_only`) et `StateModel.mlmodel` (17 entrées, énergie
  seulement ; la valence est calculée depuis le JSON). Écart Core ML / scikit-learn sur 100 lignes
  de D-1 : 1e-16. Fixtures `state_cases.json` (version de modèle 3, probabilités de valence) et
  `rank_grid_cases.json` régénérées ; tests Python et Swift verts (240 tests Swift).
- Changer `features.py` ou réentraîner = relancer ces trois commandes.

### 6.8 Modèle d'état v2 (contrat v3 en vigueur depuis le 25 nov. 2026)

Source détaillée : `docs/superpowers/specs/2026-11-23-modele-etat-v2-design.md` (formules, données,
paquets de travail) ; tâches : TODO Phase 6. Ce paragraphe résume ce qui touche le contrat §6.

- **Le contrat en vigueur est v3** (17 features ci-dessous) : critère 6.2 satisfait en 6.3, modèle
  réentraîné, exporté et porté en Swift en 6.4 (25 nov. 2026, §6.7). Il était livré avant la
  couche personnelle : aucun décalage personnel à remettre à 0.
- **Features v2 : 17 features** = les 13 de v1 puis, dans cet ordre, `raw_hr_30`, `raw_hr_60`,
  `raw_log_steps_30`, `raw_log_steps_60`. `raw_hr_w` = `hr_w` de v1 **avant** z-score (moyenne des FC
  rééchantillonnées de `(t − w, t]`, valable dès 1 mesure, sinon inconnue) ; `raw_log_steps_w` =
  `log_steps_w` de v1 avant z-score (0 si montre portée sans pas ; inconnu si ni FC ni pas). Mêmes
  règles d'inconnu et d'imputation par médiane d'entraînement que v1.
- **Mode « corps » en v2** : corps si `raw_hr_30` est connu (au moins une FC rééchantillonnée dans
  les 30 dernières minutes), sinon heure seule ; les z-scores inconnus sont imputés par la médiane.
  En v1, la règle reste « corps si `z_hr_30` connu » (§6.7). Le champ `estimateMode` suit la
  règle du modèle livré.
- **A priori d'agrément** `z_V` : par défaut la constante `logit(0,566)` (taux de base de « valence
  au-dessus de la moyenne personnelle » sur D-1 + D-2) ; un modèle valence (bloc `valence` de
  `model_params.json`) seulement s'il passe son critère (6.2). Jamais utilisé seul pour la file.
  Il suit la règle adoptée en 6.3 (« règle app ») : modèle valence si `raw_hr_30` est connu,
  sinon son modèle heure seule (bloc `valence_time_only`, même schéma que `time_only`). Les
  fixtures v3 donnent `valence_probability` et `valence_time_only_probability`.
- **`e0` sans réponse** : rang de la prédiction courante parmi les prédictions de la même personne
  sur la grille de référence (§6.4 : toutes les 30 min, 08:00–23:30, 14 jours précédents, montre
  portée), dès 32 points de grille ; sinon la probabilité brute (design v2 §4.3).
- **Couche personnelle** : un décalage de logit `b_E` (et `b_V` si l'utilisateur répond à
  l'agrément) appris des check-ins des 14 derniers jours, oubli de constante ~2 jours, a priori
  gaussien ; `b = 0` sans réponse. Étiquette d'un check-in = réponse au-dessus de la moyenne des
  réponses de la personne sur les 14 jours précédents (au moins 5). Formule : design v2 §4.4.
  **Hyper-paramètres décidés en 6.5 (25 nov. 2026) : `T` = 2 jours, `τ_E` = 2, `τ_V` = 1,5, seuil de
  5 réponses** ; fixtures golden issues de la simulation de la règle exacte de l'app.
- **Protocole WP-B0 (6.5)** : 5 plis extérieurs D-1 + D-2, 3 graines et tirage
  de 1, 2 ou 4 réponses ESM par jour. Une prédiction est évaluée sur une réponse
  étiquetée à partir des seules réponses tirées dans les 14 jours précédents.
  Le scénario à 3 niveaux arrondit vers −2, 0 ou +2, avec les égalités vers 0.
  Les réponses EmoPhone ne renseignent ni la lecture d'une file ni la fin de
  lecture. L'exclusion pendant et jusqu'à 60 min après une file est donc hors simulation.
  Fixtures synthétiques : `ml/fixtures/personal_layer_cases.json` (dont les bornes de la
  fenêtre de 14 jours et les réponses sans étiquette), `ml/fixtures/rank_cases.json`
  (percentile) et `ml/fixtures/rank_grid_cases.json` (`python ml/make_rank_fixtures.py` :
  valeurs de grille → lignes scorées avec la référence à t → probabilités selon la règle de
  mode → `e0`).
- **Résultats WP-B0** (modèle commun v3, `T` = 2, `τ_E` = 2, 25 nov. 2026). AUROC poolée, énergie
  à trois niveaux, 2 réponses/jour (24 166 prédictions étiquetées sur trois graines). À partir de cinq réponses
  étiquetées disponibles, la variante « rang puis personnel » utilise la
  probabilité personnelle. Cette variante est simulée à titre de comparaison.
  Un point de grille compte comme montre portée s'il a une FC dans ses 30 min
  (des pas seuls ne suffisent pas, §6.4).

  | Jours | Modèle commun | Rang | Personnel en ombre | Rang puis personnel |
  |---|---:|---:|---:|---:|
  | 1–3 | 0,511 | 0,517 | 0,511 | 0,517 |
  | 4–7 | 0,534 | 0,549 | 0,736 | 0,645 |
  | 8–14 | 0,516 | 0,540 | 0,820 | 0,817 |
  | 15+ | 0,507 | 0,532 | 0,810 | 0,808 |
  | Ensemble | 0,514 | 0,536 | 0,797 | 0,776 |

  À 1 / 2 / 4 réponses par jour, AUROC personnelle : 0,757 / 0,797 / 0,815 à
  trois niveaux et 0,622 / 0,657 / 0,682 à sept (avant 6.5, modèle v1 et `τ_E` = 1 :
  0,732 / 0,788 / 0,811 et 0,616 / 0,654 / 0,681). Avec 2 réponses par jour,
  l'agrément personnel donne 0,705 avec le modèle valence et 0,701 avec la
  constante. Les cibles quantifiées et celles à sept niveaux diffèrent.
  Ces chiffres décrivent des réponses EmoPhone simulées.

  **Choix de `T` et `τ_E` (TODO 6.5, 25 nov. 2026)**, selon la règle fixée avant les résultats
  (§3) : `python ml/simulate_wp_b0.py --v2 --nested data/results/wp-b0-nested.json`. Les plis
  internes, faits des seuls participants d'entraînement, choisissent `T` = 2, `τ_E` = 2 dans
  les 5 plis externes. Log-loss énergie externe poolée : 0,543 contre 0,580 au réglage nominal
  (`T` = 2, `τ_E` = 1) ; paires suivantes `T` = 2, `τ_E` = 3 (0,544) et `T` = 4, `τ_E` = 2
  (0,549). Décision : `T` = 2, `τ_E` = 2. `τ_V` reste 1,5 : pilote énergie seulement, et meilleure
  log-loss des variantes comparées pour l'agrément constant (0,623, mesurée sur les mêmes plis,
  à revoir avec le bandit et l'état 2-D après le cours). Courbes ci-dessus, fixtures
  `personal_layer_cases.json` (a priori 2,0) et contrôle de sensibilité refaits avec ces valeurs.
  Détail agrégé dans `data/results/wp-b0.json` et `wp-b0-nested.json`. Les tests Python
  vérifient les fixtures et la parité entre l'implémentation scalaire et la simulation.
- **Pendant le pilote** : modèle commun figé ; couche personnelle en mode ombre, énergie seulement
  (§3, D4 et périmètre « collecte seule »).

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
2. Chercher dans la table MuSe : d'abord par ID Spotify, puis par titre + premier artiste (dans
   l'app, apostrophe droite d'abord, puis typographique : §5.2).
3. Sinon, envoyer par lots de 50 (titre + artistes seulement) au **Worker**, qui appelle le LLM
   et renvoie `{energy, positivity}` entre 0 et 1 en JSON. Réponse invalide → 0,5 / 0,5, origine
   « neutre » (`SongScore.origin = neutral`), utilisé en dernier.
4. Mettre en cache : chaque morceau n'est envoyé qu'une fois.
5. **Contrôle hors ligne** : le même prompt sur 2 000 morceaux MuSe (scores cachés au LLM) →
   corrélation et erreur moyenne, via l'API Batch (moitié prix).

LLM : **Claude Haiku 5.5 (`claude-haiku-5-5`)**, comme dans le rapport. Essai 1 fait avec Claude
Haiku 4.5 (choix d'équipe du 23 nov. 2026, abandonné le même jour après le contrôle ci-dessous).
Attention : l'API est facturée à part de l'abonnement Claude Pro (compte Console + crédit à
acheter).

**Requête partagée (TODO 2.29)** — une seule source, lue par le Worker et par `ml/llm_check.py` :
`ml/prompts/score.txt` (prompt système) et `ml/prompts/score_config.json` (modèle, `max_tokens`,
effort, schéma de sortie). Cas communs Python ↔ TypeScript :
`ml/fixtures/score_cases.json`. Pour consommer le moins de tokens possible :
- Haiku 5.5 : réflexion (*thinking*) adaptative par défaut, limitée par `effort: "low"` ;
  `max_tokens` 4 096 car la réflexion compte dedans ; pas de `temperature` (refusée) ; pas de cache
  (prompt sous le minimum de 512 tokens). Un refus (`stop_reason: "refusal"`) = échec de la requête.
  (Essai 1, Haiku 4.5 : sans réflexion, `max_tokens` 1 024.)
- entrée compacte, une ligne par morceau : `index<TAB>titre<TAB>artiste1, artiste2` (caractères de
  contrôle → espace) ;
- sortie en *structured output* (JSON garanti) : `{"s":[{"i":index,"e":énergie,"p":positivité}, …]}`
  en **entiers 0–100**, divisés par 100 chez nous (objets depuis l'essai 3 : le schéma impose les
  trois clés, donc l'index ; essais 1–2 en triplets `[index, énergie, positivité]`, cf. leurs
  commits). « 50 = un morceau typique (la moitié des morceaux
  en dessous) », pour coller à l'échelle en centiles de MuSe (§5.2) ;
- lecture : pour chaque index, la paire n'est gardée que si exactement un objet porte cet index,
  avec les seules clés `i`, `e`, `p`, et que les deux valeurs sont des entiers 0–100, sinon `null` (→ neutre). Réponse coupée
  (`stop_reason` ≠ `end_turn`) → échec de la requête.
- Coût estimé : ~1 000 tokens en entrée + ~500 en sortie par lot de 50, soit ~0,0035 $ par lot
  avec Haiku 4.5, ~0,0004 $ avec Haiku 5.5 (dix fois moins cher par token).

**Essai 1 — contrôle hors ligne (TODO 2.30, 23 nov. 2026, Claude Haiku 4.5, prompt v1)** —
`python ml/llm_check.py` : 2 000 morceaux tirés
de `muse.sqlite` (graine 0), titres et artistes seulement, 40 requêtes Batch de 50 (batch
`msgbatch_01QKvLVUu7B4pUDXrs9QC8Cu`). 40/40 réussies, aucune coupée, aucun `null`.
Tokens réels : 42 434 en entrée, 12 320 en sortie (21,2 et 6,2 par morceau), **0,052 $** au prix
Batch (~0,0026 $ par lot de 50 hors Batch).

| Score | Pearson | Spearman | MAE brute | MAE en centiles | Moyenne / ÉT LLM | Moyenne / ÉT MuSe |
|---|---|---|---|---|---|---|
| Énergie | 0,275 | 0,277 | 0,245 | 0,275 | 0,606 / 0,125 | 0,502 / 0,286 |
| Positivité | 0,339 | 0,336 | 0,232 | 0,263 | 0,554 / 0,169 | 0,501 / 0,288 |

Lecture : le LLM range les morceaux un peu dans le même sens que MuSe, mais faiblement ; ses
scores sont resserrés (écart-type 0,13–0,17 contre 0,29) et trop hauts en énergie. Une fois
convertis en centiles, l'erreur est plus grande que celle de la valeur neutre 0,5 (0,25). Limite :
MuSe n'est pas une vérité parfaite (28,6 % des morceaux n'ont qu'un tag d'émotion, §5.2), donc
la corrélation mesurée est un plancher de l'accord réel.

**Décision sur l'essai 1 (TODO 2.31, 23 nov. 2026)** — règle écrite avant le contrôle : un score n'est utilisé
que si Spearman ≥ 0,4 **et** MAE après conversion en centiles < 0,25, chaque score jugé seul.
Énergie (0,277 ; 0,275) et positivité (0,336 ; 0,263) échouent sur les deux critères → **le LLM
n'est pas utilisé : MuSe, sinon valeur neutre 0,5 (`origin = neutral`)**. Pas de réglage du prompt
après coup pour passer la règle. Le Worker reste déployé mais l'app ne l'appelle pas ; les tâches
2.33 (`WorkerClient`) et 2.34 (`SongScorer` : MuSe → Worker → neutre) sont à redéfinir en équipe.
Un nouvel essai (autre modèle ou autre prompt) serait une nouvelle expérience, avec sa règle écrite
avant, sur un autre tirage de MuSe.

**Essai 2 — écrit avant de le lancer (23 nov. 2026)** : décision d'équipe de passer à Claude
Haiku 5.5 avec un prompt v2 tiré des leçons de l'essai 1.
- Leçons de l'essai 1 : (1) scores resserrés (écart-type 0,13–0,17 contre 0,29) malgré « use the
  whole range » ; (2) énergie trop haute (moyenne 0,61 contre 0,50) ; (3) classement faible.
- Prompt v2 (`ml/prompts/score.txt`) : décrit ce qui est noté comme les tags d'humeur que les
  auditeurs donnent (source des scores MuSe : tags Last.fm) avec des mots pour chaque bout de
  chaque échelle ; définit le score comme un rang centile dans un mélange large de genres, avec des
  repères (« ~20 % sous 20, ~20 % au-dessus de 80 ») ; rappelle que beaucoup de morceaux sont plus
  calmes et plus tristes que les tubes ; note chaque morceau seul (pas relativement aux autres
  lignes du lot). Format d'entrée et de sortie inchangé.
- Protocole : nouveau tirage de 2 000 morceaux (`--seed 1`, dossier `data/llm_check_v2/`), un seul
  lancement, pas de retouche du prompt après avoir vu les résultats. Même règle qu'à l'essai 1.

**Essai 2 — résultats (23 nov. 2026)** : batch `msgbatch_01PUDVqh21SKGjp8K5Y5q3Tc`, 40/40 requêtes
réussies, aucune coupée, aucun `null`. Tokens : 64 777 en entrée, 14 360 en sortie, réflexion
comprise (32,4 et 7,2 par morceau), **0,0068 $** au prix Batch.

| Essai | Score | Pearson | Spearman | MAE brute | MAE en centiles | Moyenne / ÉT LLM | Moyenne / ÉT MuSe |
|---|---|---|---|---|---|---|---|
| 1 (Haiku 4.5, v1, graine 0) | Énergie | 0,275 | 0,277 | 0,245 | 0,275 | 0,606 / 0,125 | 0,502 / 0,286 |
| 1 | Positivité | 0,339 | 0,336 | 0,232 | 0,263 | 0,554 / 0,169 | 0,501 / 0,288 |
| 2 (Haiku 5.5, v2, graine 1) | Énergie | 0,280 | 0,279 | 0,254 | 0,273 | 0,476 / 0,237 | 0,510 / 0,288 |
| 2 | Positivité | 0,324 | 0,324 | 0,251 | 0,266 | 0,444 / 0,232 | 0,504 / 0,290 |

Lecture : le prompt v2 a corrigé ce qu'il visait, l'échelle (écart-type 0,24 au lieu de 0,13–0,17,
plus de biais d'énergie) ; il n'a pas changé le classement (Spearman 0,28 et 0,32, comme à
l'essai 1). Deux modèles et deux prompts donnent le même accord : la limite semble venir de
l'information disponible (titre + artiste) et de la référence (tags MuSe bruités), pas du prompt.
Haiku 5.5 coûte 7,6 fois moins cher que Haiku 4.5 pour ce contrôle.

**Décision sur l'essai 2 (TODO 2.31)** : même règle, mêmes échecs (énergie 0,279 ; 0,273 —
positivité 0,324 ; 0,266) → la décision de l'essai 1 est confirmée : **pas de scores LLM, MuSe puis
valeur neutre 0,5**. Le Worker reste déployé (Haiku 5.5, prompt v2), non appelé par l'app.

**Essai 3 — écrit avant de le lancer (23 nov. 2026)** : décision d'équipe d'ajouter des morceaux de
référence au prompt, **règle 2.31 inchangée**.
- Diagnostic des essais 1–2 (agrégats sur les 4 000 morceaux) : l'accord monte avec le nombre de
  tags MuSe (Spearman énergie / positivité 0,21 / 0,28 sur 1 tag, 0,38 / 0,47–0,49 sur ≥ 10 tags ;
  65 % des morceaux ont ≤ 3 tags) ; dans un même genre, le classement est faible (0,15–0,39) ;
  dans MuSe l'énergie et la positivité vont ensemble (corrélation 0,35–0,38), pas chez le LLM. Par
  simulation, une MAE en centiles < 0,25 demande un Spearman ≈ 0,42 : les deux critères de la
  règle demandent en pratique la même chose.
- Prompt v3 = v2 + **48 morceaux de référence** avec leurs scores MuSe (0–100).
  `python ml/llm_anchors.py` (graine 0) prend, dans chaque case d'une grille 4 × 4 des quartiles
  énergie × positivité, 3 morceaux MuSe avec ≥ 10 tags (référence fiable), de genres différents
  dans la case et d'artistes tous différents. Liste non retouchée à la main (un test vérifie que
  le prompt contient exactement la sortie du script). MuSe est sous CC BY 4.0 (cité dans le script).
- Le prompt (~900 tokens) dépasse le minimum de cache de Haiku 5.5 (512) : prompt système mis en
  cache (`cache_control`) dans le Worker et dans le contrôle. `max_tokens` 8 192 (plafond ; la
  réflexion compte dedans).
- Échantillons : un tirage (graine 2) parmi les morceaux MuSe hors morceaux de référence et hors
  échantillons des essais 1–2 ; les 1 000 premiers = **dev**, les 2 000 suivants = **test**,
  disjoints par construction (test unitaire).
- Dev : deux variantes, effort `low` et `medium`. `medium` n'est gardé que si la moyenne de ses
  deux Spearman dépasse celle de `low` d'au moins 0,02 ; sinon `low` (moins cher, plus rapide).
  Le choix est écrit dans `score_config.json` et commité avant le test.
- Test : un seul lancement avec la variante choisie et la règle 2.31 telle quelle (Spearman ≥ 0,4
  et MAE en centiles < 0,25, chaque score jugé seul). Pas de retouche du prompt après.
- Chiffres secondaires, sans effet sur la décision : Spearman par nombre de tags MuSe ; MAE des
  scores ramenés vers 0,5 (0,5 + k × (centile − 0,5)), k choisi sur le dev pour chaque score.

**Essai 3 — dev, 1er passage et écart au protocole (23 nov. 2026)** : batches
`msgbatch_014eCRhzR3iL7fYAab3Z7PRL` (`low`) et `msgbatch_01NjHLMNLe6f8rXTyp85k6Cy` (`medium`).
- `low` : 4 requêtes sur 20 ont répondu des paires `[énergie, positivité]` sans index (copie du
  format des lignes de référence), rejetées par la lecture stricte → **20 % de `null`**. Spearman
  sur les 800 morceaux notés : énergie 0,279, positivité 0,370. `medium` : aucun `null`, 0,315 et
  0,340 ; 3,4 fois plus de tokens de sortie (22,8 par morceau, réflexion comprise).
- La règle de choix écrite avant (`medium` si + 0,02 de Spearman moyen) donnerait `low` (+ 0,003
  pour `medium`), mais elle n'avait pas prévu une panne de format qui laisse 20 % des morceaux au
  neutre (en production, tout un lot de 50).
- Écart décidé avant de relancer : le schéma de sortie passe aux objets `{"i","e","p"}` (le schéma
  ne permet pas d'imposer la longueur d'un tableau, mais impose des clés requises), donc l'index ne
  peut plus manquer ; ~13 tokens de sortie par morceau au lieu de ~7, coût négligeable. Le dev est
  relancé pour les deux variantes sur les mêmes 1 000 morceaux, avec la même règle de choix ;
  l'échantillon test (2 000) reste intact.

**Essai 3 — dev, 2e passage (format objets, 23 nov. 2026)** : batches
`msgbatch_01YPAjL4t51VHy3RQNWd4u7R` (`low`) et `msgbatch_01MVtz2LUNa84FfUSjFW5jTS` (`medium`),
20/20 requêtes réussies chacun, **aucun `null`**.

| Effort | Spearman énergie | Spearman positivité | Moyenne | Sortie / morceau | Coût |
|---|---|---|---|---|---|
| `low` | 0,291 | 0,347 | 0,319 | 16,2 tokens | 0,0053 $ |
| `medium` | 0,300 | 0,345 | 0,323 | 39,4 tokens | 0,0110 $ |

Choix par la règle écrite avant : `medium` ne gagne que 0,004 (< 0,02) → **`low`** (déjà dans
`score_config.json`). Facteurs de rapprochement vers 0,5 choisis sur le dev (chiffre secondaire) :
k = 0,45 (énergie), 0,50 (positivité). Test : `python ml/llm_check.py --part test --shrink 0.45
0.50 --out data/llm_check_v3_test`.

**Essai 3 — test (23 nov. 2026)** : batch `msgbatch_012GbFPRyyZ5ayDE2VTk6mpw`, 2 000 morceaux jamais
vus, effort `low`, 40/40 requêtes réussies, aucun `null`. Tokens : 39 338 en entrée, 70 640 lus
dans le cache (le prompt de référence), 32 360 en sortie (16,2 par morceau, réflexion comprise) ;
**0,0104 $**.

| Essai | Score | Spearman | MAE en centiles | Moyenne / ÉT LLM |
|---|---|---|---|---|
| 1 (Haiku 4.5, v1) | Énergie | 0,277 | 0,275 | 0,606 / 0,125 |
| 1 | Positivité | 0,336 | 0,263 | 0,554 / 0,169 |
| 2 (Haiku 5.5, v2) | Énergie | 0,279 | 0,273 | 0,476 / 0,237 |
| 2 | Positivité | 0,324 | 0,266 | 0,444 / 0,232 |
| 3 (Haiku 5.5, v3 + 48 références) | Énergie | 0,258 | 0,280 | 0,501 / 0,228 |
| 3 | Positivité | 0,316 | 0,267 | 0,461 / 0,235 |

Chiffres secondaires (sans effet sur la décision) : Spearman par nombre de tags MuSe — énergie
0,18 (1 tag, n = 556), 0,20 (2–3), 0,39 (4–9), 0,26 (≥ 10, n = 187) ; positivité 0,19, 0,29, 0,44,
0,50. Scores ramenés vers 0,5 avec les k du dev (0,45 ; 0,50) : MAE en centiles 0,238 et 0,233,
sous la valeur neutre (0,250).

**Décision sur l'essai 3 (TODO 2.31)** : même règle, mêmes échecs → **pas de scores LLM, MuSe puis
valeur neutre 0,5**. Les morceaux de référence n'ont rien apporté sur le test (écart avec l'essai 2
dans le bruit : erreur type ≈ 0,02). Trois essais, deux modèles, trois prompts donnent le même
accord (0,26–0,34) : la limite vient de ce que le LLM reçoit (titre + artiste) et du bruit de MuSe,
pas de la rédaction du prompt ; d'autres retouches du prompt ne sont pas prévues. Seule piste
restante, à décider en équipe avec une nouvelle règle écrite avant et un nouveau tirage : utiliser
les scores ramenés vers 0,5, qui font un peu mieux que le neutre (0,233–0,238 contre 0,250) mais
restent proches du milieu. Le Worker est redéployé avec le prompt v3 (format objets, cache), non
appelé par l'app.

**Décision finale (23 nov. 2026, équipe) : le LLM est utilisé malgré tout.** La règle 2.31 n'est
atteinte dans aucun des trois essais ; l'équipe passe outre, en connaissance de cause, parce que la
référence elle-même est trop peu fiable pour juger le LLM : 65 % des morceaux MuSe ont ≤ 3 tags, et
l'accord monte avec le nombre de tags (essai 3 : 0,39–0,44 sur les morceaux à 4–9 tags, contre
0,18–0,19 sur ceux à 1 tag). Le contrôle mesure donc autant le bruit de MuSe que l'erreur du LLM.
- Ordre dans l'app (2.34, comme prévu au départ) : MuSe → Worker (Claude Haiku 5.5, prompt v3,
  effort `low`) → neutre 0,5 si le Worker échoue ou rend `null` (`origin` = `muse`, `llm` ou
  `neutral`). 2.33 et 2.34 restent tels quels dans `docs/TODO.md`.
- Échelle : pas de conversion en centiles dans l'app ; les scores du LLM sont déjà sur une échelle
  proche de MuSe (essai 3 : moyenne 0,50 / 0,46, écart-type 0,23 contre 0,29).
- Pour le rapport : écrire que la règle fixée avant n'est pas atteinte (chiffres des trois essais
  ci-dessus) et que l'utilisation est un choix d'équipe motivé par la qualité de la référence, pas
  un résultat validé. Le retour « ça collait ? » et les sauts (`FeedbackStore`) restent le moyen de
  juger ces scores en usage.

**Dans l'app (TODO 2.34)** — `Core/Scoring/SongScorer.swift` : pour chaque morceau de la
bibliothèque sans `SongScore`, MuSe (`origin = muse`), sinon Worker par lots de 50 (`llm`, ou
`neutral` 0,5/0,5 si `null`), sinon `neutral` (titre vide, aucun artiste, lot refusé en 400). Un
morceau qui a un score n'est plus jamais cherché ni envoyé (test). Le store est enregistré après
MuSe puis après chaque lot : si une requête échoue (403, 429, 502, réseau), les lots déjà notés
restent et les morceaux restants partent à la prochaine fois, sans être mis à neutre. En mode démo
(ou sans URL de Worker), les morceaux absents de MuSe attendent. Lancement pour l'instant depuis
l'écran Debug (section « Song scores » : origines, couverture MuSe, 10 derniers morceaux) ;
l'onboarding (3.16) l'appellera après l'import.

### 7.1 Le Worker (seul composant cloud)
Code : `worker/` (TypeScript, Wrangler, SDK Anthropic ; commandes dans `worker/README.md`).
Déployé le 23 nov. 2026 (TODO 2.28) ; l'URL n'est que dans `Config.xcconfig` (ignoré par Git).
- `GET /health` → 200 `{"ok":true}`.
- `POST /score`, en-tête `Authorization: Bearer <jeton d'accès Spotify>`, corps
  `{"songs":[{"title":"…","artists":["…"]}]}` : 1 à 50 morceaux, titre de 1 à 200 caractères,
  1 à 10 artistes de 1 à 100 caractères, corps ≤ 64 Ko (lecture arrêtée au-delà), aucun autre
  champ (TODO 2.24).
- Réponse 200 `{"scores":[{"energy":0.42,"positivity":0.71} | null, …]}`, même ordre et même
  longueur que `songs` ; `null` = pas de paire valide pour ce morceau → neutre dans l'app.
- Codes : 400 entrée invalide · 401 jeton absent ou refusé par Spotify · 403 compte hors liste ·
  429 limite du jour (`Retry-After` jusqu'à 00:00 UTC) · 502 Spotify ou LLM en échec (réessayer
  plus tard, ne pas mettre en cache comme neutre) · 404/405 autres routes et méthodes.
- **Authentification sans comptes à nous** (TODO 2.25) : le Worker appelle
  `GET https://api.spotify.com/v1/me` avec le jeton de l'app et n'accepte que les ID Spotify du
  secret `ALLOWED_SPOTIFY_IDS` (liste séparée par des virgules, hors du dépôt public).
- Clé LLM : secret `ANTHROPIC_API_KEY`, jamais dans le code ni dans Git (`git grep` vérifié).
- **Limite** (TODO 2.27) : 50 requêtes (≤ 2 500 morceaux) par utilisateur et par jour UTC,
  compteur dans Workers KV (`count:<id>:<date>`, expire après 2 jours) ; les requêtes refusées
  (400/401/403) ne comptent pas. KV n'est pas atomique : des requêtes simultanées d'un même
  compte autorisé peuvent dépasser un peu la limite. Accepté (5 comptes connus, ~0,0035 $ par
  requête) ; un Durable Object serait la version stricte si besoin.
- Mesures du 23 nov. 2026 (vrai jeton Spotify, 50 titres connus) : 50 paires entre 0 et 1, aucun
  `null` ; 4,3 s en local, 5,1 s une fois déployé (Haiku 4.5) ; 4,4 s déployé avec Haiku 5.5 et le
  prompt v2, toujours 50 paires valides ; 5,4 s avec le prompt v3 (48 références, format objets). Ça tient dans l'offre gratuite (10 ms de CPU
  par requête, l'attente réseau ne compte pas). Un faux jeton → 401 venant du vrai Spotify.
- Offre gratuite Cloudflare : 100 000 requêtes/jour, largement suffisant.
- **Client dans l'app** (TODO 2.33) : `Services/WorkerClient.swift`, URL lue dans `Info.plist`
  (`WorkerURL`, venue de `Config.xcconfig`) ; une requête = 1 à 50 morceaux, jeton Spotify du
  Keychain (rafraîchi une fois si le Worker répond 401). Titre et artistes coupés aux limites
  ci-dessus (unités UTF-16, comme `length` en JavaScript) ; morceau sans titre ou sans artiste
  jamais envoyé. Paire hors de 0–1 → `null`. 400 = lot refusé (renvoyer n'aiderait pas) ;
  403, 429, 502 et réponse mal formée = rien n'est mis en cache, on réessaiera.

---

## 8. Construction de la file

Paramètres de départ (à ajuster au pilote) :
- `e0` = état estimé (0..1) ; `g` = énergie cible de la situation (§2.3).
- `n = 5` si |e0 − g| > 0,3, sinon 3 ; `m` = 2 morceaux « de correspondance » si n = 5, sinon 1.
- Cibles : `m` fois `e0`, puis réparties régulièrement de `e0` à `g`.
- Pour chaque cible : morceau de la bibliothèque le plus proche en énergie, avec pénalités
  (+0,2 si positivité < 0,5 pour Stress/Low energy ; +0,3 artiste déjà dans la file ; aucune pour un
  score LLM, décision du 23 nov. 2026, §3).
  Exclure les morceaux joués dans les 3 derniers jours et ceux passés 2 fois dans cette situation.
- Si aucun morceau à moins de 0,15 de la cible et < 2 suggestions : morceau MuSe d'un artiste de la
  bibliothèque, sinon d'un genre de la bibliothèque (genres MuSe de ses morceaux, §5.2), ID vérifié
  par `GET /tracks/{id}` (titre + artiste), marqué « nouveau ».
- Explication : phrases fixes (contexte + plan), **jamais** un mot d'émotion.

Suggestion de situation (FR5) : Wake-up dans les 2 h après la fin du sommeil ; Wind-down après
21 h ; Low energy entre 13 h et 17 h si état < 0,4 ; sinon aucune suggestion. Stress jamais
suggéré automatiquement (modèle trop faible sur le stress).

**Règles précisées à l'implémentation (TODO 3.1–3.8, 23 nov. 2026 ; `app/Harmony/Core/Queue/`)** :
- **Sens de la file** (décision du 23 nov., 4 situations) : Wake-up et Low energy ne font jamais
  baisser l'énergie, Stress et Wind-down ne la font jamais monter. Si `e0` est déjà au-delà du but,
  le but devient `e0` et la file reste plate (3 morceaux à `e0`).
- **Cibles** : `m` fois `e0`, puis `n − m` cibles régulières, la dernière exactement au but (« Goal »).
- **Coût** = |énergie − cible| + 0,2 + 0,3 (pénalités ci-dessus ; « artiste » = premier artiste
  normalisé). Un morceau n'apparaît qu'une fois par file. Les scores `neutral` ne servent que si
  aucun morceau MuSe/LLM n'est éligible (« utilisé en dernier », §7). Égalité : plus petit ID.
- **Exclusions** : morceaux d'une file lancée dans les 72 h ; morceaux passés (< 30 s) 2 fois dans
  des files de la même situation ; une suggestion passée une fois n'est plus jamais suggérée (rapport).
- **Repli MuSe** : déclenché si aucun morceau MuSe/LLM éligible n'est à moins de 0,15 de la cible
  et qu'il y a moins de 2 suggestions. Candidats : morceaux MuSe avec ID, hors bibliothèque, non
  exclus, d'un artiste de la bibliothèque, sinon d'un de ses genres ; on garde ceux dont le coût est
  plus bas que celui du meilleur morceau de la bibliothèque, et on en vérifie au plus 3 par place
  (`GET /tracks/{id}` : même titre et même premier artiste, clés MuSe `SongKey`) ; sinon le morceau
  de la bibliothèque. Bibliothèque épuisée → file plus courte.
- **« Use suggested tracks »** (Home vide, décision du 23 nov.) : file de morceaux MuSe seuls, tous
  vérifiés, pour la situation suggérée ; la limite de 2 suggestions ne s'applique qu'aux files de
  la bibliothèque.
- **Raison** (`Explainer`, phrases en anglais) : contexte puis plan, ex. « Short night, morning: calm
  songs first, then more energy. ». Contexte : nuit courte/longue (`z_sleep_min` ≤ −1 / ≥ 1),
  moment de la journée (5–12 h morning, 12–17 h afternoon, 17–21 h evening, sinon night), FC
  plus haute/basse que d'habitude (`z_hr_30` ≥ 1 / ≤ −1), HRV plus haute/basse que d'habitude
  (décision du 23 nov., FR3 : dernière HRV horaire des 6 dernières heures contre les HRV horaires
  des 14 jours précédents, prête à 7 jours, z ≥ 1 / ≤ −1). File en mode heure seule : moment de la
  journée seulement (rien n'est dit sur des données que la file n'a pas utilisées). Plan : niveau de
  départ (calm < 0,35, energetic > 0,65, sinon medium), puis « (a little) more energy » ou
  « (a little) calmer » (« a little » si l'écart au but ≤ 0,3), ou « all the way » si la file est plate.
  Un test balaie toutes les combinaisons contre une liste de mots interdits (émotions, stress, mots
  médicaux) ; « calm » reste permis car il décrit la musique (design).
- **Suggestion** : Wind-down de 21:00 à 04:59 ; Wake-up prioritaire (inconnu si la nuit l'est) ;
  `e0` brut jusqu'à 6.11.
- **Temps du tap à la file (TODO 3.21, NFR3 : < 2 s)** : mesuré dans l'app du tap sur une
  situation jusqu'à l'ouverture du lecteur avec la file (avant tout appel de lecture ; écran Debug
  « Tap → queue on screen » et console). iPhone 16, bibliothèque de Clément (2 459 titres), état
  « Body », 23 nov. : 12 files (3 par situation), **0,28 à 0,37 s, médiane 0,34 s**, plus
  l'animation d'ouverture du lecteur (~0,35 s). Aucune de ces files n'a eu besoin du repli MuSe :
  le pire cas, jusqu'à 15 `GET /tracks/{id}` à la suite (3 essais × 5 places), n'est pas mesuré.
  La musique démarre ensuite, sans bloquer l'écran (playlist puis App Remote : ~3 s sur un essai).
  Mesure faite avant le recalcul de l'état à chaque tap (23 nov.), qui ajoute une estimation
  (0,13–0,15 s, §12).
- **Pilote (TODO 4.4–4.5 ; protocole `docs/pilot-protocol.md`)** : une semaine, données de la
  montre tous les jours. Jour de départ dans UserDefaults (`pilot.startDay`, effacé par « Delete
  everything ») ; Debug › Pilot pour démarrer, arrêter et voir le jour du pilote. L'état est
  recalculé à chaque tap (Home peut rester ouvert des heures). `QueueRecord.stateMode` =
  estimation réellement utilisée (sans FC récente, la file part de l'heure seule ; nil pour les
  files d'avant ; type `EstimateMode`, mêmes valeurs `body` / `timeOnly`). Le tirage quotidien par
  blocs de 2 jours écrit le 23 nov. est retiré du code (TODO 4.4, 25 nov.) : plus de `QueueKind` ni
  de `QueueRecord.kind` ; `PilotSchedule` ne garde que le jour de départ, et l'arrêt du pilote
  efface aussi l'ancienne graine `pilot.seed`. `ml/pilot_analysis.py` donne les taux de la semaine
  avec un bootstrap sur les jours (protocole §7.3–7.4) et compte le repli heure seule sur toutes
  les files. Export
  anonyme `harmony-pilot-1` (`Core/Pilot/PilotExport.swift`, Debug › Pilot › Export pilot data ; contenu et exclusions : protocole §7.2 ; exemple partagé
  `ml/fixtures/pilot_export_example.json`) ; analyse `ml/pilot_analysis.py`. Les paires v2 et les
  comptes `PromptLog` (4.5) viendront avec 6.7/6.8, dans un nouveau format.

**Modèle v2 (§3, §6.8 ; design v2 §4.3–§4.6)** — ce qui change dans la file :
- **`e0`** : sans check-in étiqueté récent, rang personnel de l'état (§6.8) au lieu de la
  probabilité brute, tassée entre ≈ 0,36 et 0,55 ; avec ≥ 5 check-ins énergie étiquetés dans les
  14 jours et en mode actif, `σ(z_E + b_E)`. Le seuil « état < 0,4 » de la suggestion s'applique à
  ce même `e0`. Le rang entre dans le pilote si le constructeur de file est prêt (TODO 6.11).
- **Stratégies** (D7) : S1 « progressif » = la règle ci-dessus ; S2 « demi-pas » et S3
  « correspondance longue » partent aussi de `e0` et vont vers `g` de façon monotone. Pendant le
  pilote, toutes les files sont en S1 (journalisé) ; le bandit S1/S2/S3 vient après (TODO 6.12b).
  Récompense : « Did it fit? », skips < 30 s, likes ; jamais une étiquette d'état.
- **Positivité** : quand l'utilisateur répond à l'agrément, un terme de distance de `v0` vers le but
  de la situation remplace la pénalité fixe de +0,2 (après le cours, forme à fixer avec le customer).
- Les règles ci-dessus restent vraies (wind-down ne finit jamais plus énergique qu'il ne commence).

---

## 9. Spotify — ce qu'il faut savoir

- **Mode développement** : 5 utilisateurs max, à ajouter par e-mail dans le dashboard ; le
  propriétaire de l'app doit avoir **Premium** ; lecture = Premium + vrai iPhone + app Spotify installée.
- **Changements de février 2026** (vérifiés le 4 nov.) : restent disponibles `GET /me/tracks`,
  `GET /me/top/tracks`, `GET /me/player/recently-played`, `GET /tracks/{id}`, `GET /me`,
  lecture et file. Supprimé : `GET /tracks` (plusieurs titres d'un coup). Sauvegarder un titre :
  `PUT /me/library` avec des URI. `GET /me` ne renvoie plus e-mail ni pays. `GET /search` : 10
  résultats max par page.
- **Scopes demandés** (TODO 1.22, tous accordés au test du 10 nov. ; les trois scopes de
  playlist le 23 nov. : un jeton plus ancien ne les a pas, il faut se reconnecter, Debug › Spotify
  › Disconnect puis Connect) — un par usage :

  | Scope | Pour | Testé |
  |---|---|---|
  | `user-library-read` | `GET /me/tracks` (titres aimés) | oui (1.21) |
  | `user-top-read` | `GET /me/top/tracks` | oui (1.21) |
  | `user-read-recently-played` | `GET /me/player/recently-played` | oui (1.21) |
  | `user-library-modify` | `PUT /me/library` (like, TODO 3.14) | oui (3.14, 23 nov.) |
  | `app-remote-control` | App Remote (lecture, TODO 3.10) | oui (3.10, 23 nov.) |
  | `playlist-modify-private` | playlist privée « Harmony » qui porte la file (`POST /me/playlists`, `PUT` et `DELETE /playlists/{id}/items`) | oui (23 nov.) |
  | `playlist-read-private` | `GET /me/playlists` : retrouver les anciennes playlists « Harmony » (privées) | oui (23 nov.) |
  | `playlist-modify-public` | `DELETE /me/library` d'une playlist : sans lui, Spotify répond 403 (référence de l'API ; vu le 23 nov.) | oui (23 nov.) |

  `GET /me` et `GET /tracks/{id}` ne demandent aucun scope. Pas de `user-read-private` ni
  `user-read-email` : `GET /me` ne renvoie de toute façon plus ni e-mail ni pays.
- **Authentification** : flux *Authorization Code with PKCE* (pas de secret dans l'app), fait
  nous-mêmes avec `ASWebAuthenticationSession` (`Services/Music/Spotify/`), redirection
  `harmony://callback` ; **marche sur un vrai iPhone** (TODO 1.18, 10 nov.). Jetons dans le
  Keychain (`AfterFirstUnlockThisDeviceOnly`), rafraîchis 1 min avant expiration ou après un 401.
  App Remote accepte ce jeton (TODO 3.10, 23 nov.), mais seulement quand l'app Spotify est déjà
  réveillée (voir **Lecture** ci-dessous).
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
  Mesure du 23 nov. (même iPhone et même compte, bibliothèque plus grande) : **2 045 titres en
  14,3 s**, ce qui confirme l'estimation.
- **Lecture** : App Remote (SDK iOS 5.0.1, `Services/Music/Spotify/SpotifyRemote.swift`) pilote
  l'app Spotify. Test du 23 nov. (TODO 3.10, iPhone 16, compte Premium de Clément) :
  - `connect()` avec le jeton Web API, Spotify ouvert et en train de jouer mais pas réveillé par le
    SDK : refus immédiat (`com.spotify.app-remote.transport -2000`, POSIX 61 « Connection refused ») ;
  - `authorizeAndPlayURI(premier morceau)` : Spotify s'ouvre, joue, revient sur `harmony://callback`
    avec un jeton → connexion OK ;
  - ensuite, Harmony relancé et Spotify toujours ouvert : `connect()` avec le jeton Web API → OK.

  D'où la règle de l'app : on essaie d'abord le jeton Web API ; si la connexion est refusée, on
  réveille Spotify sur la file.
  **File = playlist « Harmony »** (décision de Clément du 23 nov., `SpotifyPlaylist.swift`) :
  ni App Remote ni le Web API ne savent vider la file « À suivre » de Spotify, et le test sur
  iPhone du 23 nov. a montré que chaque file lancée y restait, devant les suivantes (7 files
  lancées : les morceaux des anciennes passaient avant ceux de la nouvelle, l'écran restait sur le
  premier titre, le morceau retiré passait quand même, « Did it fit? » n'arrivait jamais). Désormais
  chaque file est une **nouvelle** playlist privée « Harmony » ; pendant que la musique démarre,
  les anciennes sortent de la bibliothèque (`SpotifyPlaylist.removeOthers` : `GET /me/playlists`,
  puis `DELETE /me/library?uris=spotify:playlist:…`, 40 par appel). Seules sortent celles dont le
  nom **et** la description sont ceux de l'app (l'utilisateur peut avoir sa propre playlist
  « Harmony ») ; une suppression ratée est rattrapée à la file suivante. Bug du 23 nov. corrigé le
  même jour : le scope `playlist-modify-public` manquait (403 à chaque file) ; sur l'iPhone, après
  reconnexion, 67 anciennes playlists sont sorties d'un coup, puis une par file. Une seule playlist réécrite à chaque
  file a été essayée d'abord (même jour) : au changement de file, l'app Spotify rejouait parfois
  l'ancien contenu de la playlist, d'où un morceau d'avant, une pochette qui ne correspondait pas et
  des redémarrages ; une playlist neuve, Spotify doit la charger. App Remote coupe ensuite
  l'aléatoire et la répétition et joue la playlist ; si aucun état ne montre le premier morceau dans
  les 5 s, `play` repart, 3 fois max à 1 s d'écart. « Remove this song » retire le morceau de la playlist (marche aussi téléphone
  verrouillé) ; s'il démarre quand même, l'app le passe. Après le dernier morceau, la lecture
  automatique de Spotify enchaîne : le premier morceau hors file termine la file (« Did it fit? »).
  Restes de l'ancienne méthode, gardés pour mémoire, ajouts à la file (`enqueueTrackUri`), tests du 23 nov. :
  - envoyé avant que le `play` ait pris effet, un ajout est refusé (`error.request_execution_failed`,
    -3000), perdu ou doublé → on attend un état reçu **après** le `play` qui montre le premier
    morceau à son début (< 5 s ; 5 s d'attente max) ;
  - un ajout envoyé juste après un autre peut être perdu alors que Spotify répond OK → les ajouts
    partent à 1 s d'écart ; un ajout refusé est réessayé jusqu'à 3 fois, à 1 s d'écart.

  Les morceaux que l'utilisateur ajoute lui-même à « À suivre » passent toujours avant la playlist
  (comportement de Spotify). La connexion tombe
  quand Harmony passe en arrière-plan : on se déconnecte et on se reconnecte au retour (TODO 3.12).
  Événements vérifiés sur l'iPhone le 23 nov. (écran Debug › Last queue) : la file apparaît dans
  Spotify, like (`PUT /me/library`, le titre arrive dans les Titres likés), skip avant 30 s,
  pause après un passage en arrière-plan, « Did it fit? » sur Next au dernier morceau.
  Repli testé le 23 nov., app Spotify fermée (TODO 3.13) : Spotify se réveille, joue le premier
  morceau, revient dans Harmony, et la file complète arrive dans « À suivre ». Pendant la lecture,
  le lien vers Spotify (NFR6) ouvre seulement l'app (`spotify:`), car ouvrir `spotify:track:ID`
  relance le morceau au début.
  Si rien ne marche, l'écran « Can't play this » ouvre le morceau dans l'app Spotify
  (`spotify:track:ID`) ou, sans l'app, sur `https://open.spotify.com/track/ID` (TODO 3.13).
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
  désactivé) : jamais 0. Python garde le sommeil estimé de v0 (bloc le plus long ≥ 2 h) mais
  applique cette même règle de nuit inconnue : décision du 16 nov. 2026, §6 « Features v1 ».
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
- **Revue des secrets (TODO 3.23, 23 nov.)** : aucun fichier de secrets suivi ni jamais commité
  (`app/Harmony/Config.xcconfig`, `worker/.dev.vars`, `.env` ignorés ; `git log --all` ne les a
  jamais vus) ; dans l'arbre et tout l'historique, 0 chaîne de forme clé (`sk-ant-…`, clés AWS,
  GitHub, Slack, clés privées, `api_key`/`secret`/`token` suivis d'une valeur), seulement des valeurs
  vides ou factices (`worker/.dev.vars.example`, `"test-key"` des tests du Worker). Build Release
  neuf (iOS, 20 fichiers lus octet par octet) : 0 `sk-ant-`, `ANTHROPIC`, `ALLOWED_SPOTIFY_IDS`,
  `client_secret`, clé privée, aucun `.xcconfig`/`.dev.vars`. L'`Info.plist` ne contient que le
  Client ID Spotify (public par conception : PKCE, pas de secret client) et l'URL https du Worker.
  À refaire avant chaque rendu (TODO « En continu »).
- **Check-ins (modèle v2, §6.8)** : traités comme des données de santé ; stockés sur le téléphone,
  inclus dans l'export et la suppression totale, « Reset what Harmony learned » les efface. Au
  pilote, seuls des paires (probabilité, étiquette, jour d'utilisation) et des comptes sortent, avec
  consentement écrit (§3, D5) ; ni réponse brute horodatée ni donnée HealthKit. Notifications au
  texte neutre, sans valeur de santé.

---

## 12. Où on en est (23 novembre 2026)

**Fait**
- Rendu A ; rendu B rédigé (7 pages, `docs/main.tex`, PDF, version Markdown).
- Accès EmoPhone obtenu ; vague D-1 analysée ; résultats reproductibles (`ml/explore_d1.py`).
- Choix techniques, coûts vérifiés, API Spotify de février 2026 vérifiée sur la documentation.
- Dépôt GitHub créé (Harmony), lien et sujet dans le Google Sheet du cours.
- *Mise à jour ML, 20 nov. 2026* : D-1/D-2/D-3 analysées, features v1 écrites (TODO 2.1–2.7) ;
  entraînement et évaluation faits (TODO 2.8–2.11, `ml/train.py`, résultats §6.5) ; décision :
  modèle 4 entrées (§3, TODO 2.13) ; modèle final entraîné sur les trois vagues (TODO 2.14),
  fichier local `data/models/state_model.joblib`, non versionné ; accord des auteurs d'EmoPhone pour
  publier les coefficients (2.14b) ; export `model_params.json`, `StateModel.mlmodel` et fixtures
  golden (2.15–2.17, §6.7).
- *Mise à jour ML UC Irvine, 21 nov. 2026* : exploration agrégée, étiquette d'activation,
  table v1 et évaluation figée avant résultats (TODO 5.1–5.8, `ml/uci_explore.py`,
  `ml/uci_build_features.py`, `ml/uci_eval.py`). Le critère propose UC Irvine comme modèle
  candidat (§3, §6.5), à valider en équipe ; l'intégration à l'app est reportée (5.9).
- *Décision UC Irvine, 22 nov. 2026* : lu dans les deux sens, chaque modèle ne gagne que sur ses
  propres données (§6.5) ; modèle EmoPhone gardé, TODO 5.9 close par abandon explicite (§3).
  Aucun doublon entre les 24 IDs UC Irvine (§5.3). Le modèle et les fixtures déjà livrés
  (`model_params.json`, `StateModel.mlmodel`, `ml/fixtures/state_cases.json`) servent pour 2.APP-a.
- *État dans l'app, 22 nov. 2026 (TODO 2.18–2.22)* : `app/Harmony/Core/State/` — `BaselineCalculator`
  (FC rééchantillonnée, fenêtres, grille 30 min, références 14 j prêtes à 7 jours),
  `FeatureBuilder` (13 features dans l'ordre de `model_params.json`, sommeil = nuits Apple Watch),
  `StateEstimator` (Core ML sur CPU + mode heure seule, modèle `time_only` exporté, §6.7),
  `CurrentState` (lit FC, pas et sommeil des 14 derniers jours, en mémoire seulement) et section
  « State » de l'écran Debug. Tests golden : 13 features × 10 cas, probabilités et probabilités
  heure seule à moins de 1e-6 de Python, sur simulateur et sur iPhone. Sur iPhone avec les vraies
  données Santé (dimanche après-midi, montre portée) : mode « Body », 13 features connues, calcul
  en 0,13–0,15 s.

- *Worker et prompt LLM, 23 nov. 2026 (TODO 2.23–2.29)* : `worker/` déployé sur Cloudflare
  (`POST /score`, authentification par jeton Spotify + liste blanche, 50 requêtes/jour/utilisateur
  dans KV, Claude Haiku 4.5 en sortie JSON compacte) ; prompt partagé `ml/prompts/` et cas communs
  Python ↔ TypeScript (§7, §7.1). Contrôle hors ligne sur 2 000 morceaux MuSe (2.30) : accord trop
  faible → décision 2.31 : pas de scores LLM, MuSe puis neutre (§3, §7) ; 2.33/2.34 à redéfinir.
  Essai 2 (Haiku 5.5, prompt v2, nouveau tirage) : échelle corrigée, classement inchangé ;
  décision confirmée. Worker redéployé avec Haiku 5.5.
  Essai 3 (48 morceaux de référence MuSe dans le prompt, dev/test, format de sortie en objets) :
  0,258 et 0,316 sur le test → décision confirmée à nouveau ; pistes de prompt épuisées (§7).
  Décision finale d'équipe : le LLM est utilisé malgré la règle non atteinte (référence MuSe trop
  peu taguée) ; 2.33/2.34 restent comme prévu (MuSe → Worker → neutre).
- *Scores des morceaux dans l'app, 23 nov. 2026 (TODO 2.32–2.35)* : `muse.sqlite` versionné dans
  `Resources/`, recherche par ID puis titre + premier artiste (`SongKey`, mêmes clés que Python sur
  toutes les lignes MuSe), `WorkerClient`, `SongScorer` (MuSe → Worker → neutre, cache
  `SongScore`), section « Song scores » de l'écran Debug. Sur la bibliothèque de Clément
  (2 045 titres) : 11,4 % trouvés dans MuSe, 88,6 % notés par le LLM, premier scoring en 158 s (§5.2).
- *Modèle d'état v2, 23 nov. 2026* : deux tours de recherche (EmoPhone exploité ? autres jeux ?
  personnalisation ?) archivés dans `docs/research/2026-11-23-modele-etat-v2/` (rapports, notes,
  scripts, résultats agrégés, aucune donnée) ; résultats clés en §6.5. Design A + B
  (`docs/superpowers/specs/2026-11-23-modele-etat-v2-design.md`) ; décisions D1–D9 et périmètre du
  pilote « collecte seule » notés en §3 ; résumé en §6.8 et §8 ; tâches en TODO Phase 6.
  Corrections EmoPhone reportées (§5.1 ; 282 personnes, items maison, fichiers D-3, Polar H10).
  *Suivi ML, 24 nov. 2026* : groupes déterministes et CV v1 reproduite sous Windows
  et sur Mac (§6.5), critères inscrits avant la CV (§3), candidats énergie v2 et valence validés
  (§6.5), simulation WP-B0 et fixtures Python vérifiées (§6.8), hyper-paramètres de la couche
  personnelle encore à décider (TODO 6.5).
  *25 nov. 2026* : modèle v3 (17 features + valence) entraîné, exporté, porté en Swift et testé
  (TODO 6.4, §6.7) ; le pilote tourne sur ce modèle, figé (§3). Couche personnelle : `T` = 2,
  `τ_E` = 2, `τ_V` = 1,5, choisis par sélection imbriquée (TODO 6.5, §6.8).
- *App utilisable de bout en bout, 23 nov. 2026 (TODO 3.1–3.20)* : file (`Core/Queue/` : cibles,
  choix des morceaux, historique, suggestions MuSe vérifiées, raison, suggestion de situation ;
  règles en §8) ; lecture par App Remote (SDK iOS 5.0.1) d'une playlist privée « Harmony » neuve à
  chaque file, like, skip, fin, « Did it fit? », repli « Open Spotify » (§9) ; écrans du design :
  onboarding avec import et scores en arrière-plan, Home, lecteur, « Up next », « Can't play this »,
  Réglages (compte Spotify, santé et consentements, export JSON, suppression totale FR13, à propos).
  Ajouts et écarts voulus par Clément : mini-lecteur, pochettes dans « Up next », grilles et listes
  sous le titre au lieu d'être centrées. Tout vérifié sur l'iPhone 16 de Clément ; textes validés
  par Cyprien (3.20).

- *Library, habillage et QA, 23 nov. 2026 (TODO 3.19b–3.23)* : onglet Library (`V2-Bibliotheque` :
  morceaux importés, pastilles MUSE/Estimated, rien pour neutre ou pas encore noté, part trouvée
  dans MuSe calculée comme l'écran Debug, recherche, « Refresh the import ») ; icône dessinée dans
  le canvas (`V2-Icone`) et validée par Clément, lancement sur `#121212`, portrait seulement ; file à
  l'écran 0,28–0,37 s après le tap (§8) ; messages en clair sans montre, sans réseau, sans Spotify
  (§4.5) ; aucune clé dans Git ni dans l'app (§11). Vérifié sur l'iPhone 16 de Clément ; textes
  relus par Cyprien.

- *Pilote et rapport, 23 nov. 2026 (TODO 4.1, 4.5–4.12)* : protocole et consentement
  (`docs/pilot-protocol.md`, un seul participant : Clément, §3) ; export anonyme dans Debug (§8) ;
  script d'analyse
  `ml/pilot_analysis.py` testé sur un export synthétique ; rapport : sections Design (architecture,
  modules, répartition des tâches tirée de Git), Use Cases et Evaluation and Discussion dans
  `docs/main.tex` (résultats du pilote en `\tbd`). 4.2 et 4.3 cochées : une installation, un compte.
- *Pilote revu, 24 nov. 2026 (décision de Clément)* : une semaine, du 26 nov. au 2 déc., avec les
  données de la montre tous les jours, car le projet se termine le 4 déc. ; protocole, TODO,
  rapport, design v2 et blog mis à jour ; retrait du tirage dans le code : TODO 4.4.
- *Playlists « Harmony », 23 nov.* : l'ancienne playlist ne sortait pas de la bibliothèque (403,
  scope `playlist-modify-public` manquant) ; corrigé, et les anciennes sont nettoyées à chaque
  file (§9). Vérifié sur l'iPhone 16 : 67 sorties d'un coup, puis une par file.

**Pas encore fait**
- Démo M3 au customer (3.24).
- Pilote lui-même (26 nov.–2 déc.) : retrait du tirage dans le code avant le jour 1 (4.4), point à
  mi-pilote (4.6), chiffres de 4.7–4.9, résultats dans le
  rapport (4.12) ; paires v2 de l'export (4.5) avec 6.7/6.8 ; démo finale (4.13).
  L'intégration des check-ins et les autres tâches applicatives sont suivies dans TODO.

## 13. Risques et questions ouvertes

| Risque / question | Impact | Action |
|---|---|---|
| Qui a un Mac ? (un seul MacBook Air déclaré) | Le développement iOS ne peut se faire que sur Mac | Décider tout de suite qui code l'app où |
| HealthKit avec compte gratuit | Bloque la lecture sur un vrai iPhone | Acheter l'Apple Developer Program en premier |
| Installer l'app sur les iPhone du pilote | Sans TestFlight ou appareils enregistrés, pas de pilote | Sans objet : pilote à une personne, l'app est déjà sur l'iPhone de Clément (§3, 23 nov.) |
| Spotify PKCE/App Remote | Bloque M1 | Prototype d'auth dès la première semaine |
| Fréquence de mesure FC Apple Watch | Features vides | Mesurer sur une vraie montre en M1 ; features v1 adaptées |
| Couverture MuSe de vos bibliothèques | Beaucoup d'appels LLM | Mesurée (2.35) : 11,4 % sur 2 045 titres, 88,6 % notés par le LLM ; premier scoring 158 s → à lancer en arrière-plan à l'onboarding (3.16) |
| Gain réel de pas + sommeil | Modèle plus complexe sans gain | Tester sur D-2/D-3 et au pilote ; repli heure + FC |
| Transfert entre populations : EmoPhone → UC Irvine 0,494, UC Irvine → EmoPhone D-3 0,528 (§6.5) | Sur Apple Watch et étudiants de Hanyang (3e population), le modèle peut ne rien apporter | Si les check-ins sont dans le build du pilote : AUROC du modèle commun sur les réponses (6.15), indicative (14 réponses au plus en 1 semaine) ; sinon, limite écrite dans le rapport ; mode heure seule si aucun gain |
| Coût Claude Pro (160 $) annoncé dans le rapport | Doit correspondre à la réalité | Confirmer qui s'abonne |
| Charge du modèle v2 avant le pilote (26 nov.) : build du pilote « collecte seule » ~3–4 jours après la simulation 6.5 | Check-ins absents du pilote | Faire d'abord le sous-ensemble « build du pilote » de la Phase 6 ; s'il ne tient pas, le pilote garde le modèle actuel et B passe après le cours |
| Transfert de la simulation : étudiants EmoPhone payés (~7 réponses/jour), référence « habitude » plus riche que dans l'app | Gain de la couche personnelle surestimé ou plus tardif | Simuler la règle exacte de l'app avant tout code Swift (6.5) ; toujours dire « simulé sur EmoPhone » |
| Taux de réponse sans paiement, fatigue, tension avec N1 | Trop peu d'étiquettes (au pilote : 14 réponses au plus en 1 semaine, à 2 notifications par jour) | Questions en un geste, 2 par jour au plus, facultatives ; taux mesuré au pilote |
| Notifications relayées sur l'Apple Watch sans app watchOS, réponse téléphone verrouillé | Réponses perdues | Tester sur un vrai iPhone verrouillé et une vraie montre avant le pilote (6.10) |
| Éthique : le pilote enregistre des auto-évaluations liées à la santé (App Store 5.1.3) | Pilote contesté | Consentement écrit couvrant les questions (D5) ; demander à l'enseignant si un avis éthique est requis (6.14) |
| `sleep_unknown` a l'un des plus gros coefficients : il reflète l'habitude EmoPhone de ne pas porter la montre la nuit | Signal présenté à tort comme « du corps » | Ne pas le présenter comme un signal corporel |

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
- Modèle d'état v2 : design `docs/superpowers/specs/2026-11-23-modele-etat-v2-design.md` ;
  preuves `docs/research/2026-11-23-modele-etat-v2/` (voir son `README.md`).
- LifeSnaps : https://zenodo.org/records/7229547 (CC BY 4.0)
- EmoPhone : https://arxiv.org/abs/2609.16581 — doi:10.7910/DVN/QGRVU8
- MuSe : doi:10.5281/zenodo.4281165
- Spotify Web API, changements fév. 2026 : https://developer.spotify.com/documentation/web-api/references/changes/february-2026
- Spotify iOS SDK : https://github.com/spotify/ios-sdk
- HealthKit : https://developer.apple.com/documentation/healthkit
- Cloudflare Workers (limites) : https://developers.cloudflare.com/workers/platform/limits/
- XcodeBuildMCP : https://github.com/getsentry/XcodeBuildMCP
- context-mode : https://github.com/mksglu/context-mode

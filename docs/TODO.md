# Harmony — TODO (ordre d'implémentation)

> À lire avec `docs/PROJECT.md`. Les tâches sont **dans l'ordre** : une tâche ne dépend que de
> tâches situées au-dessus (ou dans une piste parallèle déjà terminée).
> Chaque tâche a une ligne **✔** : c'est le critère pour la cocher. Pas de ✔ vérifié → pas de case cochée.
>
> Pistes parallèles après la phase 0 : **APP** (Riad, Clément) · **ML** (Lucas, Clément) ·
> **CLOUD** (Clément) · **DOC** (tous). Initiales indicatives : R, L, C, Cy.
> Jalons : M1 15 nov. · M2 29 nov. · M3 6 déc. · M4 pilote → fin du semestre.

---

## Phase 0 — Mise en place (5 → 9 nov.)

### 0.A Équipe et organisation
- [x] **0.A1** Décider qui code l'app et sur quel Mac (un seul MacBook Air déclaré). — ✔ décision écrite dans PROJECT.md §13.
- [x] **0.A2** Choisir un créneau de réunion hebdomadaire fixe. — ✔ créneau dans le README.
- [x] **0.A3** Confirmer qui prend Claude Pro (160 $ annoncés dans le rapport). — ✔ liste des 4 abonnés.
- [x] **0.A4** Lire ensemble PROJECT.md §3 (décisions) et §6 (contrat des features). — ✔ chacun a validé ou posé ses questions.

### 0.B Dépôt GitHub
- [x] **0.B1** Pousser le contenu de ce dépôt sur `SkaosDev/Harmony`. — ✔ `docs/`, `ml/`, `CLAUDE.md` visibles sur GitHub.
- [x] **0.B2** Ajouter les 3 autres membres comme collaborateurs. — ✔ invitations acceptées.
- [x] **0.B3** Protéger `main` : PR obligatoire, 1 relecture. — ✔ un push direct sur `main` est refusé.
- [x] **0.B4** Vérifier que `data/` est ignoré. — ✔ `git ls-files data/` n'affiche que `data/README.md`.
- [x] **0.B5** Créer un modèle de PR court (quoi, tâche TODO, comment vérifié). — ✔ `.github/pull_request_template.md`.

### 0.C Comptes et accès (C)
- [x] **0.C1** Acheter l'Apple Developer Program (99 $/an). — ✔ compte actif dans developer.apple.com.
- [x] **0.C2** Enregistrer l'identifiant d'app (ex. `com.firestarter.harmony`) avec la capacité HealthKit. — ✔ App ID visible avec HealthKit coché.
- [x] **0.C3** Enregistrer les iPhone de l'équipe (UDID). — ✔ appareils listés dans le compte.
- [x] **0.C4** Créer l'app sur le dashboard Spotify for Developers (propriétaire Premium). — ✔ Client ID obtenu.
- [x] **0.C5** Ajouter le bundle ID iOS et l'URI de redirection (ex. `harmony://callback`). — ✔ enregistrés dans le dashboard.
- [x] **0.C6** Ajouter les e-mails Spotify des membres (≤ 5) comme utilisateurs. — ✔ 4 utilisateurs listés.
- [x] **0.C7** Créer un compte Cloudflare (offre gratuite). — ✔ connexion OK.
- [x] **0.C8** Créer un compte API (Console) et acheter un petit crédit. — ✔ une clé API existe, stockée dans un gestionnaire de mots de passe, **pas** dans le dépôt.

### 0.D Postes de travail
- [x] **0.D1** Mac : Xcode 27.2 + outils en ligne de commande. — ✔ `xcodebuild -version`.
- [x] **0.D2** Mac : Node 18+ (pour XcodeBuildMCP et wrangler). — ✔ `node -v`.
- [x] **0.D3** Installer XcodeBuildMCP dans Claude Code. — ✔ `/mcp` le liste comme connecté.
- [x] **0.D4** PC Windows : Python 3.12, venv, `pip install -r ml/requirements.txt`. — ✔ `python -c "import sklearn; print(sklearn.__version__)"` → 1.5.2.
- [x] **0.D5** Copier les vagues EmoPhone (D1, D2, D3) dans `data/emophone/` sur la machine ML. — ✔ dossier présent, absent de `git status`.
- [x] **0.D6** Lancer `python ml/explore_d1.py --data data/emophone/D1`. — ✔ mêmes chiffres que le Table VII.

---

## Phase 1 — Fondations (→ M1, 15 nov.)

### 1.APP-a Projet Xcode (R/C)
- [x] **1.1** Créer le projet `Harmony` dans `app/` (SwiftUI, SwiftData, tests unitaires, iOS 18.0). — ✔ l'app vide se lance sur le simulateur.
- [x] **1.2** Activer les *synchronized folders* et créer les dossiers `App/ Features/ Core/ Services/ Resources/`. — ✔ un fichier ajouté sur disque apparaît dans Xcode sans modifier `project.pbxproj`.
- [x] **1.3** Capacité HealthKit + `NSHealthShareUsageDescription` dans Info.plist. — ✔ build signé sur un iPhone réel.
- [x] **1.4** Schéma d'URL `harmony` et `LSApplicationQueriesSchemes` = `spotify`. — ✔ ouvrir `harmony://test` dans Safari ouvre l'app.
- [x] **1.5** Fichier de config non versionné pour le Client ID Spotify et l'URL du Worker (`Config.xcconfig` ignoré + exemple versionné). — ✔ `git status` ne montre pas le vrai fichier.
- [x] **1.6** Écran racine avec les 3 onglets du design (Home, Library, Settings), contenus vides ; écran Debug accessible depuis Settings, en build Debug seulement. — ✔ navigation OK sur simulateur ; barre d'onglets conforme à `docs/design/V2-Accueil.dc.html`.

### 1.APP-b Modèle de données SwiftData (C)
- [x] **1.7** `Track` (spotifyId, title, artists, coverURL, source, addedAt). — ✔ test : insertion + lecture.
- [x] **1.8** `SongScore` (spotifyId, energy, positivity, origin). — ✔ test unitaire.
- [x] **1.9** `HourSummary` (hourStart, meanHR, hrCount, sdnnHRV, steps). — ✔ test unitaire.
- [x] **1.10** `NightSummary` (date, sleepMinutes, sleepEnd, wornFraction). — ✔ test unitaire.
- [x] **1.11** `QueueRecord`, `QueueItem`, `FeedbackEvent`, `Consent`. — ✔ tests unitaires.
- [x] **1.12** Conteneur SwiftData en mémoire pour les tests. — ✔ les tests ne laissent aucune donnée.

### 1.APP-c Protocoles et mode démo (C)
- [x] **1.13** Protocole `MusicProvider` (signIn, importLibrary, lookUp, play, save). — ✔ compile.
- [x] **1.14** Protocole `HealthProvider` (requestConsent, samples(type, since)). — ✔ compile.
- [x] **1.15** Fichiers démo synthétiques (`Resources/demo/`) : 14 jours de FC/pas/sommeil + 50 morceaux scorés. — ✔ générés par un script, aucune donnée réelle.
- [x] **1.16** `DemoMusicProvider` et `DemoHealthProvider` lisant ces fichiers. — ✔ test : renvoient les données attendues.
- [x] **1.17** Interrupteur « mode démo » dans Debug. — ✔ l'app fonctionne entièrement sur simulateur en mode démo.

### 1.APP-d Spotify (R)
- [x] **1.18** Prototype d'auth PKCE avec `ASWebAuthenticationSession` (verifier, challenge, échange du code). — ✔ un jeton d'accès obtenu sur un vrai iPhone.
- [x] **1.19** Stocker access/refresh token dans le Keychain. — ✔ le jeton survit à un redémarrage de l'app.
- [x] **1.20** Rafraîchissement automatique du jeton. — ✔ appel réussi après expiration simulée.
- [x] **1.21** Tester chaque endpoint prévu avec un vrai compte : `/me`, `/me/tracks`, `/me/top/tracks`, `/me/player/recently-played`, `/tracks/{id}`. — ✔ tableau OK/KO ajouté à PROJECT.md §9.
- [x] **1.22** Noter les scopes réellement nécessaires. — ✔ liste mise à jour dans PROJECT.md §9.
- [x] **1.23** Import paginé de `/me/tracks` (50 par page) dans `Track`. — ✔ nombre importé = nombre de titres aimés dans Spotify.
- [x] **1.24** Gestion du 429 (attendre `Retry-After`). — ✔ test avec une réponse simulée.
- [x] **1.25** Ajouter top tracks et écoutes récentes (source = top/recent). — ✔ doublons fusionnés.
- [x] **1.26** Déconnexion : supprimer les jetons (et la bibliothèque si l'utilisateur accepte). — ✔ Keychain vide après déconnexion.
- [x] **1.27** Mesurer le temps d'import de 2 000 titres (NFR3 : < 60 s). — ✔ temps noté dans PROJECT.md.

### 1.APP-e HealthKit (R/C)
- [x] **1.28** Demande d'autorisation pour FC, pas, HRV, sommeil, avec écran d'explication. — ✔ la feuille système s'affiche avec les 4 types.
- [x] **1.29** Lecture ancrée (`HKAnchoredObjectQuery`) de la FC depuis la dernière ancre. — ✔ les nouvelles mesures arrivent à chaque ouverture.
- [x] **1.30** Même chose pour les pas et la HRV. — ✔ valeurs cohérentes avec l'app Santé.
- [x] **1.31** Sommeil : seulement source Apple Watch, valeurs asleep*. — ✔ total d'une nuit = celui affiché dans l'app Santé (± 5 min).
- [x] **1.32** Résumés horaires et nocturnes, puis échantillons bruts jetés. — ✔ aucun échantillon brut stocké.
- [x] **1.33** **Mesure terrain** : fréquence réelle de la FC Apple Watch au repos et en journée (2 jours portés). — ✔ médiane de l'intervalle entre mesures notée dans PROJECT.md §6.4.
- [x] **1.34** Taux de port de la montre la nuit sur 3 nuits. — ✔ noté ; règle « 60 % » confirmée ou ajustée.

### 1.ML Données (L) — en parallèle de 1.APP
- [x] **1.35** Explorer D-2 et D-3 : même structure que D-1 ? colonnes ESM, échelles. — ✔ différences listées dans PROJECT.md §5.1.
- [x] **1.36** Vérifier si un participant peut apparaître dans deux vagues. — ✔ résultat noté ; identité inter-vagues non précisée par la documentation, question ouverte dans PROJECT.md §5.1.
- [x] **1.37** Lancer `explore_d1.py` sur D-2 puis D-3 (adapter le préfixe de fichier si besoin). — ✔ tableau de résultats par vague.
- [x] **1.38** Télécharger MuSe (v3, Kaggle) dans `data/muse/` ; afficher colonnes et plages de valeurs. — ✔ échelle de valence/arousal notée dans PROJECT.md §5.2.
- [x] **1.39** Script `ml/muse_build.py` → `muse.sqlite` réduit et reproductible localement (titre, artistes, genre, scores en centiles 0–1 et doublons traités selon PROJECT.md §5.2). — ✔ source retéléchargeable, base régénérable dans `data/` ignoré par Git ; 90 001 lignes lues, 89 269 gardées, taille et limite de 10 Mo documentées dans §5.2.
- [x] **1.40** Fonction de normalisation titre/artiste en Python (minuscules, accents, « feat. », « Remastered »…). — ✔ tests sur 20 cas.

### 1.DOC
- [ ] **1.41** Démo M1 au customer (Cyprien) : connexion, import, données santé, mode démo. — ✔ retours notés dans une issue GitHub.

---

## Phase 2 — Scores et modèle (→ M2, 29 nov.)

### 2.ML-a Features v1 (L/C) — cf. PROJECT.md §6.4
- [x] **2.1** Écrire `ml/features.py` : une seule source de vérité pour les features v1 (ordre fixe). — ✔ fonctions pures, testées.
- [x] **2.2** Moyennes personnelles sur les 14 jours **précédents** (prêtes à 7 jours). — ✔ test : aucune donnée future utilisée.
- [x] **2.3** Référence calculée sur une grille régulière (toutes les 30 min, montre portée). — ✔ même définition écrite dans PROJECT.md §6.
- [x] **2.4** FC rééchantillonnée à 1 mesure / 5 min, seuil 1 mesure par fenêtre. — ✔ test unitaire.
- [x] **2.5** Sommeil estimé + `hours_since_wake` + `sleep_unknown` (repris d'explore_d1). — ✔ avec les règles v0 (couverture minute par minute, fenêtre entière), nuits D-1 identiques à v0 (0 écart) ; avec les règles v1, nombre de nuits qui changent de statut et part de nuits connues notés dans PROJECT.md §6.
- [x] **2.6** Échelles D-3 ramenées sur −3..+3 avant l'étiquette. — ✔ test.
- [x] **2.7** Construire la table v1 pour D-1, D-2, D-3 (fichier local dans `data/`, jamais sur Git). — ✔ nombre de lignes par vague affiché.

### 2.ML-b Entraînement et évaluation (L)
- [x] **2.8** `ml/train.py` : validation croisée 5 groupes par participant sur D-1 + D-2. — ✔ AUROC et balanced accuracy affichées.
- [x] **2.9** Référence « heure seule » calculée de la même façon. — ✔ affichée à côté.
- [x] **2.10** Comparer : heure+FC vs heure+FC+pas+sommeil. — ✔ tableau dans PROJECT.md §6.5.
- [x] **2.11** Test unique sur D-3 (vague tenue à part). — ✔ résultat noté, sans réglage après coup.
- [x] **2.12** (Optionnel) Test sur UC Irvine. — ✔ résultat noté ou tâche abandonnée explicitement. — Fait en Phase 5 (5.6).
- [x] **2.13** Décision en équipe : modèle 4 entrées, modèle heure+FC, ou mode heure seule. — ✔ décision écrite dans PROJECT.md §3.
- [x] **2.14** Entraîner le modèle final sur D-1 + D-2 + D-3. — ✔ fichier modèle produit.

### 2.ML-c Export vers l'app (L/C)
- [x] **2.14b** Confirmer avec les auteurs d'EmoPhone que publier les coefficients du modèle (dans l'app et sur GitHub) est autorisé. — ✔ réponse écrite conservée.
- [x] **2.15** `ml/export.py` : `model_params.json` (ordre des features, médianes, moyennes, écarts-types, coefficients, version). — ✔ fichier < 5 Ko.
- [x] **2.16** Conversion Core ML (coremltools, sur le Mac). — ✔ `StateModel.mlmodel` donne les mêmes probabilités que scikit-learn (écart < 1e-6) sur 100 lignes.
- [x] **2.17** Fixtures golden : 10 séries **synthétiques** + features + probabilité attendues → `ml/fixtures/state_cases.json`. — ✔ fichier versionné, aucune donnée réelle.

### 2.APP-a Features et état dans l'app (C)
- [x] **2.18** `BaselineCalculator` Swift (14 jours, grille 30 min, prêt à 7 jours). — ✔ tests sur fixtures.
- [x] **2.19** `FeatureBuilder` Swift (13 features v1, ordre de `model_params.json`). — ✔ test golden : écart < 1e-6 sur les 10 cas.
- [x] **2.20** `StateEstimator` (Core ML + imputation/standardisation). — ✔ test golden sur la probabilité.
- [x] **2.21** Mode « heure seule » (`prior(heure)`) si pas de référence ou pas de FC sur 30 min. — ✔ test avec données vides.
- [x] **2.22** Écran Debug : features et état actuels. — ✔ valeurs visibles sur un vrai iPhone.

### 2.CLOUD Worker (C)
- [x] **2.23** Créer `worker/` (TypeScript, wrangler). — ✔ `wrangler dev` répond sur `/health`.
- [x] **2.24** Route `POST /score` : valide l'entrée (≤ 50 titres, champs texte courts). — ✔ tests : entrée invalide → 400.
- [x] **2.25** Authentification : jeton Spotify → `GET /v1/me` → ID dans la liste blanche. — ✔ jeton inconnu → 401.
- [x] **2.26** Appel LLM avec la clé en secret (`wrangler secret put`), réponse JSON validée. — ✔ 50 titres → 50 paires de scores entre 0 et 1.
- [x] **2.27** Limite par utilisateur et par jour. — ✔ dépassement → 429.
- [x] **2.28** Déployer. — ✔ URL publique répond ; clé absente du dépôt (`git grep` ne trouve rien).

### 2.ML-d Contrôle du LLM (L)
- [x] **2.29** Écrire le prompt (2 nombres par morceau, JSON strict) dans `ml/prompts/score.txt`, partagé avec le Worker. — ✔ un seul fichier source.
- [x] **2.30** `ml/llm_check.py` : 2 000 morceaux MuSe via l'API Batch, scores cachés au LLM. — ✔ corrélation et erreur moyenne pour énergie et positivité.
- [x] **2.31** Décider si le LLM est assez fiable (sinon : n'utiliser que MuSe + valeur neutre). — ✔ décision écrite.

### 2.APP-b Scores dans l'app (R/C)
- [x] **2.32** Embarquer `muse.sqlite` ; recherche par ID Spotify puis titre + premier artiste. — ✔ tests sur 20 cas (même normalisation que 1.40).
- [x] **2.33** `WorkerClient` : lots de 50, jeton Spotify dans l'en-tête. — ✔ test avec serveur simulé.
- [x] **2.34** `SongScorer` : MuSe → Worker → neutre, cache dans `SongScore`. — ✔ un morceau n'est jamais envoyé deux fois.
- [x] **2.35** Mesurer la couverture MuSe sur les bibliothèques de l'équipe. — ✔ % noté dans PROJECT.md §5.2.

### 2.DOC
- [ ] **2.36** Démo M2 : scores des morceaux, état estimé à l'écran Debug, résultats du modèle. — ✔ retours notés.

---

## Phase 3 — File, lecture, feedback (→ M3, 6 déc.)

### 3.APP-a Logique (C) — fonctions pures, tests d'abord
- [x] **3.1** `Situation` (4 cas, énergie cible, préférence positive). — ✔ test.
- [x] **3.2** Calcul des cibles (n, m, répartition e0 → g). — ✔ tests : wind-down ne finit jamais plus énergique qu'il ne commence.
- [x] **3.3** Choix du morceau le plus proche avec pénalités. — ✔ tests sur une petite bibliothèque.
- [x] **3.4** Exclusions (joué < 3 jours, passé 2 fois dans la situation). — ✔ tests.
- [x] **3.5** Repli MuSe (≤ 2 suggestions, artiste ou genre partagé). — ✔ test : jamais plus de 2.
- [x] **3.6** Vérification de l'ID Spotify d'une suggestion via `GET /tracks/{id}`. — ✔ ID faux → suggestion écartée.
- [x] **3.7** `Explainer` : phrases fixes, aucun mot d'émotion. — ✔ test qui cherche une liste de mots interdits.
- [x] **3.8** `SituationSuggester` (règles PROJECT.md §8, jamais Stress automatiquement). — ✔ tests à heures fixes.

### 3.APP-b Lecture et feedback (R)
- [x] **3.9** Intégrer le SDK Spotify iOS 5.0.1 (Swift Package Manager). — ✔ compile.
- [x] **3.10** App Remote : connexion avec le jeton obtenu en 1.18. — ✔ connexion sur un vrai iPhone.
- [x] **3.11** Jouer le 1er morceau, mettre les suivants en file. — ✔ la file apparaît dans Spotify.
- [x] **3.12** Reconnexion après retour au premier plan. — ✔ testé en sortant/revenant dans l'app.
- [x] **3.13** Repli : ouvrir le morceau dans Spotify si App Remote échoue. — ✔ testé app Spotify fermée.
- [x] **3.14** Événements : skip (< 30 s), like (`PUT /me/library`), fin de morceau. — ✔ `FeedbackEvent` enregistrés.
- [x] **3.15** Question « Ça collait ? » à la fin de la file (design : `V2-Feedback`). — ✔ réponse enregistrée.

### 3.APP-c Écrans (R, textes Cy) — à l'identique de `docs/design/` (voir son README)
- [x] **3.16** Onboarding : connexion Spotify, explications santé, import (design : `V2-Main`, `V2-Onb1` à `V2-Onb5`). — ✔ parcours complet sur iPhone neuf. *(23 nov. : parcours complet sur l'iPhone 16 via Debug › Restart onboarding, scores gardés ; réinstallation évitée, décision de Clément : elle coûterait une journée de quota du Worker.)*
- [x] **3.17** Accueil : 4 grands boutons, suggestion mise en avant (design : `V2-Accueil`, `V2-AccueilVide`). — ✔ ≤ 2 taps entre lancement et musique (NFR5). *(23 nov., iPhone 16 : ouverture de l'app puis tap sur une tuile → Spotify joue. Écart au design voulu par Clément : la grille sous le titre au lieu d'être centrée.)*
- [x] **3.18** Lecteur : pochette non modifiée, logo et lien Spotify, raison de la file, skip/like (design : `V2-Lecture`, `V2-File`, `V2-LectureImpossible`). — ✔ conforme NFR6. *(23 nov., iPhone 16 : pochette Spotify non recadrée, logo vert officiel, « Play on Spotify », skip/like/remove, « Did it fit? », changement de file. Ajouts voulus par Clément : mini-lecteur au-dessus des onglets, pochettes dans « Up next », liste sous l'en-tête ; la file est jouée comme playlist « Harmony », voir PROJECT.md §9.)*
- [x] **3.19** Réglages : données stockées, consentements, export JSON, suppression totale avec confirmation (design : `V2-Reglages`, `V2-CompteSpotify`, `V2-Sante`, `V2-MesDonnees`, `V2-APropos`). — ✔ après suppression, toutes les tables sont vides (FR13). *(23 nov. : test `DataControlTests` (les 8 tables vides, jetons et clés effacés) + sur l'iPhone 16, export JSON et « Delete everything » → retour à l'onboarding. Écarts : liste des Réglages sous le titre, barre d'onglets visible dans les sous-pages.)*
- [ ] **3.20** Textes relus par Cyprien (aucun mot d'émotion, aucune promesse médicale). — ✔ validation dans la PR.

### 3.QA
- [ ] **3.21** File affichée en < 2 s après le tap (NFR3). — ✔ mesuré sur iPhone.
- [ ] **3.22** Comportement sans montre, sans réseau, sans Spotify installé. — ✔ l'app ne plante jamais et le dit clairement.
- [ ] **3.23** Revue sécurité : aucune clé dans le binaire ni dans Git. — ✔ `git grep` + recherche dans l'app compilée.
- [ ] **3.24** Démo M3 au customer. — ✔ retours notés.

---

## Phase 4 — Pilote et rapport final (7 déc. → fin du semestre)

### 4.A Préparer le pilote
- [ ] **4.1** Protocole court (durée ~2 semaines, ≤ 5 comptes, consentement écrit simple ; complété par 6.14 pour les check-ins). — ✔ document dans `docs/`.
- [ ] **4.2** Installer l'app sur les iPhone des participants (Xcode/UDID ou TestFlight, à vérifier). — ✔ 5 installations OK.
- [ ] **4.3** Ajouter les comptes Spotify des participants (dashboard + liste blanche Worker). — ✔ connexion OK pour chacun.
- [ ] **4.4** Tirage au sort quotidien : files « corps » vs « heure seule ». — ✔ le type est enregistré dans `QueueRecord.kind`.
- [ ] **4.5** Export anonyme des feedbacks (sans données de santé brutes), avec les paires (`pCommonBefore`, `pPersonalBefore`, `labelEnergy`, `dayOfUse`) et les comptes `PromptLog` du modèle v2, sous consentement écrit (PROJECT.md §3, D5). — ✔ fichier d'export vérifié.

### 4.B Mener et analyser
- [ ] **4.6** Point à mi-pilote (bugs, ressentis). — ✔ notes.
- [ ] **4.7** Script d'analyse : taux de skip < 30 s et « ça collait ? » par type de file. — ✔ tableau de résultats.
- [ ] **4.8** Fréquence du repli MuSe et taux de skip des suggestions. — ✔ chiffres notés.
- [ ] **4.9** Couverture réelle des données montre (nuits inconnues, FC manquante). — ✔ chiffres notés.

### 4.C Rapport et démo finale
- [ ] **4.10** Sections conception : architecture, structure des modules, répartition des tâches. — ✔ dans `docs/main.tex`.
- [ ] **4.11** Cas d'usage pas à pas (onboarding, une file, suppression des données). — ✔ dans le rapport.
- [ ] **4.12** Résultats (modèle + pilote, dont la courbe commune vs personnelle de 6.15), limites honnêtes, discussion. — ✔ dans le rapport.
- [ ] **4.13** Démo finale répétée, couche personnelle en mode actif (PROJECT.md §3, D4). — ✔ fonctionne aussi en mode démo si le réseau tombe.

---

## Phase 5 — UC Irvine (plus tard, non prioritaire)

> Hors jalons M1–M4, à faire si possible **avant la Phase 4** (après M3, avant le pilote) pour que
> l'éventuel nouveau modèle soit celui du pilote ; sinon plus tard. Ne bloque aucune autre tâche.
> Objectif : refaire avec UC Irvine (Labbaf et al., Dryad doi:10.7280/D1WH6T, 21 étudiants,
> Samsung + Oura) ce qui a été fait avec EmoPhone. Mêmes règles de confidentialité (jamais sur Git,
> aucun contenu collé dans un chat : scripts qui affichent des agrégats seulement). Réalise la tâche 2.12.

### 5.ML UC Irvine
- [x] **5.1** Copier le dataset dans `data/uci/` (dossier prévu par `data/README.md`). — ✔ dossier présent, absent de `git status` ; `git ls-files data/` n'affiche que `data/README.md`.
- [x] **5.2** Explorer la structure : fichiers, colonnes, échelles, fuseau horaire, participants, appareils, fréquence de la FC, sommeil Oura mesuré. — ✔ agrégats seulement, notés dans PROJECT.md §5.3 (équivalent de 1.35–1.37).
- [x] **5.3** Vérifier la licence et les conditions d'usage Dryad. — ✔ conditions notées dans PROJECT.md §5.3.
- [x] **5.4** Définir l'étiquette « arousal haut » à partir des variables d'humeur d'UC Irvine, **s'il existe une variable équivalente**. — ✔ règle écrite dans PROJECT.md §6.2 ; sinon arrêt et question à l'équipe (le contrat §6 ne change pas sans réentraînement).
- [x] **5.5** Construire la table de features v1 pour UC Irvine avec `ml/features.py` (adapter seulement le chargement). — ✔ fichier local `data/features/v1_UCI.csv`, 3 949 lignes / 24 participants affichés, identifiant `UCI_par_N`.
- [x] **5.6** Test unique du modèle final déjà entraîné (2.14), sans réentraînement ni réglage, comparé à « heure seule » et « heure + FC ». — ✔ AUROC et balanced accuracy notées dans PROJECT.md §6.5 (équivalent de 2.11).
- [x] **5.7** (Optionnel) Validation croisée par participant sur UC Irvine seul. — ✔ résultats notés dans PROJECT.md §6.5.
- [x] **5.8** Décision en équipe : UC Irvine donne-t-il de meilleurs résultats qu'EmoPhone ? Critère écrit **avant** de regarder : mêmes métriques (AUROC, balanced accuracy) battent le modèle EmoPhone sur les mêmes données de test, en tenant compte des limites (21 participants, autres appareils, sommeil Oura mesuré et non estimé). — ✔ critère et proposition, à valider en réunion, notés dans PROJECT.md §3.
- [x] **5.9** Si oui : utiliser et implémenter UC Irvine (réentraîner avec ou sur UC Irvine, mettre à jour §6, refaire export/Core ML/fixtures 2.15–2.17 et les tests Swift 2.18–2.21 si l'app est déjà écrite). — ✔ nouveau modèle évalué sans fuite (participants séparés), fixtures golden régénérées, tests passent. Si non : abandon explicite noté. — Non : abandon explicite (22 nov. 2026), modèle EmoPhone gardé ; lu dans les deux sens, chaque modèle ne gagne que sur ses données (PROJECT.md §3, §6.5). Aucun doublon entre les 24 IDs (§5.3).
- [x] **5.10** Mettre à jour PROJECT.md (§5.3, §6.5, §6.6, §12) et le rapport si les résultats y sont utilisés. — ✔ chiffres cohérents partout ; rapport `main.tex` inchangé.

---

## Phase 6 — Modèle d'état v2 : A + B (design `docs/superpowers/specs/2026-11-23-modele-etat-v2-design.md`)

> Avant toute tâche de cette phase : lire la section 0 du design, puis le design en entier.
> Décisions D1–D9 et périmètre du pilote prises le 23 nov. 2026 (PROJECT.md §3) ; résumé en
> PROJECT.md §6.8 et §8 ; preuves dans `docs/research/2026-11-23-modele-etat-v2/`.
> **Build du pilote** (design §15, « collecte seule ») : à faire **avant la Phase 4** (pilote le
> 7 déc.) : 6.1, 6.5, 6.6 (réduit), 6.7, 6.8, 6.10, 6.12 (réduit), 6.13 (réduit), 6.14 ; côté A :
> 6.2–6.4 si prêts avant le 5 déc., 6.11 (rang seulement) si la file (3.2–3.3) existe.
> Le reste (6.9, 6.11 branchement actif, 6.12b, 6.15) vient après le pilote. Le modèle commun est
> figé pendant tout le pilote.

### 6.ML
- [ ] **6.1** Groupes de validation déterministes dans `ml/train.py` (design §7, WP-0). — ✔ deux machines donnent les mêmes écarts-types ; PROJECT.md §6.5 mis à jour.
- [ ] **6.2** Critères d'adoption v2 et valence écrits avant résultats (design §9). — ✔ notés dans PROJECT.md §3.
- [ ] **6.3** Features v2 (17) + valence : CV D-1 + D-2, test unique D-3, décision selon 6.2. — ✔ chiffres dans PROJECT.md §6.5.
- [ ] **6.4** Si adopté : entraînement final, export v3, Core ML, fixtures golden, PROJECT.md §6 (contrat). — ✔ tests Python et Swift passent.
- [ ] **6.5** Simulation de la règle exacte de l'app (WP-B0) + fixtures de la couche personnelle et du rang. — ✔ hyper-paramètres et courbe notés dans PROJECT.md ; fixtures dans `ml/fixtures/`.

### 6.DESIGN
- [ ] **6.6** Écrans et notification de check-in dessinés dans le canvas, copiés dans `docs/design/` (design §5.4 ; réduit pour le pilote : notification, étape d'onboarding, réglages « Questions » et « Reset », check-ins dans My Data). — ✔ README du design à jour.

### 6.APP
- [ ] **6.7** `CheckIn` + `PromptLog` + export/suppression (S1). — ✔ tables vides après suppression.
- [ ] **6.8** Couche personnelle (S2 ; énergie seulement au pilote, en mode ombre). — ✔ fixtures 6.5 à 1e-6.
- [ ] **6.9** Ligne énergie + feuille de check-in (S4). — ✔ NFR5 tenu.
- [ ] **6.10** Notifications à actions (S5). — ✔ réponse depuis l'écran verrouillé et la montre.
- [ ] **6.11** Rang `e0` (S3) et branchement dans la file (S6). — ✔ tests de file.
- [ ] **6.12** Journal de file + modes ombre/actif (S7a). — ✔ champs remplis pour chaque file.
- [ ] **6.12b** Bandit S1/S2/S3, après le pilote (S7b). — ✔ probabilités ≥ 0,15 journalisées.
- [ ] **6.13** Réglages, My Data, About, Debug (S8). — ✔ reset → b = 0.

### 6.PILOTE
- [ ] **6.14** Protocole et consentement incluant les check-ins (complète 4.1) ; demander à l'enseignant si un avis éthique est requis. — ✔ document dans `docs/`.
- [ ] **6.15** Analyse WP-P. — ✔ tableau d'agrégats dans le rapport.

---

## En continu
- [ ] Chaque PR : tâche TODO citée, vérification décrite, relue par un autre membre.
- [ ] Chaque semaine : PROJECT.md §12 (« où on en est ») mis à jour.
- [ ] Avant chaque rendu : `git ls-files data/` vide, `git grep -i "api[_-]key"` sans secret.
- [ ] Signaler aux auteurs d'EmoPhone le problème de la colonne `altitude`, avec les inexactitudes du papier relevées le 23 nov. 2026 (FC annoncée à 1 Hz, `Light.csv` listé pour D-3, `WifiScan` dit limité à D-1/D-2, `DeviceEvent.csv` absent, `Fitness-*` et `Proximity` non documentés : `docs/research/2026-11-23-modele-etat-v2/rapport-1-exploiter-emophone.md`, section « Corrections à reporter »).

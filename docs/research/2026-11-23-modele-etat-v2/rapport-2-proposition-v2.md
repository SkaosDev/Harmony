# Proposition : un modèle d'état qui apprend de l'utilisateur

Proposition pour l'équipe Harmony (G02), à discuter. Rien n'est implémenté et aucun fichier du dépôt n'a été modifié. Elle s'appuie sur les expériences et les recherches de ce tour (23 nov. 2026).

**Conventions.**
- **(M)** = mesuré dans ce tour ou dans un tour précédent. **(E)** = estimation ou inférence (arithmétique, jugement, transposition à l'app).
- Tous les chiffres sont des agrégats : moyenne ± écart-type sur 5 groupes de participants, ou AUROC poolée. Aucune valeur n'est donnée par participant.
- Les sources sont relatives au dossier `/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/`. Abréviations des notes de `research_notes/EmoPhone modèle enrichi et personnalisation/` :
  - **[MT]** `models_targets.md` (cibles, familles de modèles, sorties) ;
  - **[NF]** `new_features.md` (nouvelles entrées) ;
  - **[PS]** `personalization_simulation.md` (simulation de personnalisation) ;
  - **[QS]** `question_system_learning.md` (système de questions, apprentissage, iOS) ;
  - **[LS]** `lifesnaps.md` (jeu LifeSnaps) ;
  - **[R1]** `reports/Exploiter EmoPhone et autres datasets.md` (rapport du tour précédent).
- Les fichiers de sortie sont cités par leur chemin (`v2/.../out/...`).

---

## 1. Résumé

- **Constat.** Plus de capacité ou plus d'entrées montre n'améliore pas l'état estimé : aucune famille ne bat la régression logistique ; contexte de journée, veille, intensité, type d'activité, HRV et autres signaux de nuit apportent ≈ 0 (M) [MT §3, NF, LS §4].
- **Levier.** Les réponses de la personne. En simulation EmoPhone, deux réponses en un geste par jour font passer l'AUROC de l'énergie de **0,555 à 0,666** sur la période (**≈ 0,69 dès le 15e jour**) et celle de l'agrément de **0,529 à 0,704** (M) [PS Q2, Q6].
- **Recommandation : B, « Harmony apprend de toi ».** Le modèle commun actuel sert au jour 1. Sur l'iPhone, deux décalages qui oublient en ~2 jours (énergie, agrément) sont appris des check-ins. Un petit bandit choisit la stratégie de file d'après les skips, les likes et « Did it fit? ».
- **Limites.** Le gain est fiable vers le **4e jour** (5–9 réponses) et s'efface une semaine après la dernière réponse (0,693 → 0,554) (M) [PS Q7]. Il vient surtout des réponses, pas de la montre. Seul, le mode corps vaut 0,573 contre 0,524 pour l'heure seule (M) [MT §2].
- **Pilote.** Modèle commun figé, couche personnelle en ombre (calculée et journalisée, sans piloter la file), stratégies de file tirées au sort avec probabilité journalisée.

---

## 2. Ce que les expériences ont mesuré

### 2.1 Protocoles

- **EmoPhone, modèle commun.** Données D-1 + D-2 : 31 301 réponses, 191 participants (`vague + pcode`). On utilise les 5 groupes `GroupKFold` de `ml/train.py` : des personnes entières sont tenues à part, jamais de découpage aléatoire. Les réglages sont faits uniquement dans les participants d'entraînement (validation imbriquée en 4 groupes). Pipeline §6.3 : médiane, standardisation, régression logistique. **D-3 n'a jamais été ouverte** dans ce tour [MT, NF].
- **Simulation de personnalisation.** Toujours sur les étudiants EmoPhone D-1 + D-2, mêmes 5 groupes externes. Pour chaque personne test et chaque jour, 1, 2 ou 4 réponses ESM sont tirées au hasard comme « check-ins ». Chaque réponse est prédite **uniquement à partir des check-ins antérieurs**, sur 3 graines. Les hyper-paramètres sont réglés par une simulation imbriquée sur les participants d'entraînement [PS Q1].
  - L'étiquette retenue, `L_past`, est réaliste pour l'app : la réponse est-elle au-dessus de la moyenne des réponses de la personne sur les 14 jours précédents (au moins 5 réponses) ?
  - Le check-in simulé est cette étiquette binaire elle-même.
  - Aucun chiffre ne vient d'utilisateurs Apple Watch.
- **LifeSnaps (Zenodo 7229547, CC BY 4.0).**
  - Données : 71 participants européens avec une Fitbit Sense, 5 028 réponses d'humeur par catégorie, converties en activation et agrément.
  - Évaluation par `GroupKFold` par participant : 5 groupes, plus 10 × 5 pour la robustesse.
  - Test du modèle EmoPhone figé (`model_params.json`) sans réentraînement [LS].
- **Rappel.** Les écarts-types des groupes dépendent de la machine (annexe 10.1). Les moyennes sont reproduites à 0,001 près (0,534 / 0,554 / 0,563). Le modèle livré a été entraîné sur D-1 + D-2 + D-3 ; D-3 reste la vague de confirmation unique pour tout candidat ajusté sur D-1 + D-2.

### 2.2 Modèle commun : variantes (AUROC, D-1 + D-2, 5 groupes)

| Variante | Arousal | Valence | Stress | Source |
|---|---|---|---|---|
| Heure seule (3 features) | 0,534 ± 0,009 | 0,534 ± 0,004 | 0,543 ± 0,012 | `v2/models/out/q1_q2.txt` |
| **v1 livré (13 features)** | **0,563 ± 0,012** | 0,542 ± 0,017 | 0,540 ± 0,011 | idem |
| v1 + 4 fenêtres brutes (17) | 0,571 ± 0,018 ; Δ +0,008 ± 0,010 (4/5 groupes) | 0,559 ± 0,024 ; Δ **+0,017 ± 0,009 (5/5)** | 0,541 ; Δ +0,000 | `v2/features/out/eval_q5_P0.txt` |
| Même chose, familles choisies **dans** chaque groupe (estimation honnête) | Δ +0,003 ± 0,009 (3/5) | Δ +0,016 ± 0,007 (5/5) | Δ −0,004 | `v2/features/out/eval_q5_P.txt` [NF Q5] |
| Meilleure autre famille (LR réglée, interactions, HGB, MLP, ensemble, stack) | ≤ +0,000 (HGB −0,005, 0/5) | +0,005 (ensemble, 4/5) | +0,008 (stack, 5/5 ; seulement +0,006 sur l'heure seule) | `v2/models/out/q3_q5_q6.txt` [MT §3] |
| MLP multi-tâche (3 sorties) vs LR | +0,000 | +0,004 ± 0,003 (5/5) | −0,001 | `v2/models/out/q4.txt` [MT §4] |
| **Mode corps** (`z_hr_30` connu, 51,6 % des réponses) | **0,573 ± 0,013 contre 0,524** pour l'heure seule sur les mêmes lignes (+0,049 ± 0,013, 5/5) | 0,553 contre 0,536 (+0,018, 4/5) | 0,541 contre 0,544 | `v2/models/out/q1_q2.txt` [MT §2] |
| Règle mixte de l'app (13 features si `z_hr_30` connu, sinon heure seule) | 0,561 ± 0,011 (−0,002 contre 13 partout ; +0,027 contre heure seule, 5/5) | 0,544 | 0,540 | idem |

Autres mesures (M) :
- **Le stress ne bat pas l'heure seule.** −0,002 ± 0,003 avec les 13 features, 0,541 contre 0,543 avec les 17 [MT §1, NF Q5].
- **Valence et arousal se confondent.** À partir des capteurs, les prédictions de valence et d'arousal corrèlent à **0,713** (Spearman), alors que les vraies étiquettes ne corrèlent qu'à phi 0,225. L'accord sur les 4 quadrants est de 0,315 pour un hasard à 0,276 (kappa 0,054). Un état 2-D tiré des seuls capteurs se replie sur une diagonale (`v2/models/out/q6b.txt`) [MT §6].
- **Les probabilités sont comprimées.** Pour l'arousal, 5–95 % = 0,357–0,553. Le Brier vaut 0,246 contre 0,249 pour le taux de base ; l'ECE ≈ 0,02 [MT §5].
- **Le rang personnel étale e0.** Le rang de la probabilité parmi les prédictions passées de la personne va de **0,03 à 0,98** (5–95 %), pour un coût d'AUROC de −0,005 ± 0,010 (2/5, non significatif). 95,7 % des moments ont au moins 7 prédictions passées [MT §5].
- **Borne haute d'une réponse utilisée comme entrée.** La réponse vient du même questionnaire que la cible.
  - Valence + réponse d'arousal : +0,084.
  - Valence + réponse de stress : +0,138.
  - Arousal + réponse de valence : +0,082.

  `v2/models/out/q4b.txt` [MT §4].

### 2.3 Nouvelles entrées (Δ AUROC ajouté à v1, 5 groupes)

| Famille ajoutée | Arousal | Valence | Stress | Nouvelle autorisation ? |
|---|---|---|---|---|
| Fenêtres longues 2–4 h (z-scores) | +0,001 | +0,001 | +0,001 | non |
| Journée depuis 6 h (pas, FC, FC sédentaire) | +0,002 | −0,000 | −0,002 (0/5) | non |
| Depuis le réveil / matin | +0,001 | +0,001 | +0,002 | non |
| Veille / soirée précédente | −0,001 | −0,003 (0/5) | −0,003 | non |
| Minutes depuis la dernière marche | +0,003 | +0,002 | −0,001 | non |
| FC sédentaire, FC corrigée des pas | −0,000 | −0,000 | +0,000 | non |
| Intensité z-scorée (METs, niveau Fitbit) | −0,000 | −0,000 | −0,002 | oui (`physicalEffort`, `activeEnergyBurned`) |
| Type d'activité du téléphone (immobile, à pied, véhicule) | +0,001 à +0,002 | +0,000 à +0,004 | +0,001 à +0,003 | oui (Motion & Fitness) |
| **4 fenêtres brutes : FC (bpm) et log pas, 30 et 60 min, sans référence personnelle** | **+0,008** | **+0,017 (5/5)** | +0,000 | non |

Source : `v2/features/out/eval_families.txt` et `eval_q5_P0.txt` [NF Q1–Q5] (M).

Pourquoi les fenêtres brutes aident (M) : elles comblent les réponses sans référence de 7 jours, ce n'est pas du « contexte ».
- **Inconnues.**
  - Fenêtres brutes : 26–27 % des réponses (montre retirée).
  - z-scores v1 : 47–48 %.
  - Contexte de journée : 57–72 %.
- **Réponses où `z_hr_30` est inconnu mais la FC présente** (21 %) : arousal +0,028, valence +0,046 (5/5).
- **7 premiers jours de chaque participant** : arousal +0,014, valence +0,030 (5/5).

`v2/features/out/diag.txt` [NF Q1, Q6].

### 2.4 Personnalisation par check-ins (simulation EmoPhone, `L_past`)

**Courbe d'apprentissage en fonction des jours d'utilisation.** AUROC poolée. Méthode retenue : décalage personnel qui oublie (`m1d`). * = l'intervalle de confiance bootstrap de l'écart au modèle commun exclut 0 (M). Source : `v2/perso/out/overview.md`, `compact.md` [PS Q2, Q5, Q6].

*Énergie (arousal)*

| Jour d'utilisation | 1 | 2–3 | 4–7 | 8–14 | 15–21 | 22–28 | 29+ | Période entière |
|---|---|---|---|---|---|---|---|---|
| Personnes présentes | 108 | 186 | 189 | 186 | 161 | 143 | 127 | 191 |
| Modèle commun seul | 0,540 | 0,552 | 0,571 | 0,568 | 0,552 | 0,552 | 0,519 | 0,555 |
| + check-ins 1/jour | 0,528 | 0,548 | 0,615* | 0,640* | 0,664* | 0,669* | 0,652* | 0,639 |
| + check-ins 2/jour | 0,540 | 0,562 | **0,640*** | 0,671* | **0,689*** | 0,697* | 0,696* | **0,666** |
| + check-ins 4/jour | 0,566 | 0,565 | 0,665* | 0,688* | 0,707* | 0,718* | 0,719* | 0,686 (meilleure méthode : 0,687) |

*Agrément (valence)*

| Jour d'utilisation | 1 | 2–3 | 4–7 | 8–14 | 15–21 | 22–28 | 29+ | Période entière |
|---|---|---|---|---|---|---|---|---|
| Modèle commun seul | 0,520 | 0,522 | 0,553 | 0,541 | 0,508 | 0,521 | 0,520 | 0,529 |
| + check-ins 1/jour | 0,556 | 0,564* | 0,610* | 0,668* | 0,717* | 0,720* | 0,742* | 0,675 |
| + check-ins 2/jour | 0,552 | **0,575*** | 0,639* | 0,710* | 0,740* | 0,751* | 0,762* | **0,704** |
| + check-ins 4/jour | 0,580 | 0,599* | 0,676* | 0,725* | 0,760* | 0,773* | 0,788* | 0,727 (meilleure méthode : 0,729) |

**Lecture des courbes** (M) :
- **Énergie.**
  - Gain fiable à partir de **5–9 check-ins / jours 4–7**.
  - AUROC au sein d'une personne : 0,560 → 0,596 (Δ +0,036 [+0,021 ; +0,052]).
  - Brier : 0,246 → 0,227.
  - Les probabilités s'étalent : p10–p90 passe de 0,386–0,514 à 0,280–0,649.
- **Agrément.** Le gain est fiable dès les **jours 2–3**. Au sein d'une personne : +0,058.
- **Stress.** 0,541 → 0,665 (même calendrier que l'énergie) [PS Q2, Q6].
- **Même groupe de personnes.** La montée ne vient pas d'un changement de population : sur les 127 personnes présentes au moins 29 jours, on retrouve 0,656 → 0,697 (`extra.md`).

**Courbe en fonction du nombre de check-ins** (énergie, 2/jour, M) :

| Check-ins avant la prédiction | 0 | 1–4 | 5–9 | 10–19 | 20–39 | 40–59 | 60+ |
|---|---|---|---|---|---|---|---|
| Modèle commun | 0,583 | 0,552 | 0,574 | 0,566 | 0,560 | 0,543 | 0,475 |
| Décalage qui oublie | 0,583 | 0,553 | 0,622* | 0,662* | 0,692* | 0,695* | 0,699* |

Source : `compact.md`. Le pilote, avec 30 à 60 réponses par personne (E), tombe exactement dans la zone 10–59.

**Choix de la méthode** (M) [PS Q3] :
- **Le décalage qui oublie (`m1d`) est le meilleur ou à égalité à tous les budgets.** C'est un seul paramètre par personne, avec un a priori N(0 ; 1,0²) sur le logit et une constante d'oubli **T = 2 jours** (4 jours à 1 réponse/jour). Pour l'agrément, les réglages sont τ = 1,5 et T = 2 jours (`summary_valence_past_r2.md`).
- **Ce que la richesse n'ajoute pas.**
  - Des pentes personnelles : +0,003.
  - Des features d'historique : à égalité.
  - Les deux combinés : −0,003.
- **Sans oubli**, le décalage aide l'AUROC poolée (0,624) mais pas le classement au sein d'une personne (−0,002).

**Arrêt des réponses** (énergie, 2/jour, lignes à partir du jour 15, 145 personnes). Variante `m1d_now` : l'oubli court jusqu'à l'instant de la prédiction, donc le décalage revient vers 0 (M) [PS Q7] :

| Âge de la dernière réponse | 0 | 1 jour | 2 jours | 4 jours | 7 jours | Modèle commun |
|---|---|---|---|---|---|---|
| AUROC poolée | 0,693 | 0,667 | 0,639 | 0,590 | 0,554 | 0,546 |
| AUROC au sein d'une personne | 0,585 | 0,571 | 0,558 | 0,554 | 0,555 | 0,557 |

Source : `extra.md`.

**D'où vient le gain** (M) [PS Q3–Q4] :
- **Décomposition.** Partant de 0,555, apprendre le niveau habituel de la personne mène à ≈ 0,62 (contrôle par permutation dans le temps). Suivre son état récent mène à 0,666.
- **L'historique des réponses fait l'essentiel.**
  - Énergie : historique seul 0,652. La montre ajoute **+0,007** (poolé) et **+0,015** (au sein d'une personne) par-dessus les check-ins et l'heure.
  - Agrément : historique seul 0,700. La montre ajoute **+0,001**.
- **Un décalage figé ne se transfère pas.** Appris sur les premiers check-ins, il n'aide plus en semaine 3.
- **Poser la question aux moments incertains** fait légèrement moins bien qu'au hasard (0,665 → 0,660).

### 2.5 LifeSnaps (M) [LS]

| Question | Résultat | Source |
|---|---|---|
| Licence, accès | CC BY 4.0, ouvert, zip de 615 Mo ; 63 participants avec humeur, 60 utilisables pour le modèle | `v2/lifesnaps/out/zip_listing.txt`, `labels_summary.json` |
| Signaux de nuit seuls (RMSSD, FC non-REM, FC repos, stades, efficacité, température, respiration, SpO2) | AUROC 0,47–0,53, intervalles contenant presque tous 0,5 | `results_compact.txt` |
| v1 + 9 signaux de nuit (activation) | −0,001 ± 0,004 (5 groupes) ; −0,004 ± 0,006 (10 × 5, 15/50 groupes positifs) | `results.json`, `extra_checks.json` |
| FC : effet propre au jeu | v1 − heure seule +0,012 ± 0,011 (4/5) : la FC aide, comme sur EmoPhone | `results.json` |
| Modèle EmoPhone figé appliqué à LifeSnaps | **0,471** [0,446 ; 0,497] ; partie heure seule **0,416** (effet de l'heure de signe inverse) ; termes FC seuls 0,530 ; z-scores FC seuls 0,538–0,545 | `results.json`, `extra_compact.txt` |
| Effets personnels des signaux de nuit | Dispersion observée ≈ bruit d'échantillonnage (ex. activation ~ RMSSD : 0,179 observé contre 0,211 attendu) | `extra_checks.json` |
| Personnalisation (38 personnes avec ≥ 40 réponses ; modèle personnel sur la 1re moitié, mélange en log-odds avec le modèle commun, k = 30) | Activation, AUROC poolée **0,585 → 0,626** ; moyenne par personne 0,592 → 0,583 (pas de gain de classement) | `results.json` |

---

## 3. Trois architectures possibles

### A. « Modèle commun soigné » (sans questions)

- **Ce que c'est.** Le même type de modèle, mieux branché.
- **Composants.**
  1. Une régression logistique à **17 features** : les 13 de v1 + `raw_hr_30`, `raw_hr_60`, `raw_log_steps_30`, `raw_log_steps_60`.
  2. **e0 = rang** de la probabilité parmi les prédictions récentes de la personne.
  3. Une **valence** interne comme seconde sortie faible : régression logistique sur les mêmes 17 entrées, au plus une légère inclinaison de la positivité dans la file.
- **Gain mesuré** (M).
  - Valence 0,559 contre 0,534 (heure seule) et 0,542 (13 features).
  - Arousal +0,003 à +0,008, non robuste.
  - Le rang étale e0 de 0,35–0,55 à 0,03–0,98 sans perte significative [NF Q5, MT §5].
  - Pas de 2-D utile : les deux sorties corrèlent à 0,71.
- **Coût** (E).
  - Python 1–2 jours-personne : `features.py`, table, D-3, export, fixtures.
  - Swift 1–2 jours : `FeatureBuilder` expose 4 valeurs intermédiaires déjà calculées ; seconde sortie ; historique pour le rang.
  - **Aucun écran, aucune nouvelle autorisation.**
- **Risques.**
  - Changer le contrat §6 impose de réentraîner, refaire les fixtures golden et refaire le test D-3.
  - Le gain sur l'arousal n'est pas démontré.
  - La valence restera surtout une copie de l'arousal.
  - Le rang demande environ une journée d'historique.
  - Pour la présentation, cela reste « 17 entrées, 2 sorties ».
- **Décisions §3 touchées.**
  - « Modèle final : 13 features v1 » devient 17 features.
  - « Sortie = plus/moins activé » reçoit une valence interne.
  - Le sens de e0 (§8) change.

### B. « Harmony apprend de toi » (recommandée)

- **Ce que c'est.** Le modèle commun reste la base du jour 1. Les réponses de l'utilisateur le corrigent sur l'iPhone, et la file apprend de ses retours.
- **Composants.**
  1. **Modèle commun « corps »** : le modèle livré, 13 features et repli heure seule (ou 17 si D-3 le confirme, voir A). e0 est donné par le rang tant qu'il n'y a pas de réponse.
  2. **Couche personnelle (iPhone)** : deux décalages de logit qui oublient, `b_E` (énergie) et `b_V` (agrément), appris des check-ins en un geste. L'état devient 2-D (énergie, agrément) seulement quand des réponses d'agrément existent. Il est relié aux scores d'énergie et de positivité des morceaux.
  3. **Bandit de file** : Thompson sampling sur ~3 stratégies de file par situation. La récompense vient de « Did it fit? », des skips < 30 s et des likes, avec une probabilité minimale d'exploration journalisée.
- **Gain mesuré** (M, simulation EmoPhone, 2 check-ins/jour).
  - Énergie 0,555 → 0,666 sur la période, ≈ 0,69–0,70 dès le 15e jour.
  - Agrément 0,529 → 0,704.
  - Rien au jour 1 (identique au modèle commun) ; fiable dès le 4e jour (énergie) ou les jours 2–3 (agrément).
  - Le gain du bandit n'est pas mesurable hors ligne (E).
- **Coût** (E).
  - Python 2–3 jours : simuler la règle exacte de l'app, fixtures du décalage, script d'analyse du pilote.
  - Swift 5–8 jours : modèle `CheckIn`, notifications à actions, check-in dans l'app, couche personnelle et tests, journal, stratégies et bandit, export et suppression.
  - **Nouveaux écrans** à dessiner d'abord dans le canvas (section 5).
  - **Une nouvelle autorisation** : notifications. Aucun nouveau type HealthKit.
- **Risques** (section 9).
  - Taux de réponse sans rémunération.
  - Tension avec N1 « zéro effort ».
  - Transfert de la simulation (étudiants EmoPhone) à l'app.
  - Charge de travail face à M3.
  - Interaction avec l'A/B du pilote.
  - Les check-ins sont des données proches de la santé.
- **Décisions §3 touchées.**
  - « Pas d'entraînement sur chaque utilisateur ».
  - « Sortie = plus/moins activé ».
  - « Évaluation par personnes tenues à part » (ajout d'un protocole chronologique).
  - Plus N1/NFR5, le design comme source de vérité et le protocole du pilote (section 8).

### C. « Modèle personnel multi-signaux »

- **Ce que c'est.** B, plus des coefficients propres à chaque utilisateur sur l'HRV (SDNN), la respiration, la température de poignet, les stades de sommeil, `timeInDaylight`, le bruit ambiant et le type d'activité. Éventuellement des modèles plus gros (boosting, MLP, modèle séquentiel).
- **Pourquoi les preuves ne le soutiennent pas aujourd'hui** (M sauf mention).
  1. **Signaux de nuit.** Sur LifeSnaps, seuls ils donnent 0,47–0,53. Ajoutés à v1 : −0,001 à −0,004. Sur UC Irvine (Oura), aucune mesure de nuit ne dépasse |r| = 0,085 avec l'humeur du jour au sein d'une personne [LS §4, R1].
  2. **Pas d'effets personnels à apprendre.** Sur LifeSnaps, la dispersion des effets personnels ressemble à du bruit d'échantillonnage [LS §6].
  3. **Pentes personnelles.** Elles n'ajoutent que +0,002 à +0,003 sur EmoPhone [PS Q3].
  4. **Modèles plus gros.** Aucune famille ne bat la régression logistique, et le réglage imbriqué choisit toujours la régularisation maximale (C = 0,001) [MT §3].
  5. **Couverture et compatibilité.** RMSSD et respiration ne sont connus que pour 48 % des réponses, SpO2 pour 29 %. Le RMSSD Fitbit n'est pas le SDNN Apple [LS §2, §6].
  6. **Données personnelles insuffisantes** (E). Un coefficient personnel sans a priori demande ~60–100 réponses par personne, soit 1–2 mois à 2/jour. Le pilote en donnera 30–60. Sur K-EmoPhone, on gagne moins de 2 % avec ~70 réponses [QS Q4, Q6].
- **Coût** (E).
  - 5 nouveaux types HealthKit et Motion & Fitness.
  - Refonte de l'écran `V2-Onb4-Sante`.
  - Un pipeline sans a priori commun.
- **Ce qu'on propose à la place.** Journaliser ces signaux sur l'iPhone, en option, après le cours. Préenregistrer 3 hypothèses LifeSnaps : sommeil ↔ agrément ρ +0,096 ; respiration ↔ activation ρ −0,087 ; FC de repos ↔ activation ρ −0,049.

### Comparaison

| | A | B (recommandée) | C |
|---|---|---|---|
| Énergie, AUROC | 0,563 → 0,566–0,571 (M) | 0,555 → 0,666 sur la période, ≈ 0,69 dès le jour 15 (M, simulation) | pas mieux que B (M : nuits et pentes ≈ 0) |
| Agrément | 0,559, mais replié sur l'énergie (M) | 0,529 → 0,704 (M, simulation) | idem B |
| Jour 1 | modèle commun | modèle commun (identique) | modèle commun |
| Paramètres appris | 18 + 18 | 14 + 2 par personne + 24 par personne | dizaines par personne |
| Nouveaux écrans / autorisations | aucun / aucune | oui / notifications | oui / 5+ types HealthKit |
| Effort de l'utilisateur | aucun | 1 geste, ~2 fois/jour, optionnel | idem B |
| Charge d'équipe d'ici le pilote (E) | 2–4 jours | 7–11 jours (version minimale ~5–6) | hors de portée |

---

## 4. Architecture recommandée en détail

### 4.1 Flux de données

```
                       ┌──────────────────────────── iPhone (tout local) ────────────────────────────┐
 Apple Watch ─► HealthKit ─► FeatureBuilder (13 features §6) ─► MODÈLE 1 : commun « corps »         │
                       │                                         (LR Core ML ; repli heure seule)    │
                       │                                         sortie : logit z_E(t)               │
                       │                                                │                            │
 Question 1 geste ─────┼─► CheckIn (SwiftData) ─► étiquette « au-dessus de ton habitude »            │
 (Home / notification  │   (réponse, heure, z_E et z_V      (réponse > moyenne de tes réponses       │
  / Apple Watch)       │    au moment de la réponse)          des 14 jours précédents, ≥ 5)         │
                       │                                                │                            │
                       │                                   MODÈLE 2 : couche personnelle             │
                       │                                   b_E(t), b_V(t) recalculés à la volée      │
                       │                                   e = σ(z_E + b_E)   v = σ(z_V + b_V)        │
                       │                                                │                            │
 Tap situation ────────┼─► MODÈLE 3 : bandit de file ─► stratégie s ─► QueueBuilder §8 (e, v, s) ──┼─► Spotify
                       │        ▲                                                                    │
                       │        └── récompense : Did it fit? (Yes/Nope), skips < 30 s, like ◄────────┤
                       └──────────────────────────────────────────────────────────────────────────────┘
 Worker Cloudflare : inchangé (titres + artistes seulement).
```

### 4.2 Les trois modèles

| Modèle | Entrées | Sortie | Paramètres (approx.) | Appris où, quand |
|---|---|---|---|---|
| 1. Commun « corps » | 13 features §6 (FC, pas, sommeil, heure) ; repli 3 features heure | logit `z_E` de « plus activé que d'habitude » | 13 coefficients + 1 constante (+ médianes, moyennes, écarts-types) ; heure seule 4 ; variante 17 features : 18 | Ordinateurs de l'équipe, une fois, sur EmoPhone ; figé dans l'app |
| 1 bis. A priori d'agrément | aucune (taux de base 0,566) pendant le pilote ; modèle valence 17 features seulement s'il passe D-3 | logit `z_V` | 1 (ou 18) | Idem |
| 2. Couche personnelle | check-ins des 14 derniers jours : (heure, étiquette, `z` stocké) | `b_E`, `b_V`, puis `e`, `v` | **2 nombres par utilisateur** ; hyper-paramètres fixes τ_E = 1,0, τ_V = 1,5, T = 2 jours | iPhone, recalculé à chaque prédiction (Newton à 1 dimension) |
| 3. Bandit de file | situation, stratégie, récompense | probabilité de chaque stratégie | 4 situations × 3 stratégies × 2 (α, β) = **24 nombres par utilisateur** | iPhone, après chaque file |

Au total, moins de 100 paramètres, tous lisibles et tous sur le téléphone.

L'a priori d'agrément est une inférence (E). Pour la valence, l'historique seul (0,700) égale presque le décalage posé sur le modèle valence 13 features (0,704) [PS Q6]. Un a priori constant évite donc tout changement du contrat §6 avant le pilote. Ce choix précis n'a pas été simulé : il faut le simuler avant le pilote (section 6).

### 4.3 Règle de mise à jour du décalage (`m1d_now`, [PS Q3, Q7, Q8])

```
Pour une dimension (E ou V), à l'instant t, avec les check-ins i des 14 derniers jours :

  w_i(t) = exp( −(t − t_i) / T )                         oubli, T = 2 jours (4 jours si ~1 réponse/jour)
  b(t)   = argmin_b  Σ_i w_i(t) · ℓ( y_i , σ(z_i + b) )  +  b² / (2 τ²)
           ℓ(y, p) = −[ y·log p + (1 − y)·log(1 − p) ]    a priori N(0, τ²) : τ_E = 1,0, τ_V = 1,5

  Newton, 3 à 5 pas à partir de b = 0 :
    g = Σ_i w_i (σ(z_i + b) − y_i) + b / τ²
    H = Σ_i w_i σ(z_i + b)(1 − σ(z_i + b)) + 1 / τ²
    b ← b − g / H

  Probabilité personnelle :  p(t) = σ( z(t) + b(t) )
```

- **Étiquette.**
  - `y_i = 1` si la réponse dépasse la moyenne des réponses de l'utilisateur sur `[t_i − 14 j, t_i)`, avec au moins 5 réponses. C'est la même règle que l'étiquette EmoPhone `L_past`.
  - S'il y a moins de 5 réponses, le check-in est stocké mais pas encore utilisé.
  - `z_i` est le logit du modèle actif au moment de la réponse, stocké avec le check-in. Si le modèle commun change, on recalcule `z_i` ou on remet `b` à 0.
- **Propriétés.**
  - Sans réponse, `b = 0` exactement : c'est le modèle commun.
  - Une réponse pèse à moitié après T·ln 2 ≈ 1,4 jour.
  - Avec τ = 1, les données de l'utilisateur pèsent autant que l'a priori après ≈ 4 réponses récentes (E, arithmétique de Laplace [QS Q4]).
  - Quand les réponses s'arrêtent, les poids tendent vers 0 et `b` revient vers 0, donc vers le modèle commun.
  - Rien ne tourne la nuit : aucun `BGProcessingTask` n'est nécessaire.
- **Absence de réponse.** « Inconnu n'est pas zéro » : une notification sans réponse ou un « Not now » n'est **pas** une réponse « Low ». C'est une absence d'information.
- **Ce qui reste à valider** (E).
  - `m1d_now` n'a été évalué que dans l'expérience d'arrêt (à l'âge 0 : 0,693 contre 0,694 pour `m1d`). Sa courbe complète et son propre réglage restent à faire (3–6 min de calcul par configuration [PS Q1]).
- **e0 et état 2-D** (proposition, E).
  - e0 = `σ(z_E + b_E)` dès que l'utilisateur a au moins 5 réponses étiquetées dans les 14 derniers jours. Sinon, e0 = rang personnel (A). Le seuil exact de bascule est à fixer dans la simulation d'avant pilote.
  - v0 = `σ(z_V + b_V)` seulement si des réponses d'agrément existent. Il fixe alors le point de départ de la positivité, qui va vers le but de la situation (Stress, Low energy : positif). Ce terme de distance remplace la pénalité fixe « +0,2 si positivité < 0,5 » de §8.
  - Sans réponse d'agrément, la file garde la règle §8 actuelle.
  - Les paramètres de file sont des réglages produit : rien n'est mesurable en AUROC.

### 4.4 Le bandit de file

- **Bras.** 3 stratégies par situation, à choisir en équipe parmi les exemples des notes [QS Q4] :
  - « partir de l'état puis aller vers le but » (règle §8 actuelle) ;
  - « aller directement au but » ;
  - « but ± un pas » ;
  - « positivité haute ou neutre ».
- **Récompense dans [0, 1].**
  - « Did it fit? » (design `V2-Feedback` : Yes = 1, Nope = 0, Skip = pas de réponse).
  - Sinon, 1 − la part de morceaux passés avant 30 s.
  - Un petit bonus si un morceau est aimé, plafonné à 1.
  - Mise à jour Beta : α += r, β += 1 − r.
  - Les skips dépendent en partie du morceau lui-même, d'où le seuil relatif de 30 s [QS Q3].
- **Exploration.** Chaque probabilité est bornée à au moins 0,1–0,2, comme le plancher de HeartSteps (ε₀ = 0,2). La probabilité utilisée est **journalisée** à chaque file, pour pouvoir rejouer l'analyse plus tard [QS Q4].
- **Priors.** Neutres ou pessimistes (Deezer trouve Beta(1,99) meilleur que Beta(1,1)). Les récompenses restent séparées par situation.
- **À ne jamais faire.** Entraîner le modèle d'état sur « Did it fit? ». Cette réponse est la récompense de la file, pas une étiquette d'état.
- **Réalisme** (E). Avec 14 à 40 files par personne sur 2 semaines, le bandit commence à peine à départager les bras. Il faut parler d'« adaptation », pas d'« apprentissage » [QS Q4].

### 4.5 Ce qui se passe au fil du temps (simulation EmoPhone, 2/jour, énergie)

| Moment | Comportement | Chiffres (M) |
|---|---|---|
| Jour 1, avant toute réponse | `b = 0` : modèle commun exactement ; e0 par le rang | AUROC du jour 1 : 0,540 dans les deux cas |
| Jours 2–3 | Premières étiquettes. Dans l'app, la référence « habitude » doit d'abord accumuler 5 réponses (E) | Énergie 0,562 contre 0,552 (n.s.) ; agrément 0,575* contre 0,522 |
| Jours 4–7 (5–9 réponses) | Gain fiable | Énergie 0,640* contre 0,571 ; agrément 0,639* contre 0,553 |
| Jour 15 et après | Plateau | Énergie 0,689–0,697 ; agrément 0,740–0,762 |
| L'utilisateur arrête de répondre | Retour progressif au modèle commun | 0,693 → 0,639 (2 jours) → 0,590 (4 jours) → 0,554 (7 jours) ; modèle commun 0,546 ; jamais en dessous au sein d'une personne (0,555 contre 0,557) |

### 4.6 Ce que l'utilisateur voit, et ce qui ne quitte jamais le téléphone

- **Visible** (textes à dessiner dans le canvas et à faire relire par Cyprien, TODO 3.20).
  - Une ligne optionnelle « Energy right now? » sur Home, avec la dernière réponse marquée.
  - Un compteur « N answers this week », avec un texte du type « Harmony is learning your usual ».
  - Une raison de file en phrases fixes qui parle d'énergie, jamais d'émotion. Exemple : « Your recent answers: more energy than your usual, starting livelier ».
  - Dans Settings : « Questions » (activer, plages horaires) et « Reset what Harmony learned ».
- **Jamais visible.**
  - Probabilités, AUROC, « précision ».
  - Noms d'émotions (calm, stressed, happy…), niveau de stress.
  - Toute promesse médicale.
  - L'estimation du modèle **avant** de poser la question, pour éviter l'effet d'attente [QS Q4].
- **Reste sur l'iPhone.** Échantillons et résumés HealthKit, check-ins, `z_i`, décalages, état du bandit, journal des files. Le Worker ne reçoit toujours que titres et artistes.
- **Analyse du pilote.** Les agrégats sont calculés sur l'iPhone et exportés seulement avec consentement (décision 8.1). Les check-ins sont traités comme des données de santé.

---

## 5. Système de questions

### 5.1 Libellés

L'app est en anglais (textes du design) ; le français est donné pour la discussion.

| Usage | Anglais (app) | Français | Échelle |
|---|---|---|---|
| Énergie, notification (principale) | « Quick check: energy right now? » ; actions **Not now** · Low · Medium · High | « Petit point : ton énergie maintenant ? » ; Pas maintenant · Basse · Moyenne · Haute | 3 niveaux |
| Énergie, dans l'app | « Energy right now », de *Low* à *High*, marqueur « Last » | « Énergie maintenant », de *Basse* à *Haute*, marqueur « Dernière » | 7 crans (−3..+3, comme EmoPhone) |
| Agrément, dans l'app seulement, facultatif | « How does right now feel? », de *Unpleasant* à *Pleasant* | « Comment est ce moment ? », de *Désagréable* à *Agréable* | 7 crans |

Règles de formulation [QS Q1] :
- **Demander le niveau absolu, pas « par rapport à d'habitude ».** Les items formulés en relatif sont déconseillés ; afficher la réponse précédente comme repère donne moins d'erreur (Dejonckheere 2024). L'app calcule elle-même « au-dessus de ton habitude ».
- **Mots interdits.** Les ancres d'EmoPhone (« calm », « excited »), « stressed? » et les étiquettes Apple State of Mind sont exclus par la règle « jamais d'émotion nommée ».
- **Smileys.** Zone grise : l'équipe doit trancher explicitement.
- **Pas de question de stress.** Le stress est surtout l'inverse de la valence au sein d'une personne [R1], et l'agrément couvre ce besoin.
- **Correspondance 3 niveaux → échelle.** Proposition (E) : Low/Medium/High = −2/0/+2. Ce choix est à vérifier dans la simulation d'avant pilote, en ramenant les réponses EmoPhone à 3 niveaux.

### 5.2 Canaux

1. **Avant la file, dans l'app** (au moment de l'événement). C'est l'étiquette la plus propre, car elle vient avant que la musique n'agisse.
   - Elle doit rester **optionnelle** : une ligne sur Home qu'on peut ignorer. Une question obligatoire casserait N1 (« un tap suffit ») et NFR5 (≤ 2 taps jusqu'à la musique).
2. **2 notifications locales par jour**, à heure aléatoire dans des plages choisies par l'utilisateur (ex. 10–13 h et 15–19 h). Elles couvrent les moments où l'app n'est pas ouverte, ce qui réduit le biais « moments d'ouverture de l'app ».
   - La réponse se fait d'un geste sur l'écran verrouillé.
   - Les notifications locales sont **relayées sur l'Apple Watch sans app watchOS**, et l'action s'exécute en arrière-plan sur l'iPhone [QS Q5].
   - **« Not now » doit être la première action** : le Double Tap de la montre déclenche la première action non destructive.
3. **Après la file** : « Did it fit? » existant. C'est la récompense du bandit, jamais une étiquette d'état.
4. **Plus tard, en option.**
   - Re-poser la question environ 1 fois sur 10, quelques minutes après, pour mesurer le bruit des réponses (Dejonckheere 2022).
   - Widget ou Control comme simple point d'entrée : ils sont inactifs écran verrouillé.
   - `HKStateOfMind` en écriture (agrément seulement, opt-in). Inconvénient : l'app Santé affichera ses propres mots d'émotion.

### 5.3 Règles de moment et limites de charge

- **Nombre** : au plus 2 notifications par jour par défaut, au plus 4 sollicitations par jour au total. Ni rappel ni « série » à entretenir.
- **Espacement** : au moins 2 h entre deux notifications, aucune pendant la plage de sommeil.
- **Après une file** : aucune notification dans les 60 min. Les réponses données 30–60 min après une file sont marquées et exclues de l'apprentissage (boucle musique → réponse) [QS Q4].
- **Au hasard** : ne pas choisir les moments « incertains », qui ne font pas mieux que le hasard (M) [PS Q7].
- **Désactivation** : un interrupteur « Questions » ; l'app fonctionne entièrement sans.
- **Notifications facultatives** : App Store 4.5.4 interdit d'exiger les notifications et d'y mettre des informations sensibles. Le texte reste donc neutre, sans valeur de santé.
- **Volume attendu** (E). Pour un pilote de 2 semaines sans rémunération, environ **30–60 réponses par personne**, soit 150–300 pour 5 personnes.
- **Taux de réponse attendu.** Le format en un geste est ce qui soutient le taux de réponse : 81,2 % en µEMA contre 64,5 % en EMA classique, et 67,6 % sur 6 mois sans rémunération liée aux réponses (M, littérature) [QS Q2].

### 5.4 Données stockées (SwiftData, local)

- **`CheckIn`** :
  - heure de la réponse et canal (Home, notification, montre) ;
  - heure d'envoi de la notification ;
  - réponse énergie (−3..+3) et réponse agrément (facultative) ;
  - `z_E` et `z_V` au moment de la réponse, avec le mode actif (corps ou heure seule) ;
  - minutes depuis la dernière file.
- **`QueueRecord`** existant, complété par : la stratégie, la probabilité de la choisir, la récompense, et en mode ombre `p_commun` et `p_perso` au départ de la file.
- **Journal prédictif du pilote** : à chaque check-in étiqueté, `p_commun` et `p_perso` calculées **avant** la mise à jour, avec le jour d'utilisation.
- **Durée de conservation** : au-delà de 14 jours, un check-in ne pèse plus rien dans le calcul (poids < e⁻⁷). Une durée à fixer (ex. 30 jours) doit être affichée dans My Data.
- **Écran verrouillé** : une réponse donnée téléphone verrouillé ne doit pas dépendre d'un stockage en protection `.complete`. Il faut vérifier la classe de protection du store SwiftData, ou passer par une petite file d'attente fusionnée au lancement [QS Q5].
- **Export et suppression (N4, FR13, TODO 3.19)** : les check-ins et l'état du bandit entrent dans l'export JSON et dans la suppression totale. Ajouter « Reset what Harmony learned », qui met `b` à 0 et vide les check-ins et le bandit.

### 5.5 Design d'abord

Aucun de ces écrans ni aucune de ces notifications n'existe dans `docs/design/`, qui contient 18 écrans. La règle UI de CLAUDE.md impose de les **dessiner d'abord dans le canvas claude.ai**, de recopier les fichiers dans `docs/design/` et de mettre à jour son README avant d'écrire une vue. Écrans concernés :
- `V2-Accueil` : ligne énergie ;
- une nouvelle feuille de check-in, avec agrément facultatif ;
- une étape d'onboarding qui explique les questions et demande l'autorisation des notifications ;
- le texte et les actions de la notification ;
- `V2-Reglages` : « Questions », plages, réinitialisation ;
- `V2-MesDonnees` : check-ins ;
- `V2-APropos` : paragraphe sur la personnalisation locale ;
- éventuellement un indicateur « learning » sur Home ou dans le lecteur.

---

## 6. Plan par échéance

### Avant M2 (29 nov.) : garder le modèle livré, mesurer et documenter

| Action | Qui (indicatif) | Durée (E) |
|---|---|---|
| Rendre les groupes de `ml/train.py` déterministes (annexe 10.1), relancer 2.8–2.10, mettre à jour les écarts-types de §6.5 | L/C | 0,5 j |
| Écrire **avant tout calcul** le critère d'adoption du jeu 17 features et de la sortie valence (§3), puis lancer **un seul** test D-3 (ajustement sur D-1 + D-2) | L | 1 j |
| Même candidat sur LifeSnaps, en test externe secondaire : modèle entier, partie FC et partie heure seule **notés séparément** | L/C | 0,5 j |
| Ajouter à la démo M2 (2.36) : mode corps 0,573 contre 0,524 ; aucune famille ne bat la régression logistique ; test LifeSnaps | tous | — |
| Réunion : décisions de la section 8 (il faut les prendre tôt, car design et Swift des check-ins démarrent juste après M2) | tous | — |
| Corrections de documentation du tour précédent ([R1], dernière section) | DOC | 0,5 j |

Critère proposé pour le changement de modèle commun (E, à valider en équipe avant le calcul) : sur D-3, testé une seule fois, le jeu 17 features remplace v1 si :
1. son AUROC d'arousal est ≥ celle de v1 sur D-3 (0,576) ;
2. sa balanced accuracy n'est pas plus basse ;
3. la sortie valence dépasse l'heure seule d'au moins +0,02.

Sinon, on garde v1. **Intégration dans l'app** : seulement si elle est prête et couverte par les fixtures golden avant le 5 déc. Sinon, après le pilote. Le modèle est figé pendant le pilote dans tous les cas.

### Avant M3 (6 déc.) et le pilote (7 déc.) : ce qui doit exister pour collecter les check-ins et tracer la courbe

**Version minimale (E ≈ 5–6 jours-personne)**, à faire passer avant le reste :
1. **Design** dans le canvas (section 5.5), copié dans `docs/design/`, textes relus (3.20).
2. **Python.**
   - Simuler la **règle exacte de l'app** : `m1d_now`, réponses ramenées à 3 niveaux, référence « habitude » calculée sur les seuls check-ins (2/jour), a priori d'agrément constant, règle de bascule de e0.
   - Produire des fixtures synthétiques pour le décalage (suites de check-ins → `b` et `p` attendus).
   - Écrire **le plan d'analyse du pilote avant le pilote**.
3. **Swift.** Modèle `CheckIn` ; notification locale à actions (« Not now » en premier, action en arrière-plan, vérifiée sur une vraie Apple Watch) ; ligne énergie sur Home ; couche personnelle **en mode ombre** (calcule et journalise `p_perso`, ne pilote rien), testée contre les fixtures ; export et suppression.
4. **File.** 3 stratégies par situation, **tirées au sort uniformément**, probabilité journalisée. C'est le meilleur jeu de données pour évaluer ensuite un bandit, et cela ne fausse pas l'A/B. Le tirage quotidien « corps » / « heure seule » (4.4) reste inchangé.
5. **Protocole du pilote (4.1).** Consentement écrit couvrant les questions, les notifications, les journaux locaux et l'export d'agrégats ; question d'éthique posée au cours (section 8.2).

**Si le temps le permet** : agrément dans l'app ; e0 par le rang (à décider d'ici M3, car il conditionne l'A/B [R1]) ; compteur « answers this week ».

Les tâches de la phase 3 (3.1–3.24) ne sont pas commencées. Ce lot entre en concurrence directe avec M3 : sans la version minimale, le pilote ne produira pas de courbe d'apprentissage.

### Pendant le pilote (7 déc. → ~21 déc.)

- Modèle commun figé, couche personnelle en ombre, stratégies tirées au sort.
- Point à mi-pilote (4.6) :
  - les notifications arrivent-elles sur la montre ?
  - combien de « Not now » et combien de réponses par jour ?
  - des plaintes de charge ?
- Ne rien régler en cours de route (sinon l'analyse prédictive n'est plus propre).

### Après le pilote, rapport final, démo

- **Analyse préenregistrée** (calculée sur l'iPhone, agrégats exportés avec consentement). Métriques réalistes avec 5 personnes au plus :
  - **Faisabilité** : réponses par jour et par personne, part des notifications répondues, délai de réponse, baisse sur 2 semaines, nombre d'étiquettes utilisables (cible 30–60 par personne).
  - **Premier test du modèle commun sur Apple Watch** : AUROC de `p_commun` contre les étiquettes « au-dessus de ton habitude », avec IC bootstrap par personne. Avec 150–300 étiquettes, l'IC fera environ ± 0,07–0,10 (E).
  - **Courbe prédictive réelle** : log-loss et Brier de `p_commun` contre `p_perso` (calculées avant chaque mise à jour) par tranche de jours (1–3, 4–7, 8–14), regroupées sur toutes les personnes. Ce sont des **points indicatifs** à superposer à la courbe simulée, pas une preuve.
  - **Files** : A/B corps contre heure seule (4.7) ; récompense moyenne par stratégie (pondération par probabilité inverse, rendue possible par la probabilité journalisée) ; skips < 30 s ; couverture de la montre (4.9).
- **Démo finale** : passer la couche personnelle et le bandit (Thompson) en mode actif sur le téléphone d'un membre qui a répondu pendant le pilote, et montrer son décalage appris.
- **Rapport** : courbe simulée + points du pilote + limites (section 9).

### Après le cours

- Pentes personnelles seulement au-delà de 60–100 réponses par personne (E).
- Journalisation optionnelle des signaux de C, avec les 3 hypothèses préenregistrées.
- Répliquer la courbe d'apprentissage sur LifeSnaps (~2,2 réponses par jour) comme second terrain.
- `HKStateOfMind` en option.

### Protocole de validation (s'applique à tout ce qui précède)

1. **Critères écrits avant les résultats**, consignés dans PROJECT.md §3, comme pour UC Irvine.
2. **Modèle commun** : validation croisée D-1 + D-2 sur des personnes entières, puis **une seule confirmation sur D-3** par changement, code figé avant. Si le changement est adopté, réentraîner le modèle final sur D-1 + D-2 + D-3 et refaire export, fixtures et tests Swift.
3. **LifeSnaps** en test externe secondaire, jamais décisif (étiquette convertie, 60 personnes, effets d'horaire). Toujours rapporter séparément le modèle entier, la partie FC et la partie heure seule.
4. **Couche personnelle** : évaluation chronologique (chaque réponse prédite avant d'être utilisée), personnes tenues à part pour les hyper-paramètres, étiquette `L_past`. Critère proposé pour la simulation d'avant pilote (E) : écart à `p_commun` sur l'AUROC poolée et le Brier strictement positif (IC excluant 0) à partir des jours 4–7 à 2/jour, et Brier pas plus mauvais que de +0,005 aux jours 1–3.
5. **Bandit** : aucune affirmation « il a personnalisé » sans le test de rééchantillonnage cité dans [QS Q4] (arXiv 2304.05365).

---

## 7. Pour la présentation

### 7.1 Pitch (3–4 phrases)

> Harmony part d'un modèle appris sur les données de 282 étudiants (EmoPhone) qui lit la fréquence cardiaque, les pas et le sommeil de l'Apple Watch. Ce modèle commun sait déjà mieux que l'horloge quand tu es plus activé que d'habitude. Chaque réponse en un geste à « Energy right now? » le corrige pour toi, sur ton iPhone, sans jamais envoyer tes données. En simulation, après quatre jours à deux réponses par jour, la prédiction progresse nettement, et la file apprend en parallèle quelle façon d'enchaîner les morceaux te convient, d'après tes skips et tes « Did it fit? ».

### 7.2 La figure à montrer

- **Titre** : « AUROC selon les jours d'utilisation : modèle commun contre modèle personnalisé ».
- **Axe x** : tranches de jours (1, 2–3, 4–7, 8–14, 15–21, 22–28, 29+). **Axe y** : AUROC de 0,50 à 0,80.
- **Courbes, panneau énergie** (tableau 2.4) :
  - modèle commun plat (0,52–0,57) ;
  - personnalisé à 1, 2 et 4 réponses par jour : 0,540 → 0,640 (jours 4–7) → 0,689 (jours 15–21) pour 2/jour.
- **Second panneau, agrément** : 0,529 → 0,704 sur la période.
- **Encart « si tu arrêtes de répondre »** : 0,693 → 0,554 en 7 jours.
- **Repères** : la ligne « heure seule » (0,534) et le point « mode corps » (0,573).
- **Légende obligatoire** : « simulation sur EmoPhone (étudiants, Fitbit), réponses tirées au hasard dans la journée, étiquette relative aux 14 jours précédents ».
- **Après le pilote** : y superposer les points mesurés.

### 7.3 Le schéma « 3 modèles »

Trois blocs de gauche à droite, tous dans un cadre « iPhone » :
1. **Modèle commun** (14 paramètres, appris une fois sur EmoPhone, figé) : FC, pas, sommeil, heure → énergie de départ.
2. **Couche personnelle** (2 nombres, appris à chaque réponse, oublie en ~2 jours) : tes réponses → décalage énergie et agrément.
3. **Bandit de file** (24 nombres, appris à chaque file) : skips, likes, « Did it fit? » → stratégie de file.

Une flèche sort vers Spotify. Seuls « titres + artistes » sortent vers le Worker. Ce schéma remplace avantageusement « 13 entrées, 1 sortie » : trois modèles qui coopèrent, moins de 100 paramètres, aucune donnée de santé hors du téléphone.

### 7.4 Formulations honnêtes

- **À dire.**
  - « En simulation sur des données d'étudiants (EmoPhone), pas encore sur des utilisateurs Apple Watch. »
  - « L'essentiel du gain vient de tes propres réponses : ton niveau habituel et ton état des derniers jours. La montre ajoute peu une fois qu'on a tes réponses (+0,007 pour l'énergie, ≈ 0 pour l'agrément). »
  - « Rien ne change le premier jour ; le gain devient fiable vers le quatrième. »
  - « Sans réponses récentes, l'app revient au modèle commun. »
- **À éviter.**
  - « apprend comment ton corps réagit » : un décalage seul ne change pas le classement de tes moments par la montre [PS Q3] ;
  - « précision », « détecte ton stress », « comprend tes émotions » ;
  - toute promesse de santé (App Store 1.4.1, NFR7).
- **Si on cite 0,56 → 0,67** : préciser « AUROC poolée sur la période, 2 réponses par jour ». Au sein d'une personne, le gain est plus petit (0,560 → 0,596).

---

## 8. Décisions d'équipe à prendre

### 8.1 Décisions de PROJECT.md §3 touchées

| Décision actuelle (§3) | Changement proposé | Pourquoi |
|---|---|---|
| « Pas d'entraînement sur chaque utilisateur » (mauvais premier jour) | « Pas de **modèle** entraîné par utilisateur. Une **correction personnelle** (2 décalages qui s'oublient), apprise sur l'iPhone à partir des réponses ; jour 1 = modèle commun exactement. » | La raison d'origine (le premier jour) est respectée, puisque `b = 0` ; gain mesuré en simulation |
| « Sortie = plus/moins activé que d'habitude, jamais une émotion » | Ajouter : « + une sortie interne *plus/moins agréable que d'habitude*, utilisée seulement si l'utilisateur répond à la question d'agrément ; jamais affichée. » | La valence issue des capteurs seuls se replie sur l'énergie (0,71) ; avec les réponses, 0,704 |
| « Entrées du modèle : heure, FC, pas, sommeil » | Inchangé pour le modèle commun (les fenêtres brutes restent FC et pas). Ajouter : « + réponses de l'utilisateur pour la couche personnelle. » | — |
| « Modèle final : 13 features v1 » | Passe à 17 features **seulement** si le critère D-3 (section 6) est satisfait ; intégration avant le 5 déc. ou après le pilote | Gain de valence robuste, gain d'arousal incertain |
| « Évaluation par personnes entières tenues à part » | Ajouter : « Couche personnelle : évaluation chronologique (chaque réponse prédite avant d'être utilisée) sur des personnes tenues à part ; jamais de découpage aléatoire. » | Règle de CLAUDE.md étendue à la personnalisation |
| « HRV lue mais hors modèle » ; « Modèle entraîné sur EmoPhone » | Inchangés. Ajouter : « LifeSnaps (CC BY 4.0) = test externe secondaire seulement. » | Section 3, C |

Autres décisions (hors §3) :
- **N1 / NFR5** : questions **optionnelles**, jamais un tap de plus obligatoire avant la musique.
- **§8** :
  - sens de e0 (rang, puis `p_perso`) ;
  - terme de positivité ;
  - stratégies de file (lesquelles, combien) ;
  - plancher d'exploration.
- **Pilote (4.4 / 4.7)** : couche personnelle en ombre et stratégies tirées au sort (recommandé). Alternative : couche active pour tous en 2e semaine, mais l'A/B ne porte alors que sur la 1re semaine.
- **Règle « les données de santé ne quittent jamais le téléphone »** : les check-ins sont-ils des données de santé ? Recommandation : oui. L'analyse du pilote se fait alors sur l'iPhone, et seuls des agrégats sont exportés, avec consentement (prolonge 4.5).
- **Design** : smileys oui ou non ; les écrans de la section 5.5 sont à dessiner dans le canvas avant tout code.

### 8.2 Consentement et éthique du pilote

- **App Store 5.1.3(iii)–(iv)** : une recherche sur des humains liée à la santé exige un consentement (nature, but, durée, risques, confidentialité, contact, retrait) **et** l'approbation d'un comité d'éthique indépendant [QS Q5].
- **Le cas d'Harmony.** Un pilote de 5 personnes au plus, via Xcode ou TestFlight, relève surtout du cours et de l'université. Mais il enregistre désormais des auto-évaluations liées à la santé.
- **À faire.**
  1. Demander à l'enseignant si un avis éthique est requis.
  2. Au minimum, un consentement écrit (4.1) qui couvre les questions, les notifications, les journaux locaux, l'export d'agrégats, ainsi que le retrait et la suppression.
  3. Ne rien écrire dans HealthKit pendant le pilote.
  4. Ne rien stocker dans iCloud (5.1.3(ii)).

---

## 9. Risques et limites

| Risque | Effet | Parade |
|---|---|---|
| Simulation ≠ app : étudiants coréens payés (~7 réponses/jour), check-in = réponse ESM recodée, référence « habitude » tirée de toutes les réponses ESM | Gains surestimés, démarrage plus tardif dans l'app (la référence se remplit à 2/jour) | Re-simuler la règle exacte de l'app avant le pilote ; présenter les chiffres comme « simulés » |
| La montée après la 1re semaine peut tenir au calendrier d'EmoPhone [PS Q2] | Plateau ≈ 0,69 moins sûr que le gain des jours 4–14 | Mettre l'accent sur « à partir du 4e jour » |
| Taux de réponse sans rémunération ; réponses sur écran verrouillé jamais mesurées comme EMA | Moins de 30 réponses, gain qui s'efface (moitié perdue après 4 jours) | Format en un geste, 2 par jour, pas de pression ; mesurer le taux au pilote |
| Charge face à N1 « zéro effort » | Rejet de la fonction | Tout optionnel, app complète sans questions |
| Réactivité, boucle musique → réponse, biais des moments d'ouverture | Étiquettes biaisées | Questions avant la file + au hasard ; exclure les 30–60 min après une file ; ne pas afficher l'estimation avant |
| Effet de l'heure propre à la population (LifeSnaps : partie heure seule 0,416) | Le repli heure seule peut se tromper avec assurance ; un décalage ne corrige pas la forme horaire | Le dire ; tester heure seule et FC séparément ; pentes horaires seulement après le cours |
| `sleep_unknown` = habitude de port de la montre dans EmoPhone (coefficient +0,109) [NF Q5] | Ne se transfère pas aux porteurs nocturnes d'Apple Watch | Le signaler, ne pas le « vendre » comme signal corporel |
| Pilote ≤ 5 personnes, 2 semaines | Pas d'AUROC fiable ; bandit non convergé (14–40 files par personne) | Pilote = faisabilité ; résultats indicatifs avec IC |
| Écueils du bandit (récompense liée à la situation, skips propres au morceau, boucle de rétroaction, fausse personnalisation) | Conclusions fausses | Récompenses par situation, skip relatif, plancher d'exploration, probabilité journalisée, test de rééchantillonnage |
| Relais vers l'Apple Watch sans app watchOS non confirmé sur watchOS 26/27 ; protection des fichiers téléphone verrouillé ; `HKStateOfMind` avec étiquettes vides non vérifié [QS Q5] | Réponses perdues | Tester sur appareil avant le 6 déc. |
| Confidentialité des check-ins, App Store 5.1.3, 4.5.4 | Refus ou problème éthique | Tout en local, export d'agrégats avec consentement, notifications facultatives |
| Charge d'équipe : phase 3 pas commencée | M3 en retard ou check-ins absents du pilote | Version minimale d'abord ; le reste après le pilote |
| Écarts-types des groupes dépendants de la machine | Chiffres non reproductibles d'un poste à l'autre | Annexe 10.1 |

---

## 10. Annexe

### 10.1 Rendre les groupes de `ml/train.py` déterministes

- **Constat** (M) [NF, en-tête] :
  - Sur ce Mac (NumPy 2.5.4), `train.folds()` redonne les mêmes moyennes que PROJECT.md §6.5 (0,534 / 0,554 / 0,563). Les écarts-types diffèrent : 0,009 contre 0,017 pour l'heure seule.
  - `GroupKFold` (scikit-learn 1.5.2) range les participants par nombre de réponses avec un `argsort` **non stable**. Il y a 41 nombres de réponses à égalité sur 191 participants, donc la répartition des égalités dépend de la plateforme et de la version de NumPy.
  - Tailles des groupes tests ici : 6 255 / 6 250 / 6 258 / 6 280 / 6 258.
- **Correctif proposé.** Même algorithme glouton, avec départage explicite par identifiant :

```python
def folds(participant, n_splits=N_FOLDS):
    """5 folds of whole participants, identical on every machine."""
    participant = np.asarray(participant)
    ids, inverse, counts = np.unique(participant, return_inverse=True, return_counts=True)
    order = sorted(range(len(ids)), key=lambda g: (-counts[g], ids[g]))  # ties broken by ID
    load, fold_of = np.zeros(n_splits), np.empty(len(ids), dtype=int)
    for g in order:
        f = int(np.argmin(load))  # lightest fold, lowest index on ties
        fold_of[g] = f
        load[f] += counts[g]
    test_fold = fold_of[inverse]
    return [(np.flatnonzero(test_fold != f), np.flatnonzero(test_fold == f)) for f in range(n_splits)]
```

- **Ensuite.**
  - Ajouter un test qui vérifie l'absence de recouvrement entre groupes et des tailles identiques d'un lancement à l'autre.
  - Noter les tailles de groupes (agrégat) dans §6.5, relancer 2.8–2.10 et mettre à jour les écarts-types.
  - Le test D-3 n'est pas concerné.
  - Les chiffres de ce tour ont été obtenus avec la répartition de ce Mac.

### 10.2 Corrections de documentation déjà relevées

Voir [R1], section « Corrections à reporter dans PROJECT.md et main.tex » : 297 enregistrements contre 282 personnes, items « PANAS » maison, fichiers D-3, Polar H10, formulations de `main.tex` l. 326 et 450. S'y ajoute l'écart d'écarts-types de §6.5 (10.1).

### 10.3 Hygiène des données

Tout est hors du dépôt, dans le scratchpad, qui peut être vidé au redémarrage. **Rien de ceci ne doit aller sur Git**, ni être collé dans un chat. À supprimer quand l'équipe n'en a plus besoin :

| Chemin (sous le scratchpad) | Contenu | Taille |
|---|---|---|
| `ext/lifesnaps/rais_anonymized.zip` | Archive LifeSnaps brute (Zenodo 7229547) | 587 Mo |
| `ext/lifesnaps/derived/` (`labels.csv`, `v1_features.csv`, `ext_features.csv`, `nights.csv`, `heart_rate.npz`, `steps.npz`, `user_index.json`, `types/`) | Tables par réponse, par nuit et par participant dérivées de LifeSnaps | 723 Mo |
| `ext/lifesnaps/early/` (`sema.bson`, `surveys.bson`, `daily.csv`, `hourly.csv`, `panas.csv`, `personality.csv`, `ttm.csv`, `breq.csv`, `head.bin`, `slice.bin`) | Extraits bruts LifeSnaps | 38 Mo |
| `v2/features/out/new_D1.csv`, `v2/features/out/new_D2.csv` | **Tables par réponse dérivées d'EmoPhone** (participant, heure, valence, nouvelles features) | 5,6 Mo + 10 Mo |
| `v2/features/out/*.log`, `v2/lifesnaps/out/s05.log`, `s06.log` | Journaux de calcul. Une recherche de motifs d'identifiants n'y trouve rien, mais ils n'ont pas été relus ligne à ligne | ≈ 1,4 Mo |

Le reste de `v2/*/out/` (fichiers `.txt`, `.md`, `.json` de résultats) contient des agrégats ; la même recherche n'y trouve aucun identifiant. Les tables `data/features/v1_D*.csv` du dépôt restent dans `data/` (ignoré par Git), inchangées.

### 10.4 Index des fichiers

Tout est sous le scratchpad indiqué en tête.

- **Notes de ce tour** : `research_notes/EmoPhone modèle enrichi et personnalisation/` — `models_targets.md`, `new_features.md`, `personalization_simulation.md`, `question_system_learning.md`, `lifesnaps.md`.
- **Rapport et notes du tour précédent** : `reports/Exploiter EmoPhone et autres datasets.md`, `research_notes/Exploiter EmoPhone et autres datasets/`.
- **Scripts.**
  - `v2/models/scripts/` (`q1_q2_targets_body.py`, `q1b_coefficients.py`, `q3_q5_q6_families.py`, `q4_multioutput.py`, `q4b_question.py`, `q6b_independence.py`, `common.py`) ;
  - `v2/features/scripts/` (`extract.py`, `evaluate.py`, `diag.py`, `probe.py`) ;
  - `v2/perso/scripts/` (`sim.py`, `lag.py`, `uncert.py`, `summarize.py`, `compact.py`, `extra.py`, `runall.sh`…) ;
  - `v2/lifesnaps/scripts/` (`download.sh`, `s02_extract.py` … `s06_extra.py`, `common.py`).
- **Sorties agrégées clés.**
  - Modèle commun : `v2/models/out/q1_q2.txt`, `q3_q5_q6.txt`, `q4.txt`, `q4b.txt`, `q6b.txt`.
  - Nouvelles entrées : `v2/features/out/eval_families.txt`, `eval_singles.txt`, `eval_q5_P.txt`, `eval_q5_P0.txt`, `diag.txt`.
  - Personnalisation : `v2/perso/out/overview.md` (tableaux par configuration et par jour), `compact.md` (par nombre de check-ins), `extra.md` (arrêt des réponses, incertitude, groupe de 29 jours), `summary_<cible>_<étiquette>_r<rythme>.md` (détail et réglages).
  - LifeSnaps : `v2/lifesnaps/out/results.json`, `results_compact.txt`, `extra_checks.json`, `extra_compact.txt`, `labels_summary.json`, `nights_inventory.json`.

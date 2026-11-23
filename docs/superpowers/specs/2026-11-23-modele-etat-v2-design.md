# Modèle d'état v2 — design (A « modèle commun soigné » + B « Harmony apprend de toi »)

> **Statut (23 nov. 2026)** : design proposé par Clément (choix A + B), **rien n'est implémenté**.
> Les décisions d'équipe du §11 ont été prises telles que proposées le 23 nov. 2026 et notées dans
> `docs/PROJECT.md` §3 (résumé en §6.8 et §8) ; les tâches du §10 sont dans `docs/TODO.md`, Phase 6.
> **Lecteur visé** : une future session Claude Code (ou un membre de l'équipe) qui écrira le plan
> (skill `superpowers:writing-plans`) puis implémentera, un paquet de travail par branche.
> **Preuves** : `docs/research/2026-11-23-modele-etat-v2/` (rapports, notes, scripts, résultats agrégés).

---

## 0. Avant de commencer (pour la session qui reprend ce design)

1. Lire `CLAUDE.md`, puis `docs/PROJECT.md` §3 (décisions), §6 (contrat des features), §8 (file),
   §11 (confidentialité), puis ce document en entier.
2. Vérifier dans PROJECT.md §3 que les décisions de §11 ci-dessous ont été prises et notées.
   Si l'une manque : **s'arrêter et demander** (règle CLAUDE.md « si la tâche contredit PROJECT.md »).
3. Vérifier que les paquets de travail ont été ajoutés à `docs/TODO.md` (proposition prête en §10).
   Une tâche TODO (ou un petit groupe) par session et par branche.
4. Règles dures inchangées : données santé jamais hors du téléphone ; jamais d'émotion nommée ;
   aucune promesse médicale ; évaluation par personnes entières tenues à part ; inconnu ≠ zéro ;
   aucune donnée EmoPhone/UC Irvine/LifeSnaps dans Git ; pas de co-auteur Claude dans les commits ;
   tout écran vient d'abord du canvas de design (`docs/design/`).

---

## 1. Intention

**Pourquoi.** Le modèle commun actuel (régression logistique, 13 features, une sortie) est au niveau
des meilleurs résultats publiés sur EmoPhone, mais ce niveau est bas (AUROC ≈ 0,56–0,58 sur des
personnes jamais vues) et ses probabilités sont tassées (≈ 0,36–0,55) : la file part presque toujours
du même point. Les expériences montrent que **plus de capacité ou plus d'entrées montre n'y change
presque rien**, alors que **les réponses de l'utilisateur lui-même** font passer l'AUROC simulée de
0,555 à ≈ 0,67–0,70. L'équipe veut aussi une architecture plus convaincante à présenter que
« 13 entrées, 1 sortie ».

**Idée.** Trois modèles, tous sur l'iPhone :
1. **Modèle commun « corps »** (EmoPhone, figé) : l'estimation du jour 1, mieux branchée (A).
2. **Couche personnelle** : deux nombres par utilisateur (énergie, agrément) appris de questions en un
   geste ; elle corrige le modèle commun et oublie en ~2 jours (B).
3. **Bandit de file** : choisit entre 3 stratégies de file par situation selon les retours
   (« Did it fit? », skips, likes) (B).

**Objectifs**
- G1. Jour 1 identique (ou meilleur) qu'aujourd'hui : sans réponse, l'app se comporte comme le
  modèle commun.
- G2. Une couche personnelle qui s'améliore avec les réponses, mesurable pendant le pilote
  (courbe « jour d'utilisation → AUROC », commune vs personnelle).
- G3. Un état 2-D (énergie, agrément) quand l'utilisateur répond à la question d'agrément, relié aux
  deux scores des morceaux.
- G4. Un point de départ de file (`e0`) qui varie vraiment d'un moment à l'autre.
- G5. Tout reste local ; l'app fonctionne entièrement sans répondre aux questions.

**Non-objectifs** : HRV, respiration, température, SpO2, lumière, bruit comme entrées (option C,
non soutenue par les données, §3) ; modèles plus gros (boosting, réseaux, séquences, modèles de
fondation) ; sortie stress ; localisation ; entraînement côté serveur ; app watchOS.

**Anti-objectifs** (échec même si « ça marche ») :
- une question obligatoire, ou plus de 2 taps entre le lancement et la musique (N1, NFR5) ;
- un mot d'émotion ou un niveau de stress affiché ; une promesse médicale ;
- une notification insistante (rappels, séries à entretenir) ou contenant une valeur de santé ;
- l'absence de réponse traitée comme une réponse « basse » ;
- le modèle d'état entraîné sur « Did it fit? » ;
- D-3 utilisée plus d'une fois par changement, ou un réglage fait en regardant D-3 ;
- des réponses ou des features qui quittent le téléphone sans consentement explicite.

---

## 2. Ce que les preuves disent (résumé)

Protocole commun : EmoPhone D-1 + D-2 (31 301 réponses, 191 participants-vagues), 5 groupes de
participants entiers (ceux de `ml/train.py`), réglages faits dans les groupes d'entraînement
seulement, **D-3 jamais ouverte**. Détails : `rapport-2-proposition-v2.md` §2 et `notes/tour2/`.

| Question | Résultat mesuré |
|---|---|
| Familles de modèles (LR réglée, interactions, HistGB, MLP, ensembles) | Aucune ne bat la LR simple de plus que l'écart entre groupes ; le réglage choisit toujours la régularisation maximale |
| Sorties multiples (multi-tâche, chaîne, régression centrée) | ≤ +0,004 d'AUROC ; stress = pas mieux que l'heure seule (0,540 vs 0,543) |
| Valence prédite par les capteurs | Corrélée à 0,71 avec l'énergie prédite : un état 2-D tiré des capteurs seuls se replie sur un axe |
| Mode « corps » (`z_hr_30` connu, 51,6 % des réponses) | Énergie 0,573 vs 0,524 pour l'heure seule sur les mêmes réponses |
| Nouvelles features : contexte de journée, veille, FC au repos, intensité (METs), type d'activité | ≈ 0 chacune |
| 4 valeurs brutes non référencées (`raw_hr_30/60`, `raw_log_steps_30/60`) → 17 features | Valence 0,559 (+0,017 ± 0,009, 5/5 groupes ; +0,016 avec sélection imbriquée) ; énergie +0,008 ± 0,010 (4/5 ; +0,003 en sélection imbriquée, non robuste). Effet « première semaine » (référence 7 jours pas prête) |
| `e0` = rang de la probabilité parmi les prédictions passées de la personne | Étale `e0` de 0,36–0,55 à 0,03–0,98 ; AUROC −0,005 ± 0,010 (n.s.) |
| Personnalisation simulée, 2 réponses/jour, étiquette « passé seulement » | Énergie 0,555 → 0,666 sur la période, ≈ 0,69–0,70 dès le jour 15 ; jours 4–7 : 0,640 vs 0,571. Agrément 0,529 → 0,704. Stress 0,541 → ≈ 0,67 |
| Méthode de personnalisation | Un décalage de logit par personne qui oublie (T ≈ 2 jours) ≈ meilleur ; pentes personnelles +0,003 ; questions « au moment incertain » pires que le hasard (0,660 vs 0,665) |
| Rythme de réponse 1 / 2 / 4 par jour | 0,639 / 0,666 / 0,686 |
| Arrêt des réponses | 0,693 → 0,639 (2 j) → 0,590 (4 j) → 0,554 (7 j) ; modèle commun 0,546 |
| LifeSnaps (Fitbit Sense, Europe, CC BY 4.0) | Signaux de nuit : −0,001 à −0,004 ; modèle EmoPhone figé : 0,471 (effet de l'heure inversé), termes FC seuls 0,530 |
| Questions en un geste (littérature) | 81,2 % de réponses (µEMA) vs 64,5 % (EMA classique) ; 67,6 % sur 6 mois sans paiement |

**Lecture honnête.** Le gain de B vient surtout de l'**habitude de la personne** et de son **état
récent**, pas de la montre (la montre ajoute +0,007 à l'énergie par-dessus les réponses, ≈ 0 à
l'agrément). La simulation est faite sur des étudiants EmoPhone, avec une référence « habitude »
calculée sur toutes leurs réponses (5–7/jour) : dans l'app, la référence viendra des seules
réponses aux questions, le gain arrivera donc probablement plus tard. D'où WP-B0 (§9).

---

## 3. Approches considérées

| | A. Modèle commun soigné | B. Harmony apprend de toi | C. Modèle personnel multi-signaux |
|---|---|---|---|
| Contenu | LR 17 features, valence secondaire, `e0` par rang | Questions en un geste + décalages personnels + bandit de file | B + coefficients personnels sur HRV, respiration, température, lumière, bruit ; modèles plus gros |
| Gain | +0,01 à +0,02 | ≈ +0,11 (énergie) et +0,17 (agrément), simulé | Aucun mesuré (signaux de nuit ≈ 0, pentes personnelles ≈ 0) ; 60–100 réponses/personne nécessaires |
| Coût | 2–4 jours, aucun écran | Écrans + notifications, ~5–11 jours | Hors de portée |

**Retenu : A + B.** A améliore le jour 1 et la première semaine sans rien demander à l'utilisateur ;
B est le seul levier à gain important. **C est écarté** ; à la place, on pourra plus tard journaliser
ces signaux en option (après le cours), avec 3 hypothèses LifeSnaps préenregistrées
(sommeil ↔ agrément ρ +0,096 ; respiration ↔ activation ρ −0,087 ; FC de repos ↔ activation ρ −0,049).

---

## 4. Architecture

```
iPhone (tout local)
 Apple Watch ─► HealthKit ─► FeatureBuilder (§6 v1, ou v2 à 17 features si adopté)
                                   │
                    MODÈLE 1 : commun « corps » (Core ML, figé)   ── repli « heure seule »
                    sorties : z_E (logit énergie)  ;  z_V (logit agrément : constante ou modèle valence)
                                   │
 Question en 1 geste ─► CheckIn (SwiftData) ─► étiquette « au-dessus de ton habitude »
 (Home, feuille, notification       (réponse > moyenne de tes réponses des 14 jours précédents, ≥ 5)
  écran verrouillé / Apple Watch)          │
                    MODÈLE 2 : couche personnelle — b_E(t), b_V(t) recalculés à la volée
                    e = σ(z_E + b_E)     v = σ(z_V + b_V)
                                   │
 Tap situation ─► MODÈLE 3 : bandit de file ─► stratégie s ─► constructeur de file §8 (e0, v0, s) ─► Spotify
                        ▲
                        └── récompense : Did it fit? / skips < 30 s / likes  (FeedbackEvent)
 Worker Cloudflare : inchangé (titres + artistes seulement).
```

### 4.1 Modèle 1 — commun « corps » (A)

- **Aujourd'hui** : `StateModel.mlmodel` + `model_params.json` v2 (13 features, bloc `time_only`),
  `StateEstimator.estimate` (mode corps si `z_hr_30` connu, sinon heure seule).
- **Candidat v2 : 17 features** = les 13 de v1 + `raw_hr_30`, `raw_hr_60`, `raw_log_steps_30`,
  `raw_log_steps_60`, ordre fixe ajouté **à la fin** de `FEATURES`.
  - `raw_hr_w` = `hr_w` de v1 (moyenne des FC rééchantillonnées, première FC de chaque tranche de
    5 min d'horloge, fenêtre `(t − w, t]`, valable dès 1 mesure, sinon inconnue) **avant** z-score.
  - `raw_log_steps_w` = `log_steps_w` de v1 (log(1 + pas de la fenêtre) ; 0 si montre portée sans pas ;
    inconnu si ni FC ni pas) **avant** z-score.
  - Mêmes règles d'inconnu et d'imputation par médiane d'entraînement que v1. Ces valeurs sont déjà
    calculées par `FeatureBuilder` avant le z-score : il suffit de les exposer.
- **Adoption seulement si le critère passe** (WP-A1, §9) ; sinon on garde v1 et seul le reste de A
  (rang, valence constante) s'applique.
- **Quand le mode « corps » s'applique** (choix de design) :
  - v1 (aujourd'hui) : corps si `z_hr_30` connu, sinon heure seule — ce qui exclut toute la première
    semaine (référence 7 jours pas prête).
  - v2 : corps si `raw_hr_30` connu (au moins une FC rééchantillonnée dans les 30 dernières minutes),
    sinon heure seule. Les z-scores inconnus sont imputés par la médiane, comme à l'entraînement.
    C'est précisément sur ces réponses (z inconnu mais FC présente, 21 % ; première semaine) que les
    valeurs brutes apportent leur gain : garder la règle v1 l'annulerait.
  - Le « corps » de l'A/B du pilote (TODO 4.4) et le champ `estimateMode` suivent cette règle.
- **Modèle « heure seule »** : inchangé. LifeSnaps montre qu'il est propre à la population EmoPhone
  (effet de l'heure inversé en Europe) ; la couche personnelle (B) corrige ce biais pour chaque
  utilisateur qui répond.

### 4.2 Modèle 1 bis — a priori d'agrément `z_V` (A)

- **Par défaut** : une constante, `z_V = logit(0,566)` (taux de base de « valence au-dessus de la
  moyenne personnelle » sur D-1 + D-2). Aucun changement du contrat §6.
- **Option** : une seconde LR sur les mêmes 17 features (étiquette `valence > moyenne de la
  personne`), exportée dans `model_params.json` (bloc `valence`, même schéma que `time_only`).
  Adoptée seulement si elle passe son critère (WP-A1). Raison du défaut constant : pour l'agrément,
  l'historique des réponses seul (0,700) égale presque le décalage posé sur un modèle valence (0,704).
- `z_V` n'est **jamais** utilisé seul pour la file : `v` n'existe que si l'utilisateur a répondu à la
  question d'agrément (§4.5).

### 4.3 `e0` sans réponse : rang personnel (A)

- `rank(t)` = part des prédictions de la même personne, sur la **grille de référence §6**
  (toutes les 30 min, 08:00–23:30, jours `[t − 14 j, t)`, points où la montre est portée), qui sont
  ≤ à la prédiction courante.
- **Score des points de grille** (choix de design, pour rester simple et rapide) : chaque point est
  scoré avec **la référence personnelle calculée à `t`** (une seule référence, celle de la prédiction
  courante), ses propres valeurs de fenêtre FC/pas, son heure, son jour de semaine et la nuit de son
  jour (`NightSummary` déjà lues pour `z_sleep_min`). On ne recalcule pas une référence propre à
  chaque point : l'app ne lit pas plus de données qu'aujourd'hui (15 jours + 1 h). WP-B0 simule
  exactement cette règle et produit ses fixtures.
- **Même règle de mode par point** que la prédiction courante (corps si FC dans les 30 min, sinon
  heure seule, §4.1).
- `e0 = rank(t)` s'il y a **au moins 32 points de grille** (≈ une journée de port) ; sinon
  `e0 = σ(z_E)` brut.
- **Pilote, bras « heure seule » (TODO 4.4)** : même transformation, appliquée aux prédictions
  heure seule (la prédiction courante et la grille sont scorées par le modèle heure seule). Les deux
  bras ne diffèrent alors que par la source d'information, pas par l'étalement de `e0`. Conséquence
  assumée : en bras heure seule, `e0` dit « ce moment de ta journée, d'après l'horloge seule ».
- Les deux usages de l'état s'appliquent : départ de la file (§8) et seuil « état < 0,4 » de la
  suggestion Low energy (§8, `SituationSuggester`) — avec des probabilités tassées, ce seuil ne se
  déclenche aujourd'hui presque jamais.
- Mesuré sur les moments de réponse EmoPhone, pas sur la grille de l'app : WP-B0 le revérifie.

### 4.4 Modèle 2 — couche personnelle (B)

Pour une dimension `d ∈ {E, V}`, à l'instant `t`, avec les check-ins `i` étiquetés et
utilisables des 14 derniers jours :

```
w_i(t) = exp( −(t − t_i) / T )                      oubli ; T = 2 jours
b_d(t) = argmin_b  Σ_i w_i(t) · ℓ( y_i , σ(z_i + b) )  +  b² / (2 τ_d²)
         ℓ(y, p) = −[ y·log p + (1 − y)·log(1 − p) ]    a priori N(0, τ²) ; τ_E = 1,0 ; τ_V = 1,5

Newton, 3 à 5 pas depuis b = 0 :
  g = Σ_i w_i (σ(z_i + b) − y_i) + b / τ²
  H = Σ_i w_i σ(z_i + b)(1 − σ(z_i + b)) + 1 / τ²
  b ← b − g / H

Probabilité personnelle :  p_d(t) = σ( z_d(t) + b_d(t) )
```

- **Étiquette** `y_i` (fixée au moment de la réponse et stockée) : 1 si la réponse dépasse la
  moyenne des réponses de l'utilisateur sur `[t_i − 14 j, t_i)`, **au moins 5** réponses ;
  sinon pas d'étiquette (réponse gardée, pas encore utilisée). C'est la règle `L_past` simulée.
- `z_i` = logit du modèle 1 **selon la règle de mode du §4.1** (corps si FC dans les 30 min, sinon
  heure seule), **au moment de la réponse**, stocké avec le check-in — **indépendamment du bras
  du jour** de l'A/B du pilote (le bras ne change que la source de `e0` pour la file).
  Une réponse donnée téléphone verrouillé (HealthKit illisible) reçoit son `z_i` au prochain
  déverrouillage, calculé pour l'instant de la réponse.
  Si le modèle 1 change (v1 → v2), on remet les décalages à 0 (ou on recalcule `z_i` si les
  features sont disponibles) : choix laissé au builder, à documenter.
- **Propriétés** : sans réponse, `b = 0` exactement → modèle commun (G1). Une réponse pèse moitié
  après ≈ 1,4 jour. Quand les réponses s'arrêtent, `b` revient vers 0 (variante `m1d_now`).
  Calcul à la volée, quelques dizaines de check-ins au plus : aucune tâche de fond nécessaire.
- **Utilisables pour l'apprentissage** : pas les réponses données pendant une file ou dans les
  60 min après sa fin (la musique influence la réponse) ; la réponse « avant la file » l'est.
- **Hyper-paramètres** `T`, `τ_E`, `τ_V`, le seuil de 5 et le passage au personnel (§4.5) viennent
  de la simulation ; `m1d_now` (oubli jusqu'à l'instant de prédiction) n'a été évalué que dans
  l'expérience d'arrêt → **WP-B0 doit le régler et le confirmer avant tout code Swift**.

### 4.5 État utilisé par la file

| Situation de l'utilisateur | `e0` | `v0` | Règle de positivité |
|---|---|---|---|
| Aucun check-in étiqueté récent (< 5 dans les 14 j) | rang (§4.3) | — | §8 actuelle (+0,2 si positivité < 0,5 en Stress / Low energy) |
| ≥ 5 check-ins énergie étiquetés dans les 14 j | `σ(z_E + b_E)` | — | §8 actuelle |
| + ≥ 5 check-ins agrément étiquetés | idem | `σ(z_V + b_V)` | Terme de distance en positivité de `v0` vers le but de la situation (Stress, Low energy : positif) à la place de la pénalité fixe |

- **Mode pilote** (décision D4, §11) : en mode **ombre**, la file utilise la ligne 1 du tableau
  quel que soit le nombre de réponses ; `p_perso` est calculé et journalisé, pas utilisé.
  En mode **actif**, le tableau s'applique. Une seule constante choisit le mode.
- Les règles §8 restent vraies (wind-down ne finit jamais plus énergique qu'il ne commence, etc.).
- La forme exacte du terme de positivité est un réglage produit (non mesurable en AUROC), à fixer
  avec le customer.

### 4.6 Modèle 3 — bandit de file (B)

- **Bras** : 3 stratégies par situation (décision D7). Proposition par défaut, définie pour être
  implémentable telle quelle (`e0`, `g`, `n`, `m` comme en §8) :
  - **S1 « progressif »** = §8 actuel : `n = 5` si |e0 − g| > 0,3, sinon 3 ; `m` cibles à `e0`
    (2 si n = 5, sinon 1), puis cibles réparties régulièrement de `e0` à `g`.
  - **S2 « demi-pas »** : même `n`, `m = 1` ; première cible à `e0`, puis cibles réparties
    régulièrement de `(e0 + g) / 2` à `g` (on rejoint le but plus vite, sans l'ignorer).
  - **S3 « correspondance longue »** : même `n` ; `m = n − 2` cibles à `e0`, puis deux cibles
    `(e0 + g) / 2` et `g` (on reste plus longtemps avec l'état avant de bouger).
  - Les trois partent de `e0` (aucune n'ignore l'état, pour ne pas diluer l'A/B corps / heure seule)
    et respectent les règles §8 (wind-down ne finit jamais plus énergique qu'il ne commence :
    toutes les cibles sont monotones de `e0` vers `g`).
- **Récompense r ∈ [0, 1]** par file, calculée depuis `FeedbackEvent` :
  `fitYes` = 1, `fitNo` = 0 ; sans réponse « Did it fit? » : 1 − part des morceaux passés < 30 s ;
  +0,2 par like, plafonné à 1. Mise à jour Beta : α += r, β += 1 − r, par (situation, stratégie).
- **Choix** : Thompson sampling, a priori Beta(1, 1), mélangé avec un tirage uniforme pour que
  chaque stratégie garde une probabilité ≥ 0,15. La **probabilité de la stratégie choisie est
  journalisée** dans `QueueRecord` (estimée par tirages Monte-Carlo si besoin).
- **État** : recalculé à la volée depuis l'historique `QueueRecord` + `FeedbackEvent` (pas de table
  dédiée ; la suppression des données le remet à zéro).
- **Pendant le pilote : pas de bandit** (choix de design). Toutes les files utilisent S1, journalisée
  (`strategy = S1`, probabilité 1). Raisons : ne pas ajouter de variation dans l'A/B corps / heure
  seule (4.4, 4.7), et ne pas mettre S2/S3 sur le chemin critique d'avant pilote. Le bandit
  commence après le pilote ; les récompenses S1 du pilote servent de point de comparaison.
- **Jamais** : entraîner le modèle d'état sur « Did it fit? ». Avec 14–40 files par personne en
  2 semaines, parler d'« adaptation », pas d'« apprentissage ».
- **Compatibilité pilote** : le tirage quotidien « corps » vs « heure seule » (TODO 4.4,
  `QueueRecord.kind`) reste indépendant du bras du bandit.

---

## 5. Système de questions

### 5.1 Libellés (l'app est en anglais ; textes finaux relus par le customer, TODO 3.20)

| Usage | Anglais (app) | Échelle stockée |
|---|---|---|
| Énergie, notification | « Quick check: energy right now? » — actions dans cet ordre : **Not now** · Low · Medium · High | Low/Medium/High = −2 / 0 / +2 (à vérifier en WP-B0) |
| Énergie, dans l'app | « Energy right now », de *Low* à *High*, 7 crans, marqueur « Last » sur la réponse précédente | −3..+3 |
| Agrément, dans l'app seulement, facultatif | « How does right now feel? », de *Unpleasant* à *Pleasant*, 7 crans | −3..+3 |

- Demander le **niveau absolu**, jamais « par rapport à d'habitude » : l'app calcule elle-même
  « au-dessus de ton habitude » (§4.4). Afficher la réponse précédente comme repère.
- Interdits : ancres EmoPhone (« calm », « excited »), « stressed », mots de l'app Santé
  (State of Mind) ; toute émotion nommée. Smileys : décision D6.
- Pas de question de stress (le stress recopie surtout l'agrément inversé).
- « Not now » en **premier** : le Double Tap de l'Apple Watch déclenche la première action non
  destructive.

### 5.2 Canaux

1. **Avant la file, sur Home** : une ligne facultative « Energy right now? » qu'on peut ignorer ;
   ne doit jamais ajouter de tap obligatoire (NFR5 ≤ 2 taps). Réponse la plus propre (avant la musique).
2. **Deux notifications locales par jour**, à heure aléatoire dans deux plages choisies par
   l'utilisateur (défaut 10–13 h et 15–19 h). Réponse d'un geste sur l'écran verrouillé ; les
   notifications locales sont relayées sur l'Apple Watch **sans app watchOS**, l'action s'exécute
   sur l'iPhone. À tester sur un vrai appareil (watchOS récent).
3. **Après la file** : « Did it fit? » existant (`V2-Feedback`) = récompense du bandit, jamais une
   étiquette d'état.

### 5.3 Règles de charge

- Au plus 2 notifications par jour, au plus 4 sollicitations par jour au total ; ≥ 2 h entre deux
  notifications ; aucune pendant la plage de sommeil ; aucune dans les 60 min après une file.
- Moments **au hasard** dans les plages (le choix « au moment incertain » fait moins bien).
- Pas de rappel, pas de série, pas de badge insistant. Texte de notification neutre, sans valeur de
  santé (App Store 4.5.4) ; notifications facultatives : l'app fonctionne sans.
- Interrupteur « Questions » dans Settings ; désactivé → aucune question, couche personnelle gelée
  puis revenue à 0 par l'oubli.
- **Inconnu ≠ zéro** : notification ignorée ou « Not now » = aucune information, jamais « Low ».
- Volume attendu sur 2 semaines sans paiement : ≈ 30–60 réponses par personne.

### 5.4 Design d'abord (règle UI de CLAUDE.md)

Aucun de ces éléments n'existe dans `docs/design/` (18 écrans). À dessiner dans le canvas claude.ai,
recopier dans `docs/design/` et ajouter au README **avant** toute vue :
ligne énergie sur `V2-Accueil` ; feuille de check-in (énergie + agrément facultatif) ; étape
d'onboarding qui explique les questions et demande les notifications ; texte et actions de la
notification ; `V2-Reglages` (« Questions », plages, « Reset what Harmony learned ») ;
`V2-MesDonnees` (check-ins) ; `V2-APropos` (paragraphe sur l'apprentissage local) ; éventuellement
un indicateur « Harmony is learning your usual — N answers this week ».

### 5.5 Ce que l'utilisateur voit / ne voit jamais

- **Voit** : la question, sa réponse précédente, un compteur de réponses, une raison de file en
  phrases fixes qui parle d'énergie (« Your recent answers: more energy than your usual, starting
  livelier »), les réglages et la réinitialisation.
- **Ne voit jamais** : probabilités, AUROC, « précision », émotion nommée, niveau de stress,
  promesse médicale, ni l'estimation du modèle **avant** de répondre (effet d'attente).

---

## 6. Données (SwiftData, local)

**Nouveau `@Model CheckIn`** (noms indicatifs) :

| Champ | Type | Rôle |
|---|---|---|
| `id` | UUID | |
| `answeredAt` | Date | instant de la réponse |
| `channel` | enum `home`, `sheet`, `notification` | |
| `promptedAt` | Date? | heure d'envoi de la notification |
| `energy` | Int (−3..+3) | réponse énergie |
| `pleasantness` | Int? (−3..+3) | réponse agrément, facultative |
| `zEnergy`, `zPleasantness` | Double | logits du modèle 1 à l'instant de la réponse |
| `estimateMode` | enum `body`, `timeOnly` | mode actif |
| `labelEnergy`, `labelPleasantness` | Bool? | étiquette `L_past` fixée à la réponse (nil si < 5 réponses passées) |
| `usableForLearning` | Bool | false pendant une file ou < 60 min après |
| `pCommonBefore`, `pPersonalBefore` | Double? | journal prédictif : `σ(z)` et `σ(z + b)` calculés **avant** d'ajouter cette réponse (évaluation chronologique du pilote) |
| `dayOfUse` | Int | jour d'utilisation depuis l'installation |

**Nouveau `@Model PromptLog`** (une ligne par sollicitation envoyée, pour le taux de réponse) :
`id`, `scheduledAt`, `deliveredAt?`, `outcome` (`answered`, `notNow`, `ignored`) — `ignored` quand
la notification expire ou est remplacée sans réponse —, `checkInId?`. Entre dans l'export, la
suppression totale et le texte de consentement (D5).

**`QueueRecord` complété** : `strategy` (String), `strategyProbability` (Double),
`e0Source` (`rank` / `raw` / `personal`), `pCommon` (Double), `pPersonal` (Double?), `v0` (Double?).

**Écran verrouillé** : une réponse donnée téléphone verrouillé ne doit pas dépendre d'un store en
protection complète ; vérifier la classe de protection du store SwiftData ou passer par une petite
file d'attente fusionnée au lancement (choix du builder, à tester sur appareil).

**Export / suppression (N4, FR13, TODO 3.19)** : les check-ins entrent dans l'export JSON et dans la
suppression totale. « Reset what Harmony learned » supprime les check-ins et note une date de
réinitialisation au-delà de laquelle l'historique du bandit est seul pris en compte.
Durée de conservation des check-ins à afficher dans My Data (proposition : 30 jours ; au-delà de
14 jours une réponse ne pèse plus rien).

**Rien de nouveau ne quitte le téléphone.** L'analyse du pilote n'utilise que des agrégats ou des
paires (probabilité, étiquette, jour d'utilisation) exportées **avec consentement écrit** (D5).

---

## 7. Python (`ml/`)

- **WP-0 — groupes déterministes** : `ml/train.py` `folds` départage les égalités du nombre de
  réponses par un tri non stable (résultats différents entre machines, mêmes moyennes). Assigner les
  groupes de façon déterministe (ex. tri stable sur `(n_réponses, participant)` ou affectation
  explicite enregistrée), relancer la CV v1, noter les nouveaux écarts-types dans PROJECT.md §6.5.
  Prérequis de toute comparaison.
- **WP-A1 — features v2 et valence** (voir §9 pour le critère) : ajouter les 4 valeurs brutes dans
  `features.py` / `build_features.py` (tables locales `data/features/v2_D*.csv`, jamais sur Git),
  CV D-1 + D-2 (énergie, valence), test unique D-3, puis `train.py --final` sur D-1 + D-2 + D-3,
  `export.py` (`model_params.json` v3 : 17 features, bloc `time_only`, bloc `valence` si adopté),
  Core ML, fixtures golden (`make_fixtures.py`, avec les 4 nouvelles valeurs et `valence_probability`),
  mise à jour PROJECT.md §3, §6.
- **WP-B0 — simulation de la règle exacte de l'app** (avant tout code Swift de B), sur D-1 + D-2
  seulement, à partir de `docs/research/.../scripts/perso/sim.py` :
  réponses ramenées à la question réelle (7 crans ; et 3 niveaux −2/0/+2 pour les notifications),
  « habitude » calculée sur les seules réponses simulées (≥ 5), étiquettes fixées à la réponse,
  `m1d_now`, exclusion « pendant ou < 60 min après une file » non simulable (le noter), a priori
  d'agrément constant vs modèle valence, rythme 1 / 2 / 4 par jour, et passage rang → personnel.
  Sorties : `T`, `τ_E`, `τ_V`, seuil, courbe attendue ; **fixtures golden** de la couche
  personnelle (séquences synthétiques de check-ins + `z` → `b` et `p` attendus, tolérance 1e-6) et
  du rang (§4.3).
- **WP-P — analyse du pilote** (après) : script d'agrégats : taux de réponse, réponses par personne,
  AUROC chronologique `pCommonBefore` vs `pPersonalBefore` par tranche de jours d'utilisation (avec
  intervalles par bootstrap sur les personnes), récompense moyenne par stratégie. Aucun chiffre
  individuel publié.

---

## 8. Swift (`app/Harmony/`)

Code existant concerné : `Core/State/FeatureBuilder.swift`, `StateEstimator.swift`,
`CurrentState.swift`, `ModelParams.swift`, `Core/Models/QueueRecord.swift`, `FeedbackEvent.swift`
(`skip`, `like`, `finish`, `fitYes`, `fitNo`), `HarmonyStore.swift`, `Features/Home`,
`Features/Settings`, `Features/Debug/StateDebugSection.swift`. Le constructeur de file (TODO 3.2–3.3),
l'`Explainer` (3.7), le `SituationSuggester` (3.8), les feedbacks (3.14–3.15) et les écrans
(3.16–3.19) sont des tâches Phase 3 : B s'y branche, il ne les remplace pas.

Paquets dans l'ordre (dépendances entre parenthèses) :

| WP | Contenu | Vérification |
|---|---|---|
| S1 | `CheckIn` + migration SwiftData + export/suppression | test : après suppression totale, `CheckIn` vide ; export contient les check-ins |
| S2 | `PersonalLayer` en fonctions pures : étiquette `L_past`, Newton, `m1d_now`, utilisabilité (WP-B0) | tests golden WP-B0 à 1e-6 ; `b = 0` sans réponse ; « Not now » n'ajoute rien |
| S3 | Rang `e0` sur la grille §4.3 (WP-B0) | tests golden du rang ; file affichée < 2 s (NFR3) |
| S4 | Ligne énergie sur Home + feuille de check-in (design §5.4 fait) | ≤ 2 taps jusqu'à la musique (NFR5) ; test de mots interdits (3.7) étendu aux nouveaux textes |
| S5 | Notifications : catégorie à actions (« Not now » en premier), planification selon §5.3, réponse traitée en arrière-plan, écran verrouillé | testé sur iPhone verrouillé et sur Apple Watch ; aucune notification dans les 60 min après une file |
| S6 | Branchement de `e0` / `v0` dans le constructeur de file + raison de file (3.2, 3.3, 3.7) | tests : sans réponse, file identique à la règle A ; wind-down jamais plus énergique |
| S7a | Journal de file (`strategy = S1`, `strategyProbability = 1`, `e0Source`, `pCommon`, `pPersonal`, `v0`) et constante de mode ombre/actif (S6) | champs remplis pour chaque file |
| S7b | Bandit S1/S2/S3 (après le pilote ; S6, 3.14, 3.15) | tests : probabilité ≥ 0,15 par bras ; cibles monotones pour les 3 stratégies |
| S8 | Settings (« Questions », plages, reset), My Data, About, section Debug (b_E, b_V, p commune vs perso) | reset → `b = 0` ; textes relus |
| S9 | Modèle v2 (17 features, valence) si WP-A1 l'adopte (WP-A1) | fixtures golden v3 à 1e-6 |

**Règles de gel** (reprises de la proposition) : le modèle commun est figé pendant tout le pilote ;
v2 (S9) n'entre dans le build du pilote que s'il est prêt, fixtures golden comprises, **avant le
5 déc.** ; sinon le pilote tourne avec v1.

**Périmètre du build du pilote** : voir §15 (décision de périmètre).

---

## 9. Validation et critères de succès

- **Critères écrits avant les résultats**, comme pour UC Irvine (§3 de PROJECT.md). Proposition à
  figer en réunion avant WP-A1 :
  - **Chaque modèle est noté selon la règle de l'app qu'il aurait** (choix de design) : v1 avec sa
    règle (corps si `z_hr_30` connu, sinon heure seule), v2 avec la sienne (corps si `raw_hr_30`
    connu, sinon heure seule), sur les mêmes réponses. Le score « toutes réponses, modèle complet »
    est aussi noté, pour comparaison avec les chiffres publiés (0,563).
  - v2 (17 features) remplace v1 si, en CV D-1 + D-2 (groupes déterministes), l'AUROC énergie n'est
    pas plus basse que v1 de plus de 0,002 **et** si, au test unique D-3, l'AUROC énergie n'est pas
    plus basse que v1 et reste ≥ heure seule + 0,02.
  - Le modèle valence remplace la constante si son AUROC dépasse l'heure seule (valence) d'au moins
    +0,01 en CV et sur D-3.
- **D-3 une seule fois** par changement, code figé avant, résultat noté même s'il déçoit.
- **Couche personnelle** : fixtures golden Python ↔ Swift (1e-6). Attendu (pas un critère) : courbe
  WP-B0 au-dessus du modèle commun à partir de la 1re–2e semaine.
- **Pilote (≤ 5 personnes, ~2 semaines)** : c'est un test de faisabilité, pas une preuve
  statistique. Mesures : taux de réponse, réponses/personne, AUROC chronologique commune vs
  personnelle avec intervalles larges, récompense par stratégie, NFR3/NFR5 tenus, aucun mot interdit.
- **Externe** (facultatif, après le cours) : LifeSnaps comme second test, partie FC et partie heure
  seule notées séparément.

---

## 10. Tâches proposées pour `docs/TODO.md` (ajoutées le 23 nov. 2026 : Phase 6)

> Nouvelle phase, à insérer avant « En continu ». Format identique au reste de TODO.md.
> **TODO.md fait foi** : en l'ajoutant, 6.7 a reçu `PromptLog` et 6.12 (réduit) est entré dans le
> build du pilote, pour suivre le §15.
> Build du pilote (§15, « collecte seule ») : 6.1, 6.5, 6.6 (réduit), 6.7, 6.8, 6.10, 6.13 (réduit),
> 6.14 ; côté A : 6.2–6.4 si prêts avant le 5 déc., 6.11 (rang seulement) si la file existe.

```
## Phase 6 — Modèle d'état v2 : A + B (design docs/superpowers/specs/2026-11-23-modele-etat-v2-design.md)

### 6.ML
- [ ] **6.1** Groupes de validation déterministes dans `ml/train.py`. — ✔ deux machines donnent les mêmes écarts-types ; PROJECT.md §6.5 mis à jour.
- [ ] **6.2** Critères d'adoption v2 et valence écrits avant résultats. — ✔ notés dans PROJECT.md §3.
- [ ] **6.3** Features v2 (17) + valence : CV D-1 + D-2, test unique D-3, décision selon 6.2. — ✔ chiffres dans PROJECT.md §6.5.
- [ ] **6.4** Si adopté : entraînement final, export v3, Core ML, fixtures golden. — ✔ tests Python et Swift passent.
- [ ] **6.5** Simulation de la règle exacte de l'app (WP-B0) + fixtures de la couche personnelle et du rang. — ✔ hyper-paramètres et courbe notés dans PROJECT.md ; fixtures dans `ml/fixtures/`.

### 6.DESIGN
- [ ] **6.6** Écrans et notification de check-in dessinés dans le canvas, copiés dans `docs/design/`. — ✔ README du design à jour.

### 6.APP
- [ ] **6.7** `CheckIn` + export/suppression (S1). — ✔ tables vides après suppression.
- [ ] **6.8** Couche personnelle (S2). — ✔ fixtures 6.5 à 1e-6.
- [ ] **6.9** Ligne énergie + feuille de check-in (S4). — ✔ NFR5 tenu.
- [ ] **6.10** Notifications à actions (S5). — ✔ réponse depuis l'écran verrouillé et la montre.
- [ ] **6.11** Rang `e0` (S3) et branchement dans la file (S6). — ✔ tests de file.
- [ ] **6.12** Journal de file + modes ombre/actif (S7a). — ✔ champs remplis pour chaque file.
- [ ] **6.12b** Bandit S1/S2/S3, après le pilote (S7b). — ✔ probabilités ≥ 0,15 journalisées.
- [ ] **6.13** Réglages, My Data, About, Debug (S8). — ✔ reset → b = 0.

### 6.PILOTE
- [ ] **6.14** Protocole et consentement incluant les check-ins (complète 4.1). — ✔ document dans `docs/`.
- [ ] **6.15** Analyse WP-P. — ✔ tableau d'agrégats dans le rapport.
```

---

## 11. Décisions d'équipe à prendre avant de coder (prises telles que proposées le 23 nov. 2026, PROJECT.md §3)

| # | Décision (PROJECT.md §3 ou pilote) | Proposition |
|---|---|---|
| D1 | « Pas d'entraînement sur chaque utilisateur » | Reformuler : « pas de modèle par utilisateur appris de zéro ; un ajustement personnel (2 nombres) appris sur l'iPhone à partir des réponses ; jour 1 = modèle commun » |
| D2 | « Sortie = plus/moins activé que d'habitude, jamais une émotion » | Ajouter un agrément **interne**, jamais affiché comme émotion |
| D3 | « Modèle final : 13 features v1 » | 17 features si le critère 6.2 passe |
| D4 | Mode de la couche personnelle pendant le pilote | **Ombre** (calculée et journalisée, ne pilote pas la file ; toutes les files en S1) pour garder propre l'A/B « corps vs heure seule » (4.4) et mesurer une vraie courbe d'apprentissage ; passage en **actif** pour la démo finale. Alternative : actif dès le pilote (démo plus parlante, A/B mélangé) |
| D5 | Consentement / éthique du pilote avec check-ins (App Store 5.1.3, cours) | Consentement écrit incluant les questions ; export limité aux agrégats et paires (probabilité, étiquette, jour) |
| D6 | Smileys dans la question | Non par défaut (zone grise « émotion nommée ») |
| D7 | 3 stratégies de file par situation | S1/S2/S3 de §4.6, à valider avec le customer |
| D8 | « Évaluation par personnes tenues à part » | Garder pour le modèle commun ; ajouter l'évaluation **chronologique** (prédire chaque réponse avec le passé seulement) pour la couche personnelle |
| D9 | N1 « zéro effort » | Questions facultatives, désactivables, jamais bloquantes |

---

## 12. Laissé au builder

Noms et découpage des types Swift ; calcul efficace des prédictions de grille (cache en mémoire,
NFR3) ; mécanique de planification des notifications ; estimation de la probabilité du bras
(analytique ou Monte-Carlo) ; gestion de la protection des données écran verrouillé ; organisation
des tests ; recalcul ou remise à 0 des décalages lors d'un changement de modèle (à documenter) ;
détails visuels (toujours d'après le canvas).

---

## 13. Risques et limites

- **Transfert de la simulation** : étudiants EmoPhone, référence « habitude » plus riche que dans
  l'app ; gain probablement plus tardif (WP-B0 le chiffrera).
- **Taux de réponse** sans paiement ; fatigue au fil des semaines ; tension avec N1.
- **Boucle musique → réponse** : réponses pendant ou juste après une file exclues de l'apprentissage.
- **Biais de moment** : réponses données surtout quand l'app est ouverte → les notifications au
  hasard le réduisent.
- **Charge de travail** face à M3 (6 déc.) : la version minimale en mode ombre compte ~5–6 jours ;
  si elle ne tient pas, le pilote garde le modèle actuel et B passe après le cours.
- **`sleep_unknown`** a l'un des plus gros coefficients (+0,12) : il reflète l'habitude EmoPhone de ne
  pas porter la montre la nuit, pas un signal du corps ; ne pas le présenter comme tel.
- **Données proches de la santé** : les check-ins sont traités comme des données de santé (local,
  export et suppression, aucune sortie sans consentement).

---

## 14. Pour la présentation

- **Pitch** : « Harmony part d'un modèle appris sur 53 000 moments de 282 étudiants. Chaque réponse
  en un geste l'ajuste à toi, sur ton iPhone, sans que rien ne quitte ton téléphone. La file, elle,
  s'adapte à tes skips et à tes likes. »
- **Figure** : AUROC en fonction du jour d'utilisation, modèle commun vs couche personnelle (simulation
  EmoPhone : 0,571 vs 0,640 aux jours 4–7, ≈ 0,69 dès le jour 15) ; puis la même courbe mesurée au
  pilote (journal `pCommonBefore` / `pPersonalBefore`).
- **Schéma** : « 3 modèles » (commun, personnel, file), < 100 paramètres, tous sur le téléphone.
- **Honnêteté** : préciser « simulé sur EmoPhone » ; le gain vient surtout des réponses de
  l'utilisateur, la montre donne l'estimation du premier jour.

---

## 15. Périmètre du build du pilote (décision de Clément, 23 nov. 2026 : « collecte seule »)

**But** : que le pilote du 7 déc. collecte des réponses et mesure la couche personnelle **en ombre**,
sans nouvel écran sur Home et sans toucher la file. Charge estimée ~3–4 jours, après WP-B0.

| Dans le build du pilote | Hors du build du pilote (après le cours) |
|---|---|
| WP-0 (groupes déterministes) et WP-B0 (simulation de la règle exacte + fixtures) | Ligne énergie sur Home, feuille de check-in, question d'agrément (S4) |
| S1 : `CheckIn` + `PromptLog` + export/suppression | Branchement de `e`/`v` dans la file (S6, mode actif) |
| S2 : couche personnelle en fonctions pures, calculée **en ombre** (`pCommonBefore`, `pPersonalBefore` à chaque réponse étiquetée) | Bandit S1/S2/S3 (S7b) |
| S5 : 2 notifications/jour à boutons (« Not now », Low, Medium, High), écran verrouillé et Apple Watch | État 2-D et terme de positivité |
| S8 réduit : étape d'onboarding des notifications, réglage « Questions » (on/off, plages), « Reset what Harmony learned » | Raison de file fondée sur les réponses |
| S7a réduit : `pCommon` / `pPersonal` journalisés dans `QueueRecord` si le constructeur de file existe | |

- **Énergie seulement** pendant le pilote (les notifications n'ont qu'une question) : `b_V` et `v`
  ne sont pas calculés.
- **Design d'abord** (6.6 réduit) : texte et actions de la notification, étape d'onboarding,
  réglages « Questions » et « Reset », ligne « check-ins » dans My Data.
- **A** (indépendant de B) : le rang `e0` (S3) entre dans le pilote si le constructeur de file
  (3.2–3.3) est prêt ; v2 (S9) seulement s'il est prêt avant le 5 déc. (§8, règles de gel).
- **Analyse (WP-P)** : l'iPhone calcule les paires (`pCommonBefore`, `pPersonalBefore`,
  `labelEnergy`, `dayOfUse`) et les comptes de `PromptLog` ; seules ces paires et ces comptes sont
  exportés, **avec consentement écrit** (D5), comme l'export des feedbacks prévu en 4.5. Ni réponse
  brute horodatée, ni `z`, ni donnée HealthKit ne quittent le téléphone.
- **Ce que le rapport final pourra montrer** : la courbe « jour d'utilisation → AUROC »,
  commune vs personnelle, **mesurée sur de vrais utilisateurs Apple Watch** (intervalles larges avec
  ≤ 5 personnes), à côté de la courbe simulée sur EmoPhone.

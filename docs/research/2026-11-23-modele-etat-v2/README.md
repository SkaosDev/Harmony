# Archive de recherche — modèle d'état v2 (23 nov. 2026)

Preuves derrière le design `docs/superpowers/specs/2026-11-23-modele-etat-v2-design.md`.
Deux tours de recherche menés avec Claude Code le 23 nov. 2026 ; rien n'a été implémenté dans l'app.

**Aucune donnée ici** : seulement des rapports, des notes, des scripts et des résultats agrégés
(moyennes sur 5 groupes de participants, courbes moyennées). Les tables par réponse construites
pendant les expériences et le téléchargement LifeSnaps (1,3 Go) sont restés hors du dépôt.

## Contenu

| Chemin | Ce que c'est |
|---|---|
| `rapport-1-exploiter-emophone.md` | Tour 1 : EmoPhone est-il pleinement exploité ? UC Irvine ? autres datasets ? |
| `rapport-2-proposition-v2.md` | Tour 2 : expériences et proposition A / B / C (l'équipe a retenu A + B) |
| `notes/tour1/` | Notes du tour 1 : audit EmoPhone/UCI, datasets grand public, datasets labo, signaux Apple Watch, benchmarks |
| `notes/tour2/` | Notes du tour 2 : cibles et modèles, nouvelles features, simulation de personnalisation, système de questions, LifeSnaps |
| `scripts/` | Scripts des expériences (code seulement) |
| `resultats/` | Sorties agrégées des scripts |

## Relancer un script

Les scripts ont été écrits dans un dossier temporaire
(`/private/tmp/claude-501/.../scratchpad/`) : **adapter les chemins** en tête de chaque script
(données dans `data/emophone_data/`, tables dans `data/features/`, sorties hors du dépôt).

- Python : `.venv/bin/python` (3.12, scikit-learn 1.5.2), avec `PYTHONDONTWRITEBYTECODE=1`.
- Les scripts importent `ml/` en lecture (`sys.path`).
- **Jamais D-3** dans ces expériences : la vague est réservée à un test unique de confirmation.
- Les sorties ne doivent contenir que des agrégats ; une table par réponse ne va jamais dans `docs/`.
- Script clé pour la suite : `scripts/perso/sim.py` (simulation de la couche personnelle,
  méthodes 0–5, `m1d`, `m1d_now` via `lag.py`) ; à adapter à la règle exacte de l'app (design §9, WP-B0).
- LifeSnaps : `scripts/lifesnaps/download.sh` télécharge le Zenodo 7229547 (CC BY 4.0) ; le décodage
  BSON utilise `pymongo` ; ne rien exécuter depuis le dossier téléchargé.

## Points d'attention relevés pendant la recherche

- Les groupes de `ml/train.py` dépendent de la machine (égalités du nombre de réponses départagées
  par un tri non stable) : mêmes moyennes, écarts-types différents. À corriger avant toute nouvelle
  comparaison (design, WP-0).
- Corrections de documentation à reporter dans PROJECT.md et `main.tex` : voir la dernière section
  de `rapport-1-exploiter-emophone.md`.

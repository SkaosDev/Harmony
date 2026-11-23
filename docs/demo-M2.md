# Démo M2 — fiche de déroulé (TODO 2.36)

> Jalon M2, 29 nov. 2026. Public : le *customer* (Cyprien). Durée visée : 10 min + questions.
> À montrer (TODO 2.36) : **scores des morceaux**, **état estimé à l'écran Debug**, **résultats du
> modèle**. Les écrans définitifs viennent en phase 3 : tout passe par l'écran Debug.
> Chiffres tirés de `docs/PROJECT.md` (§5.2, §6.5, §7) ; ne pas en citer d'autres.

## Avant (la veille)

- [ ] Build Debug de la branche à jour installé sur l'iPhone 16, `Config.xcconfig` rempli.
- [ ] Apple Watch portée depuis ≥ 7 jours (référence personnelle prête), et au poignet le jour J.
- [ ] Spotify connecté (Settings › Debug › Spotify), bibliothèque importée et notée
      (Song scores › Score songs ; les fois suivantes, seuls les nouveaux titres partent).
- [ ] Réseau OK (Wi-Fi ou partage de connexion) ; iPhone chargé ; recopie d'écran testée.
- [ ] Repli prêt : **Demo mode** (Settings › Debug) marche sans réseau, sans montre et sans Spotify.

## Déroulé

1. **Rappel (1 min)** — Harmony joue une courte file tirée de *ta* bibliothèque Spotify selon le
   moment (réveil, stress, coup de mou, détente), d'après la FC, les pas et le sommeil de l'Apple
   Watch. M2 = les deux briques qui décident : le score de chaque morceau et l'état de la personne.

2. **Scores des morceaux (3 min)** — Settings › Debug › *Song scores*.
   - Chaque morceau reçoit une énergie et une positivité entre 0 et 1.
   - D'abord **MuSe** (base publique, tags Last.fm, rang centile : 0,2 = plus calme que 80 % des
     morceaux), cherchée par ID Spotify puis par titre + premier artiste.
   - Sinon le **LLM** (Claude Haiku 5.5) via notre Worker Cloudflare : seuls titres et artistes
     quittent le téléphone, la clé API n'est pas dans l'app.
   - Sinon 0,5 / 0,5 (neutre). Chaque morceau n'est noté qu'une fois.
   - Montrer : la répartition MuSe / LLM / neutre et les 10 derniers titres avec E, P et l'origine.
   - Chiffres mesurés (bibliothèque de Clément, 2 045 titres) : **11,4 %** trouvés dans MuSe,
     **88,6 %** notés par le LLM, premier scoring en **158 s**, import en 14,3 s.

3. **État estimé (3 min)** — Settings › Debug › *State* › *Compute state*.
   - Sortie : un nombre 0…1 = « plus activé que d'habitude » (comparé à sa propre moyenne sur
     14 jours). **Jamais un nom d'émotion, aucune promesse médicale.**
   - Montrer : le mode (*Body* avec les données de la montre, *Time only* sans référence ou sans FC
     récente), les 13 features, le temps de calcul (~0,15 s sur iPhone).
   - Tout est calculé sur le téléphone ; les données santé n'en sortent pas.

4. **Résultats du modèle (2 min)** — régression logistique entraînée sur EmoPhone (étudiants
   coréens, étiquettes « du moment »), évaluée par participants entiers tenus à part.

   | Entrées | AUROC, validation croisée D-1 + D-2 | AUROC, D-3 tenue à part |
   |---|---:|---:|
   | Heure seule (référence) | 0,535 | 0,534 |
   | Heure + FC | 0,554 | 0,570 |
   | **Heure + FC + pas + sommeil (modèle de l'app)** | **0,563** | **0,576** |

   Le modèle bat l'heure seule sur les deux évaluations, mais le signal reste **faible** (0,5 = au
   hasard). UC Irvine testé aussi : chaque modèle ne gagne que sur ses propres données → modèle
   EmoPhone gardé. Le pilote (phase 4) comparera files « corps » et « heure seule ».

5. **Limites dites franchement (1 min)**
   - Scores LLM : la règle fixée avant (Spearman ≥ 0,4) n'est pas atteinte (0,26–0,34 sur trois
     essais) ; on les utilise par choix d'équipe, car la référence MuSe est elle-même peu taguée.
     Les sauts et le « ça collait ? » serviront à les juger en usage.
   - MuSe couvre peu une bibliothèque actuelle (11 %) : la plupart des scores viennent du LLM.

## Questions à poser au customer

- [ ] Les scores des morceaux affichés paraissent-ils plausibles sur des titres qu'il connaît ?
- [ ] L'état « plus / moins activé que d'habitude » est-il compréhensible tel quel ?
- [ ] 158 s pour noter une grande bibliothèque à la première ouverture : acceptable si ça tourne
      en arrière-plan pendant l'onboarding ?
- [ ] Priorités pour M3 (file, lecture, retours) : quelque chose à ajouter ou retirer ?

## Après la démo

Ouvrir une issue GitHub « Retours démo M2 » avec les réponses et remarques (une case par point à
traiter), puis cocher **2.36** dans `docs/TODO.md` avec le lien de l'issue.

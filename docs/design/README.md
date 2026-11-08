# Design des écrans

**Source de vérité :** le canvas claude.ai « Harmony — brand identity + screens »
https://claude.ai/code/artifact/0daa5d2a-f709-49a4-b443-88a879845319 (privé, compte de Clément).

Ce dossier en est une **copie** (version `1794122035-ef17`, copiée le 8 nov. 2026) pour que toute
l'équipe, et son Claude Code, puisse lire le design sans accès au canvas.
L'app doit reproduire ces écrans **à l'identique** : couleurs, police, tailles, espacements,
rayons, textes, icônes.

## Lire un écran

- Un fichier `.dc.html` = un écran iPhone de 390 × 844 pt. Tout est en styles en ligne : les
  valeurs exactes (px → pt, 1 pour 1) se lisent directement dans le fichier. Toujours partir du
  fichier, jamais de mémoire ni du résumé ci-dessous.
- Ces fichiers ont besoin du moteur du canvas (`support.js`, absent ici) pour s'afficher
  correctement : pour **voir** un écran, ouvrir le canvas ; pour **coder**, lire le fichier.
- Les liens `<a href="V2-….dc.html">` donnent la navigation entre écrans.
- `canvas.json` : titres et position des écrans dans le canvas.

## Écrans

| Fichier | Titre | Tâche TODO |
|---|---|---|
| `V2-Main.dc.html` | 1.1 Launch | 3.16 |
| `V2-Onb1-Bienvenue.dc.html` | 2.1 Welcome | 3.16 |
| `V2-Onb2-Comment.dc.html` | 2.2 How it works | 3.16 |
| `V2-Onb3-Spotify.dc.html` | 2.3 Connect Spotify | 3.16 |
| `V2-Onb4-Sante.dc.html` | 2.4 Health data | 3.16 |
| `V2-Onb5-Import.dc.html` | 2.5 Library import | 3.16 |
| `V2-Accueil.dc.html` | 3.1 Home | 1.6 (barre d'onglets), 3.17 |
| `V2-AccueilVide.dc.html` | 3.2 Home – empty | 3.17 |
| `V2-Lecture.dc.html` | 4.1 Now playing | 3.18 |
| `V2-File.dc.html` | 4.2 Up next | 3.18 |
| `V2-Feedback.dc.html` | 4.3 Did it fit? | 3.15 |
| `V2-LectureImpossible.dc.html` | 4.5 Can't play | 3.13, 3.18 |
| `V2-Bibliotheque.dc.html` | 5.1 My library | **pas encore de tâche** (onglet Library créé en 1.6) |
| `V2-Reglages.dc.html` | 6.1 Settings | 3.19 |
| `V2-CompteSpotify.dc.html` | 6.2 Spotify account | 1.26, 3.19 |
| `V2-Sante.dc.html` | 6.3 Health & consents | 3.19 |
| `V2-MesDonnees.dc.html` | 6.4 My data | 3.19 |
| `V2-APropos.dc.html` | 6.5 About & privacy | 3.19 |

Navigation : 3 onglets **Home / Library / Settings** ; le lecteur s'ouvre depuis Home (une
situation) ; l'écran Debug n'est pas dans le design (accessible depuis Settings, build Debug
seulement, cf. TODO 1.6).

## Aide-mémoire (les valeurs exactes restent dans les fichiers)

- Police : Helvetica Neue ; titres en graisse 800 avec interlettrage négatif.
- Fonds : écran `#121212`, lecteur `#191414`, cartes `#181818`, surfaces `#282828`,
  pastilles `#2A2A2A`, champ de saisie `#242424`, séparateurs `#333333`.
- Texte : `#FFFFFF`, secondaire `#B3B3B3` ; bordures `#727272` ; piste de progression `#4D4D4D`.
- Accent : vert `#1ED760` (texte noir dessus) ; destructif `#E91429` ; bleu `#509BF5`.
- Situations : Wake-up `#E8A21A`, Stress `#E8115B`, Low energy `#E13300`, Wind-down `#477D95`.
- Rayons : cartes 8, vignettes 4, boutons et pastilles en pilule (500) ; boutons pleine largeur
  hauteur 52 ; cibles tactiles ≥ 44.
- Marges d'écran : 56 en haut, 16 sur les côtés, 24 en bas.

## Placeholders à remplacer

- « Spotify cover art, unmodified » → la vraie pochette, non modifiée (NFR6).
- « SPOTIFY LOGO » et les cercles en pointillés → le logo Spotify officiel (NFR6).
- `[Account name]`, `[date]`, chiffres d'exemple → les vraies valeurs.
- Les textes (en anglais) passent quand même par la relecture de Cyprien (3.20) : aucun mot
  d'émotion, aucune promesse médicale.

## Mettre à jour

Modifier le canvas d'abord, puis recopier ici **tous** les fichiers modifiés (et `canvas.json`)
dans une PR, en mettant à jour la version et la date ci-dessus.

# UDR-0157 : Sujet, copie et résultat d'un exercice en cahier noir et blanc
<!-- index
titre: Sujet, copie et résultat en noir et blanc
statut: Accepté
adr-lie: —
problematique: Le sujet, la copie et le résultat d'un exercice gardaient le bleu, le vert et le rouge alors que les feuilles de la leçon sont en noir et blanc.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-05 |
| **Chantier** | `docs/chantiers/sujets-cahier-noir-blanc` |
| **ADR lié** | — |
| **Remplacé par** | — |

---

## 1. Contexte

Issue #390. L'élève passe d'une feuille noir et blanc (page de la leçon, UDR-0149) à des cartes bleues, vertes et rouges dès qu'il
ouvre un exercice, remplit sa copie ou lit sa correction. Le sujet ne ressemble plus à une interrogation.

## 2. Décision

Une feuille de style isolée, `exam_sheet.css`, redéfinit les variables du design system dans un conteneur `.exam-sheet`. Les vues
gardent leurs classes et leurs partiels : seules les valeurs changent dans le conteneur. Rejeté : réécrire chaque partiel en
classes `.ps-*` (une trentaine de fichiers, deux rendus à maintenir pour les mêmes questions).

La feuille est du papier cahier : papier `#fbf6e9`, lignes Seyès grises, marge verticale grise, sur fond gris `#d6d6d6`. Décision du porteur
(2026-11-05) : pas de maquette par sujet ; le tableau de l'issue et l'exemple Thalès sont un gabarit générique pour tous les sujets
d'interrogation et de devoir, toutes matières. Le même gabarit (`.sheet-cahier`, variables `--sheet-*`) habille `.ps-sheet`
(« Prépare interros », « Prépare devoirs », devoir reçu) : `prepare_sheet.css` importe `exam_sheet.css`.

## 3. Règles d'implémentation

**Structure**
- `assessment/exercises/show`, `assessment/exercise_sessions/show`, `assessment/session_results/show` :
  `content_for :head` charge `stylesheet_link_tag "exam_sheet"` ; tout le contenu de la page (lien de retour compris) est dans
  `<div class="exam-sheet">`.
- Sujet et copie : en tête de la feuille, un cartouche `#exam-header` (`<header>`) : à gauche « INTERROGATION » (petites capitales),
  à droite « Lnclass » ; puis le titre de l'exercice en `h1`, souligné d'un double trait noir ; puis la consigne `#exam-instructions`
  en italique : « n questions », suivi de « · barème : p points » seulement si une question ne vaut pas 1 point. Aucune durée,
  aucune mention du nombre de tentatives.
- Sur le sujet (`exercises/show`), le `h1` d'aujourd'hui devient celui du cartouche (un seul `h1`).
- Résultat : contenu inchangé (appréciation en `h1`, note sur 20, points, « À revoir », correction, pause).

**Tokens** (dans `.exam-sheet` seulement, `app/assets/stylesheets/exam_sheet.css`)
- Encre `#1a1a1a` ; texte secondaire `#333` ; discret `#555` ; traits `#d6d6d6` ; traits forts et champs `#b5b5b5` ; fond doux `#f5f5f5`.
- `--color-brand`, `--color-brand-strong`, `--color-info`, `--color-success`, `--color-error`, `--color-warning`, `--color-struggling`,
  `--color-school`, `--color-team`, `--color-teacher`, `--color-gold`, `--color-fragile`, `--color-signal-*`, `--color-band-ink` →
  `#1a1a1a` (sauf `--color-band-ink`) ; leurs variantes `-soft`, `--color-mist`, `--color-tint-*` → `#f5f5f5` ; `--color-line` `#d6d6d6`, `--color-line-strong`
  `#b5b5b5` ; `--color-ink` `#1a1a1a` ; `--color-mute` `#555` ; `--color-paper` et `--color-white` `#fbf6e9` (le papier) ; `--color-band-ink` `#fff` (écart : le bouton « brand » est texte `ink` sur fond `brand`, rendu `#1a1a1a` sur `#1a1a1a` sinon ; il est aussi noir à texte blanc dans `.exam-sheet`).
- Choix sélectionné : fond `rgba(0,0,0,.08)` via `--color-brand-soft`.
- Rayons `--radius-sm`, `--radius-ln`, `--radius-card` : 0. Ombres `--shadow-card`, `--shadow-lift` : `none`.
- Police : Source Serif 4 auto-hébergée (`--font-sans`, `--font-display`), les mêmes `@font-face` que `prepare_sheet.css`.
- Papier cahier (variables `--sheet-paper` `#fbf6e9`, `--sheet-ink`, `--sheet-rule` `rgba(0,0,0,.13)`, `--sheet-rule-fine` `rgba(0,0,0,.05)`,
  `--sheet-margin` `rgba(0,0,0,.28)`, `--sheet-field` `#b5b5b5`) : un seul bloc `.sheet-cahier` par page dessine le papier, les lignes (fortes
  tous les 32 px, fines tous les 8 px, derrière le texte) et la marge à 74 px (téléphone : `clamp(18px, 7.4vw, 74px)`), même géométrie que
  `course_sheet.css`. Marges `clamp(14px, 5vw, 52px)`. Les cartes sont transparentes à bord noir fin : les lignes ne sont jamais coupées.
- Le conteneur : fond `#d6d6d6` en marge de page dès 700 px ; sous 640 px, la feuille va bord à bord, sans défilement horizontal.
- Mode sombre : le conteneur redéfinit les valeurs claires, la feuille reste du papier clair (comme UDR-0149).

**Comportement**
- Aucun changement : Turbo, Stimulus (`assessment--copy`, `math`, `modal`, `assessment--confetti`, `reveal`), formulaires et liens
  restent les mêmes.

**États obligatoires**
- Erreur (422 de la copie) : résumé et message par question, noir sur `#f5f5f5`, avec l'icône d'aujourd'hui.
- Succès : le résultat ; pause : « Tu pourras recommencer à … ».
- Vide et chargement : sans objet (une page serveur, un exercice a toujours au moins une question).

**Accessibilité**
- Juste / Faux / Sans réponse : le mot et l'icône restent, la couleur ne porte jamais le sens.
- Cibles ≥ 48 px (`min-h-tap`) inchangées ; focus visible noir.
- Contraste : encre `#1a1a1a` sur papier, discret `#555` sur papier (≥ 7:1).
- Sous 640 px : pas de défilement horizontal ; les figures gardent `max-width: 100%`.

## 4. Conséquences

- La fiche de révision et le reste de l'application ne chargent pas `exam_sheet.css`.
- `exam_sheet.css` rejoint l'exception aux jetons de `course_sheet.css` et `prepare_sheet.css` (design_tokens_test).
- Une nouvelle couleur ajoutée au `@theme` doit être neutralisée dans `.exam-sheet` ; un test le vérifie.

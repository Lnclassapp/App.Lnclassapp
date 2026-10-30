# UDR-XXXX : Parcours matière → exercice — la carte « Prochain exercice » dans la matière et dans la leçon
<!-- index
titre: Parcours matière → exercice : carte Prochain exercice dans la matière et la leçon
statut: Accepté
adr-lie: —
problematique: De la grille des matières à un exercice, l'élève fait 4 clics et lit 461 mots avant le premier lien d'exercice de la leçon ; il doit voir tout de suite où cliquer.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/parcours-matiere-exercice` |
| **ADR lié** | — |
| **Remplacé par** | — |

Complète : UDR-0085 §3.1 (vue d'une matière), UDR écrans élève sans répétition §3.6 et §3.6 bis, UDR-0139 §2 (page de la leçon). Reprend le bouton de UDR-0132 (`next_step/_start`).

---

## 1. Contexte

De la grille des matières à la feuille d'un exercice : 4 clics (matière → leçon → sujet → « Faire l'exercice »). Sur la leçon, la fiche de révision passe avant les exercices : 461 mots et 1 623 px de défilement sur téléphone avant le premier lien d'exercice. L'élève ne voit pas où cliquer.

## 2. Décision

**Une carte « Prochain exercice » en tête de la vue d'une matière et de la page d'une leçon.** Son bouton ouvre directement la feuille : la session démarre (POST, comme la carte de l'accueil) ou reprend (lien vers la session). Grille → feuille : **2 clics**. Leçon choisie → feuille : 3 clics.

- **Pourquoi une carte plutôt que remonter les exercices au-dessus de la fiche ?** La page de la leçon est aussi la fiche de révision (UDR-0139) : on garde son ordre et on ajoute un raccourci de quelques mots.
- **Pourquoi sauter le sujet ?** La carte de l'accueil le fait déjà ; le sujet reste ouvert depuis la liste « Prépare interros ».
- **Lecture de « 50 mots »** : 50 mots au plus avant la cible du clic suivant, cible visible sans défiler à 390 px (memo, « Lecture tranchée »).

## 3. Règles d'implémentation

**Structure**
- Partial : `app/views/catalog/courses/_next_exercise.html.erb`, locals `(next_exercise:, scope:)` ; `scope` vaut `:material` ou `:lesson`. Rien n'est rendu si `next_exercise` est `nil`.
- Conteneur : `<section id="material_next_exercise">` (matière, téléphone), `id="lesson_material_next_exercise"` (matière, ordinateur) ou `id="lesson_next_exercise"` (leçon), `aria-labelledby` sur son titre.
- Contenu, dans cet ordre : étiquette en capitales « PROCHAIN EXERCICE » (`text-xs tracking-wide uppercase`) ; titre de l'exercice (`font-display text-base font-medium`, 2 lignes au plus) ; sous-ligne `text-sm text-mute` : le nom de la leçon (matière seulement ; absent sur la leçon, déjà titrée) ; bouton pleine largeur.
- Bouton : partial existant `classroom/student_homes/next_step/_start` (POST `exercise_sessions_path` ou lien `exercise_session_path`). Libellé « Commencer l'exercice » ; session en cours : « Reprendre à la question N ».
- Leçon seulement : sous le bouton, lien « Tous les exercices » vers `#prepare-interros` (≥ 44 px, `text-brand-strong`).
- Place : matière (téléphone) sous le titre de la matière, avant la recherche ; matière (ordinateur) sous les pastilles de matières, avant la recherche ; leçon : entre l'en-tête de la leçon et « Fiche de révision ».
- Rien dans la ligne d'un exercice (`_exercise_row`) ni dans la page de l'exercice ne change.

**Tokens**
- Carte : `ui_card padding: :md`, fond blanc, bordure `line`. Pas de seconde couleur ; bouton `:primary` (bleu Lnclass). Jamais d'ambre (pas d'urgence ici).
- Texte ≥ 12 px ; étiquette `text-mute`.

**Comportement**
- Choix de l'exercice (`Queries::Catalog::NextExerciseQuery`) : exercices publiés, non archivés, d'une leçon publiée du niveau de l'élève, notion publiée ou toute la leçon, dans l'ordre du programme (numéro de leçon, notion, position).
  1. une session en cours sur l'un d'eux → la plus récente, « Reprendre à la question N » ;
  2. sinon, après le dernier exercice terminé, le premier non terminé qui le suit ; à défaut, le premier non terminé ;
  3. sinon (tout terminé, ou aucun exercice) → pas de carte.
- Pas de Turbo Frame : la carte est rendue avec la page ; une recherche (frame `courses` ou `lessons`) ne la recharge pas.
- `data-turbo-prefetch="false"` sur la carte : un préchargement n'ouvre rien.

**États obligatoires**
- À commencer · En cours (« Reprendre ») · Rien à proposer (pas de carte) · Élève sans classe (pas de carte, l'état vide existant).

**Accessibilité**
- Bouton et lien ≥ 44 px, focus visible (`outline-brand`).
- `aria-label` du bouton : « Commencer l'exercice <titre> » ou « Reprendre l'exercice <titre> à la question N ».
- Un seul `h2` par carte, relié par `aria-labelledby`.

## 4. Conséquences

- Grille → feuille en 2 clics ; aucun écran intermédiaire ne fait lire plus de 50 mots avant sa cible.
- La vue d'une matière et la page de la leçon gagnent une requête de lecture (deux au plus) pour l'élève ; rien pour les autres rôles.
- Interdit : répéter un exercice assigné dans cette carte (il est sur l'accueil), mettre la carte dans les vues de l'enseignant.

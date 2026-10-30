# UDR-XXXX : Les feuilles « Prépare interros » et « Prépare devoirs » de la page d'une leçon
<!-- index
titre: Feuilles Prépare interros et Prépare devoirs
statut: Accepté
adr-lie: XXXX-sujets-de-devoir-et-verification-sur-la-feuille
problematique: L'élève ne voit jamais une notion ni un sujet de devoir en entier et quitte la leçon pour chaque exercice
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/prepare-interros-cahier` |
| **ADR lié** | ADR-XXXX-sujets-de-devoir-et-verification-sur-la-feuille |
| **Remplacé par** | — |

---

## 1. Contexte

« Prépare interros » est une grille de cartes (UDR-0139 §3.4, UDR-0145) : chaque exercice s'ouvre sur une autre page.
Touré a dessiné la feuille que l'élève connaît en classe et demande qu'elle s'applique **telle quelle**.

## 2. Décision

Les deux maquettes de [`docs/chantiers/prepare-interros-cahier/maquettes/`](../../chantiers/prepare-interros-cahier/maquettes/)
sont la référence au pixel près : on reprend leurs styles, leurs libellés et leur disposition, sans les retoucher ni les
traduire en tokens du design system. Elles remplacent, dans la page de la leçon seulement, la grille de cartes de
UDR-0145 §3.2. La seule adaptation est la vue de l'enseignant, que la maquette ne dessine pas.

## 3. Règles d'implémentation

**Structure** (`app/views/catalog/courses/_prepare_sheets.html.erb`, rendu là où `_prepare_interros` l'est aujourd'hui)
- Section « Prépare interros » : une feuille par notion qui a au moins un exercice, dans l'ordre des notions ; puis, si la
  leçon a des exercices « Toute la leçon » sans sujet, une dernière feuille titrée « TOUTE LA LEÇON », sans encadré.
- Section « Prépare devoirs », juste dessous, seulement si la leçon a un sujet : une feuille par sujet, dans l'ordre.
- Feuille (`catalog/courses/sheets/_sheet.html.erb`), recopiée de la maquette, du haut vers le bas :
  1. cartouche à bordure 2 px : « PRÉPARE INTERROS » / « PRÉPARE DEVOIRS », « MATHÉMATIQUES » (nom de la matière en
     capitales), « Lnclass · <titre de la leçon> », « Classe de <niveau> · Notion n / N » ou « Sujet n / N » ;
  2. titre en capitales (nom de la notion, titre du sujet), puis la progression en italique « x / n exercice(s) réussi(s) » ;
  3. encadré gris « À retenir : » (`sheet.remember` de la notion, absent s'il est vide) ou « Notions mobilisées : » ;
  4. les exercices (`_exercise.html.erb`) : « Exercice n » et son statut (« Réussi », « À revoir », vide) ; l'énoncé et la
     figure (`figure_key`, partiel d'aujourd'hui) ; chaque question avec son étiquette (QCM, Vrai ou faux, Complète, Calcul ;
     les autres types : leur partiel `exercise_sessions/kinds/*` d'aujourd'hui, dans le même cadre) ; l'encadré pointillé
     « Indice : » ; la barre « Vérifier ma réponse » (noir) · « Indice » (blanc, absent sans indice) ou
     « Refaire l'exercice » ; puis le résultat (`_result.html.erb`) ;
  5. pied : « Lnclass · Prépare interros · Notion n » ou « … · Sujet n », et le lien souligné « Recommencer cette notion »
     ou « Recommencer ce sujet ».
- Résultat, recopié de la maquette : « Ta note : x / 10 » (22 px), « Mention : … » (italique), « x bonne(s) réponse(s)
  sur n. », « CORRECTION », puis par question « a. ✓ Juste | ✗ Faux | ✗ Sans réponse · Bonne réponse : … » et
  « Explication : » (`questions.explanation`). Note et mention : `Entities::Assessment::SheetGrade`.

**Tokens**
- Exception assumée au design system : les valeurs de la maquette, dans `app/assets/stylesheets/prepare_sheet.css`, en
  classes `.ps-*` (fond `#d6d6d6`, feuille blanche `max-width: 880px`, ombre `0 8px 28px rgba(0,0,0,.15)`, bordures noires,
  `#f5f5f5`, `#e8e8e8`, `#999`, rayon 0). Police « Source Serif 4 » déjà auto-hébergée (`app/assets/fonts`). Aucun style en
  ligne dans les vues.
- Pas de couleur : noir, blanc et gris seulement.

**Comportement**
- « Vérifier ma réponse » : formulaire `POST /exercises/:exercise_public_id/sheet_check` dans `turbo_frame_tag
  "sheet-exercise-<public_id>"` ; la réponse remplace ce frame (exercice corrigé) et la progression
  `#sheet-progress-<feuille>` par Turbo Stream. Sans JS : redirection vers la leçon, ancre `#sheet-exercise-<public_id>`.
- Stimulus `prepare-sheet` (`app/javascript/controllers/prepare_sheet_controller.js`) : garde les réponses non vérifiées
  dans `localStorage` (clé `lnclass-prepare-<exercise_public_id>`, lecture et écriture sous try/catch) ; « Indice »
  montre ou cache l'encadré (`aria-expanded`) ; « Refaire l'exercice » et « Recommencer… » remettent à blanc dans le
  navigateur, sans requête : la prochaine vérification ouvre une nouvelle copie.
- Rechargement : un exercice dont l'élève a une copie terminée et qui n'a pas été remis à blanc s'affiche corrigé.
- Vue enseignant : pas de champ ; « Assigner à <classe> » / « ✓ Assigné à <classe> » à la place de « Vérifier ma réponse »
  et « Indice », même style ; la bascule `classroom/assignments/toggle` d'aujourd'hui, une par classe. Équipe : idem, sans
  « Assigner ».
- Visiteur : « Vérifier ma réponse » est un lien vers la connexion.

**États obligatoires**
- Vide : leçon sans exercice ni sujet → l'état vide d'aujourd'hui (`exercises_empty`).
- Chargement : le bouton passe à « Vérification… », `aria-busy="true"` sur le frame, désactivé.
- Erreur : dans l'exercice, `p role="alert"` : pause « Tu as rendu 3 copies d'affilée. Tu pourras recommencer à HH h MM. » ;
  archivé « Cet exercice n'existe plus. » ; autre « La copie n'est pas partie. Réessaie. ». Les réponses restent.
- Succès : l'exercice corrigé, focus sur « Ta note ».

**Accessibilité**
- Boutons ≥ 44 px de haut, comme la maquette (exception assumée aux 48 px). Focus visible : contour noir 2 px.
- QCM et Vrai ou faux : `role="radiogroup"` et `aria-checked` ; champs avec `aria-label` = l'intitulé de la question.
- Progression et résultat dans `aria-live="polite"`.

## 4. Conséquences

- Dans la page de la leçon, la grille de cartes de UDR-0145 §3.2 disparaît au profit des feuilles. La page de l'exercice
  (`exercise_sessions/show`) et le résultat (`session_results/show`) restent pour les exercices assignés.
- `prepare_sheet.css` est la seule exception au design system ; toute autre vue qui voudrait le cahier passe par l'issue #390.

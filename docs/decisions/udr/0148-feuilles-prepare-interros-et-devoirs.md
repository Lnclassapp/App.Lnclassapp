# UDR-0148 : Les feuilles « Prépare interros » et « Prépare devoirs » de la page d'une leçon
<!-- index
titre: Feuilles Prépare interros et Prépare devoirs
statut: Accepté
adr-lie: 0121
problematique: L'élève ne voit jamais une notion ni un sujet de devoir en entier et quitte la leçon pour chaque exercice
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/prepare-interros-cahier` |
| **ADR lié** | ADR-0121 |
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
- Section « Prépare devoirs », juste dessous, seulement si la leçon a un sujet : une feuille par sujet, dans l'ordre. Elle
  remplace la section « Prépare devoirs » par type d'exercice de l'UDR-0145 §3.2 ter : une évaluation sans sujet reste dans la
  feuille de sa notion ou dans « Toute la leçon ».
- Feuille (`catalog/courses/sheets/_sheet.html.erb`), recopiée de la maquette, du haut vers le bas :
  1. cartouche à bordure 2 px : « PRÉPARE INTERROS » / « PRÉPARE DEVOIRS », « MATHÉMATIQUES » (nom de la matière en
     capitales), « Lnclass · <titre de la leçon> », « Classe de <niveau> · Notion n / N » ou « Sujet n / N » ;
  2. titre en capitales (nom de la notion, titre du sujet), puis la progression en italique « x / n exercice(s) réussi(s) » ;
  3. encadré gris « À retenir : » (`sheet.remember` de la notion, absent s'il est vide) ou « Notions mobilisées : » ;
  4. les exercices (`_exercise.html.erb`) : « Exercice n » et son statut (« Réussi », « À revoir », vide) ; l'énoncé et la
     figure (`figure_key`, partiel d'aujourd'hui) ; chaque question avec son étiquette (QCM, Vrai ou faux, Complète, Calcul ;
     les autres types : leur partiel `exercise_sessions/kinds/*` d'aujourd'hui, dans le même cadre) ; l'encadré pointillé
     « Indice : » ; la barre « Vérifier ma réponse » (noir) · « Indice » (blanc, absent sans indice) ou
     « Refaire l'exercice » ; une fois la copie rendue, « Voir ma correction » (lien vers sa page de résultat) à la place d'un bloc de résultat ;
  5. pied : « Lnclass · Prépare interros · Notion n » ou « … · Sujet n », et le lien souligné « Recommencer cette notion »
     ou « Recommencer ce sujet ».
- Résultat (Lot C bis, Touré, 2026-10-30, memo Q18) : la feuille n'a ni « Ta note », ni mention, ni correction. La note sur 20 et la
  correction sont celles de la page de résultat d'aujourd'hui (`exercise_session_result_path`), inchangée. Au retour, un exercice
  vérifié porte son statut (« Réussi » ou « À revoir »), les marques ✓ / ✗ de ses questions, « Voir ma correction » (lien vers sa
  page de résultat) et « Refaire l'exercice » ; la progression « x / n exercices réussis » reste.

**Devoir composé par l'enseignant** (ajout du 2026-10-30)
- Sous chaque exercice de la feuille, pour l'enseignant : une case « Choisir » (`role="checkbox"`, 44 px), à côté de
  « Assigner à <classe> », même style.
- Bandeau collé en bas de l'écran (`app/views/catalog/courses/sheets/_batch_bar.html.erb`), cadre noir 2 px, fond blanc,
  visible dès un exercice choisi : « n exercice(s) choisi(s) » · « Vider » (lien souligné) · « Envoyer à <classe> »
  (bouton noir), un par classe de l'enseignant pour ce niveau. Sélection gardée dans `localStorage`
  (`lnclass-batch-<teacher>`), elle suit l'enseignant d'une leçon à l'autre.
- Après l'envoi (Turbo Stream sur `#sheet-batch-status`, le bandeau reste en place) : « Devoir envoyé à 3e 1 : n exercices. » et, s'il
  y en a, « Déjà assigné : <titres>. » (`role="status"`) ; la sélection est vidée et les exercices envoyés passent à « ✓ Assigné à <classe> ».
  Un refus (liste vide ou de plus de 10, exercice inconnu ou d'un autre niveau, jours de séance non donnés) s'affiche en toast et
  garde la sélection. Au plus 10 exercices : le onzième n'est pas coché, le bandeau dit « Choisis entre 1 et 10 exercices. ».

**Devoirs reçus par l'élève** (`app/views/classroom/student_classrooms/_assigned_sheets.html.erb`, à la place de la liste
des `_assigned_exercise`)
- Un envoi = une feuille `_sheet` (même partiel que la leçon), la plus récente en haut ; un exercice assigné seul est un
  envoi d'un exercice.
- 3 exercices ou plus : cartouche « PRÉPARE DEVOIRS », « Devoir n / N », titre « DEVOIR DU <date d'envoi> », encadré
  « Notions mobilisées : » (noms des notions des exercices, dans l'ordre, sans doublon ; un exercice « Toute la leçon »
  apporte le nom de sa leçon), sous-titre « À rendre le <échéance> ».
- 1 ou 2 exercices : cartouche « PRÉPARE INTERROS », titre = nom de la notion si elle est commune, sinon « DEVOIR DU
  <date> » ; « À retenir : » seulement si la notion est commune et a un « À retenir ».
- Avant de rendre : le bouton noir est « Rendre à l'enseignant » (même route `sheet_check`, la copie se rattache à
  l'assignation active) ; « Indice » reste ; ni note ni correction. Après : la page de résultat de la copie (le retour est
  « Ma classe »), puis, sur la feuille, « Voir ma correction » et « Refaire l'exercice » ; l'exercice refait porte « Vérifier ma réponse » et sa copie n'est plus rattachée au devoir
  (entraînement) ; pas de « Recommencer » sur la feuille d'un devoir reçu (memo Q17).
- Dans la leçon, un exercice assigné à l'élève et pas encore rendu : à la place de « Vérifier ma réponse » et
  « Indice », `p` « Ce devoir est à rendre : ouvre-le dans Ma classe. » avec le lien vers « Ma classe ».

**Tokens**
- Exception assumée au design system : les valeurs de la maquette, dans `app/assets/stylesheets/prepare_sheet.css`, en
  classes `.ps-*` (fond `#d6d6d6`, feuille blanche `max-width: 880px`, ombre `0 8px 28px rgba(0,0,0,.15)`, bordures noires,
  `#f5f5f5`, `#e8e8e8`, `#999`, rayon 0). Police « Source Serif 4 » déjà auto-hébergée (`app/assets/fonts`). Aucun style en
  ligne dans les vues.
- Pas de couleur : noir, blanc et gris seulement.

**Comportement**
- « Vérifier ma réponse » : formulaire `POST /exercises/:exercise_public_id/sheet_check` dans `turbo_frame_tag
  "sheet-exercise-<public_id>"`, avec `data-turbo-frame="_top"` : le succès redirige (303, avec ou sans JS) vers la page de
  résultat de la copie, `exercise_session_result_path(…, return_to: "sheet")`. Les refus restent sur la feuille : réponse
  Turbo Stream 422 qui ajoute `p role="alert"` à la fin de l'exercice, réponses gardées.
- Retour depuis la page de résultat : le lien « Retour à la leçon » existant mène à `course_path(slug, anchor:
  "sheet-exercise-<public_id>")` quand l'élève vient de la feuille ; « Retour à Ma classe » pour un devoir rendu depuis « Ma
  classe » (`return_to=class`). `return_to` ne prend que ces deux valeurs, jamais une adresse ; sinon le retour d'aujourd'hui.
  Rien d'autre ne change sur cette page.
- Stimulus `prepare-sheet` (`app/javascript/controllers/prepare_sheet_controller.js`) : garde les réponses non vérifiées
  dans `localStorage` (clé `lnclass-prepare-<propriétaire>-<exercise_public_id>`, le propriétaire étant l'id de l'élève connecté ou `visitor`, posé par le serveur (`data-prepare-sheet-owner-value`) : un brouillon ne se recharge pas dans le compte d'un autre sur le même appareil ; lecture et écriture sous try/catch) ; « Indice »
  montre ou cache l'encadré (`aria-expanded`) ; « Refaire l'exercice » et « Recommencer… » remettent à blanc dans le
  navigateur, sans requête : la prochaine vérification ouvre une nouvelle copie.
- Rechargement : un exercice dont l'élève a une copie terminée et qui n'a pas été remis à blanc s'affiche vérifié (statut,
  « Voir ma correction », « Refaire l'exercice »).
- Vue enseignant : pas de champ ; « Assigner à <classe> » / « ✓ Assigné à <classe> » à la place de « Vérifier ma réponse »
  et « Indice », même style ; la bascule `classroom/assignments/toggle` d'aujourd'hui, une par classe. Équipe : idem, sans
  « Assigner », et le statut éditorial de chaque exercice (« Brouillon » / « Publié », `catalog.content_status.*`) à droite
  de l'en-tête de l'exercice, en `.ps-status` ; les autres rôles ne le voient pas.
- Visiteur : « Vérifier ma réponse » est un lien vers la connexion.

**États obligatoires**
- Vide : leçon sans exercice ni sujet → l'état vide d'aujourd'hui (`exercises_empty`).
- Chargement : le bouton passe à « Vérification… », `aria-busy="true"` sur le frame, désactivé.
- Erreur : dans l'exercice, `p role="alert"` : pause « Tu as rendu 3 copies d'affilée. Tu pourras recommencer à HH h MM. » ;
  archivé « Cet exercice n'existe plus. » ; autre « La copie n'est pas partie. Réessaie. ». Les réponses restent.
- Succès : la page de résultat de la copie (note sur 20), comme après une copie rendue depuis l'exercice. Pas de focus à gérer
  sur la feuille : le retour recharge la page à l'ancre de l'exercice.

**Accessibilité**
- Boutons ≥ 44 px de haut, comme la maquette (exception assumée aux 48 px). Focus visible : contour noir 2 px.
- QCM et Vrai ou faux : `role="radiogroup"` et `aria-checked` ; champs avec `aria-label` = l'intitulé de la question.
- Progression et résultat dans `aria-live="polite"`.

## 4. Conséquences

- Dans la page de la leçon, la grille de cartes de UDR-0145 §3.2 disparaît au profit des feuilles. La page de l'exercice
  (`exercise_sessions/show`) et le résultat (`session_results/show`) restent pour les exercices assignés.
- `prepare_sheet.css` est la seule exception au design system ; toute autre vue qui voudrait le cahier passe par l'issue #390.

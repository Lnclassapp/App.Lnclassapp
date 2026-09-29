# UDR-0030 : Assigner un cours — « Assigner à mes classes », une ligne par classe avec la bascule de la classe

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot D7, critère CA-27 |
| **ADR lié** | [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (active/archived) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (seul un contenu publié s'assigne) · [UDR-0028](0028-cours-dans-la-classe-et-bascule-d-assignation.md) (bascule d'assignation) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 (CRUD Hotwire) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

Un enseignant qui parcourt le catalogue trouve un cours et veut le proposer à ses classes. Dans l'ancienne application, un pied de carte prévoyait un bouton par classe sur la page du cours, mais il n'était jamais rendu : aucun contrôleur ne renseignait la liste des classes (CA-27). Pour assigner le cours, l'enseignant devait quitter le catalogue, ouvrir chaque classe, puis y retrouver le cours.

## 2. Décision

1. **Une page dédiée, pas un pied de carte.** Le bouton « Assigner à mes classes » de la page du cours (B1) mène à `GET /courses/:course_slug/assignments`. La page du cours reste la même pour tous les rôles ; l'action de l'enseignant a sa propre adresse, qu'on peut ouvrir, recharger et partager.
2. **Une ligne par classe active de l'enseignant**, chacune avec la bascule de l'UDR-0028, rendue telle quelle. Le cours a donc le même bouton ici et dans la classe, et reçoit les mêmes streams : assigner ou retirer se fait en place, sans rechargement, avec un toast qui nomme le cours et la classe.
3. **Seules les classes actives.** Une classe archivée n'accepte plus d'assignation (`AssignPolicy`) : elle n'est pas proposée plutôt que d'afficher un bouton qui échoue.
4. **Toutes les classes actives, quel que soit leur niveau.** L'enseignant décide ; la ligne affiche le niveau et l'établissement pour qu'il choisisse en connaissance de cause.
5. **Réservée à l'enseignant.** L'équipe n'enseigne pas de classe : elle reçoit 403, comme l'élève.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Écran `classroom/course_assignments/index`, `content_for :nav_key, "courses"`.
  - Lien de retour « Retour au cours » (`chevron-left`) vers `course_path(course.slug)`.
  - `ui_card` : sur-titre « Assigner à mes classes », `h1` du cours, sous-titre, `ui_subject_badge` de la matière, badge du niveau (et de la série).
  - `section#course_assignment_classrooms` : titre « Mes classes », aide « Assignez le cours à une classe pour le proposer à ses élèves. », puis une liste (`divide-y`, carte) d'une ligne `li#course_assignment_<classroom_public_id>` par classe, triée par niveau puis dans l'ordre naturel des noms (« 6ème 2 » avant « 6ème 10 ») :
    - nom de la classe (lien vers `classroom_path`), puis « <niveau> <série> · <établissement> » ;
    - la bascule `classroom/assignments/_toggle` avec `assignable_type: "Course"`, `assignable_key: course.slug`, `assignable_name: course.name`, `assignment_public_id:` l'assignation active du cours à cette classe (ou `nil`), dans un `role="group"` nommé « Assignation du cours à <classe> ».
- Lecture : `Queries::Classroom::CourseAssignmentTargetsQuery` (le cours publié ; les classes `active` liées à l'enseignant par `teacher_classrooms` ; l'assignation `active` de ce cours seulement).

**Tokens**
- Composants `ui_*` uniquement ; la bascule garde ses propres classes (UDR-0028).
- Aucune couleur ni classe reprise de l'ancienne application.

**Comportement**
- Pas de stream propre à cet écran : la bascule poste vers `Classroom::AssignmentsController` (D5), dont `create` et `archive` remplacent `#assignment_<classe>_Course_<slug>` et affichent le toast.
- Repli sans Turbo : la redirection `303` de D5 revient sur cette page.
- Cours inconnu, brouillon ou archivé : 404. Équipe ou élève : 403. Visiteur non connecté : page de connexion.

**États obligatoires**
- Vide (aucune classe active) : « Aucune classe active pour l'instant. », « Déclarez les classes où vous enseignez : elles apparaîtront ici. », icône `user-group`, action « Déclarer mes classes » vers `teacher_classrooms_path`.
- Succès et refus : ceux de la bascule (UDR-0028 §3).

**Accessibilité**
- Les boutons de la bascule nomment le cours (UDR-0028) ; chaque groupe nomme la classe.
- Cibles tactiles ≥ 48 px ; sur téléphone, la page ne défile jamais en largeur.

## 4. Conséquences

- Le point d'entrée de l'assignation depuis le catalogue est cette page ; la page du cours n'affiche jamais de liste de classes.
- Toute évolution de la bascule (UDR-0028) s'applique ici sans changement.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- Retour : `ui_back_link` vers `course_path`, libellé = nom du cours (au lieu de « Retour au cours »).
- Titre : « Assigner à mes classes · Enseignant · Lnclass ».

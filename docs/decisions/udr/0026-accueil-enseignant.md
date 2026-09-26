# UDR-0026 : Accueil enseignant — mes classes et leurs chiffres, activité « Bientôt », cours ; aucun montant

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot D3, critères TR-05, TR-02 ; TR-06 et TR-07 écartés |
| **ADR lié** | [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) (école principale, configuration) · [ADR-0041](../adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) (année scolaire) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (assignations actives) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) (shell, sections d'accueil) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) · [UDR-0025](0025-declaration-des-classes.md) (déclaration des classes) · [UDR-0027](0027-page-classe.md) (page d'une classe) |
| **Remplacé par** | — |

---

## 1. Contexte

L'accueil est la page où arrive l'enseignant configuré, à chaque connexion. Dans l'ancienne application (`teachers/feed/index`) :

- le fil levait `NameError` dès que l'enseignant avait une classe (TR-05) : la requête lisait une table supprimée ;
- un enseignant sans école tournait en rond entre `/` et `/teachers/classrooms` (TR-02) ;
- un encart « examen dashboard » affichait des gains « Prepa » en FCFA calculés sur une donnée forcée à 0 (TR-06), et `/teachers/dashboard` était un écran de scaffold (TR-07) ;
- les classes défilaient dans un carrousel qui ne disait rien d'elles, sinon leur code.

L'enseignant a besoin de savoir, d'un coup d'œil, où en sont ses classes et d'en ouvrir une.

## 2. Décision

1. **Les sections suivent l'ordre du shell** (`NavigationHelper::HOME_SECTIONS[:teacher]`) : « Mes classes », « Activité de vos classes », « Cours ».
2. **« Mes classes » liste les classes déclarées** (`teacher_classrooms`), actives, de l'année scolaire en cours (ADR-0041), comme la déclaration des classes : triées par niveau, puis par nom, les nombres comparés comme des nombres. Chaque carte donne **l'effectif** (adhésions présentes), **le nombre d'assignations actives** (tous types confondus) et **le score moyen**, puis mène à la page de la classe (UDR-0027). Une grille de cartes plutôt qu'un carrousel : tout est visible sans geste caché.
3. **Le score moyen** est la moyenne des scores des sessions **terminées** par les élèves **présents** de la classe, sur les exercices **de la matière de l'enseignant** : un enseignant de SVT ne lit pas la réussite de ses élèves en mathématiques. Sans session terminée : « Aucune session terminée ». Le libellé est « Score moyen » : le mot interdit par l'UDR-0007 est « Moyenne » employé seul pour une note, pas l'adjectif qui qualifie le score.
4. **« Modifier mes classes »** mène à la déclaration des classes (UDR-0025), toujours présent, même quand la liste est vide.
5. **L'activité est annoncée « Bientôt »** (V3) : un état vide, sans lien ni bouton, plutôt qu'une section fausse ou un lien mort.
6. **Aucun montant** : ni « Prepa », ni FCFA (TR-06 écarté), ni tableau de bord (TR-07 écarté).
7. **Configuration non terminée ou sans école principale** : un seul saut vers l'accueil réel que désigne `HomeDestination` — la déclaration des classes, ou l'écran de sortie —, qui ne redirigent jamais ici.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Écran `classroom/teacher_homes/show` : `ui_page_header` « Bonjour, <prénom> », sous-titre l'établissement principal, et en action `ui_subject_badge(matière, category:)` ; puis une grille `grid gap-5` :
  - `ui_card#teacher_home_classrooms` « Mes classes » (icône de la section), sous-titre « Vos classes actives de cette année scolaire » ; liste `ul.grid.gap-4.sm:grid-cols-2.xl:grid-cols-3` d'une `_classroom_card` par classe ; pied de carte : `ui_button` « Modifier mes classes » (`secondary`, `sm`, icône `pencil-square`) vers `teacher_classrooms_path`. Le bouton est dans le pied, pas dans les actions de l'en-tête : en 375 px, l'en-tête ne passe pas à la ligne.
  - `ui_card#teacher_home_activity` « Activité de vos classes » (icône `bolt`) : `ui_empty_state` « Bientôt », sans action.
  - `ui_card#teacher_home_courses` : carte lien vers `courses_path`, « Voir les cours ».
- `_classroom_card` : `li#classroom_<public_id>`, qui contient un seul lien vers `classroom_path(public_id)` couvrant toute la carte (`rounded-ln border border-line bg-brand-soft/40 p-4`) : nom (`font-display`), niveau, puis trois lignes à icône mini — `users` « N élèves », `clipboard-document-list` « N assignations actives », `chart-bar` « Score moyen : N % » ou « Aucune session terminée » —, enfin « Ouvrir la classe » et sa flèche.
- Lecture : `Queries::Classroom::TeacherHomeQuery#call(teacher_id:, today:)` → `Row(school_name, material_name, material_category, classrooms: [ClassroomRow(public_id, name, level_name, active_students_count, active_assignments_count, average_score_percent)])`, en six requêtes quel que soit le nombre de classes.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement ; teinte `brand-soft` pour les cartes de classe, comme la carte « Ma classe » de l'élève (UDR-0010). Aucune classe ni emoji de l'ancienne application, aucun dégradé.

**Comportement**
- Lecture seule : aucun Turbo Stream. Ouvrir une classe est une navigation Turbo, sans rechargement de la fenêtre.
- Réservé au rôle enseignant : un élève ou l'équipe reçoit 403.

**États obligatoires**
- Vide : « Aucune classe déclarée », « Déclarez les classes où vous enseignez : vous les retrouverez ici. », et le bouton « Modifier mes classes » reste là.
- Classe sans élève, sans assignation, sans session : « Aucun élève », « Aucune assignation active », « Aucune session terminée ».
- Activité : « Bientôt », « Vous suivrez bientôt ici les sessions terminées par vos élèves. »
- Chargement : sans objet (page rendue d'un bloc).
- Configuration non terminée : redirection unique vers la déclaration des classes ; sans école principale : vers l'écran de sortie.

**Accessibilité**
- Le lien d'une classe n'a pas d'`aria-label` : son nom accessible est son texte (nom, niveau, chiffres, « Ouvrir la classe »), que les lecteurs d'écran lisent en entier.
- Les icônes des chiffres sont décoratives : chaque chiffre est écrit en toutes lettres.
- Cibles tactiles ≥ 48 px ; en 375 px, la page ne défile pas en largeur et la barre du bas reste visible (test système).

## 4. Conséquences

- L'accueil enseignant n'affiche aucun montant ni aucune donnée simulée ; un futur encart de rémunération exige d'abord une source de vérité du paiement (TR-06).
- « Activité de vos classes » est réservée à la V3 : la remplir ne change que le corps de sa carte.
- Le score moyen ne compte que la matière de l'enseignant ; une classe vue par l'équipe (UDR-0027) n'affiche aucun score moyen.

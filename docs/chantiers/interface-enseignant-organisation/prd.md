# PRD — Organisation des écrans enseignant : accueil, catalogue, fiche et page d'une classe

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'accueil de l'enseignant suit l'ordre classes (en bande), cours, annonces, activités ; « Activités » montre les exercices à suivre. Son catalogue ne montre que les cours de sa matière et des niveaux de ses classes. Sur téléphone, la recherche du catalogue disparaît pour tous les rôles, la fiche essentielle présente chaque classe en ligne compacte, et la page d'une classe suit l'ordre cours (en bande), exercices assignés (3 puis « Voir plus »), élèves (code de récupération dans un menu).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher | voir son accueil, le catalogue réduit à sa matière et à ses niveaux, les classes où il enseigne | voir dans « Activités » une classe où il n'enseigne pas, ou une autre matière |
| Team | catalogue complet ; page de toute classe (ordre nouveau) | — (rien ne change pour elle, hors masquage de la recherche sur téléphone) |
| Student | catalogue de son niveau (inchangé) ; recherche masquée sur téléphone | ouvrir `/teachers` (403, inchangé) |
| SchoolStaff, Parent | — | aucun écran touché ne leur est ouvert |

Règles inchangées : `allow_roles :teacher` sur l'accueil, `ReadClassroomPolicy` et `FollowAssignmentPolicy` sur la page d'une classe, `AssignExercisePolicy` sur la bascule.

## 3. Parcours utilisateur

### Chemin nominal

1. L'enseignant ouvre l'accueil : « Mes classes » en bande défilante, « Cours » (bulles de niveaux), les annonces, « Activités ».
2. « Activités » liste les exercices à suivre ; il touche une ligne et arrive sur le suivi de l'exercice dans sa classe.
3. Il ouvre « Cours » : seuls les cours de sa matière, aux niveaux (et séries) de ses classes ; sur téléphone, pas de recherche.
4. Il ouvre une fiche : sous chaque exercice, une ligne par classe — nom, échéance dessous, et à droite « Assigner » ou « Assigné ✓ » et ✕.
5. Il ouvre une classe : cours en bande, 3 exercices assignés puis « Voir plus », élèves avec un menu ⋮ « Code de récupération ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucune classe | état vide de « Mes classes » (existant) ; catalogue vide, « Déclarez vos classes » |
| Aucun exercice à suivre | état vide « Rien à suivre pour l'instant » |
| Aucune annonce lisible | pas de section annonces |
| Catalogue filtré, sur téléphone | lien « Tout voir » à côté du total |
| Bascule refusée (classe archivée, autre niveau) | toast d'erreur existant, 422 (inchangé) |
| Sans JavaScript | les bandes défilent sans points ; « Voir plus » suit le comportement existant du contrôleur `reveal` (UDR-0057 R3) ; le menu ⋮ demande JavaScript, comme tous les menus ⋮ de l'application (UDR-0042) |

## 4. Critères d'acceptation

```gherkin
# CA-1 — ordre de l'accueil
Étant donné un enseignant avec deux classes, une annonce aux enseignants et un exercice à suivre
Quand il ouvre /teachers
Alors les sections se suivent : « Mes classes », « Cours », annonces, « Activités »
Et « Mes classes » est une bande défilante d'une carte par classe

# CA-2 — annonces de l'enseignant, en lecture seule
Étant donné une annonce publiée pour les enseignants
Quand il ouvre /teachers
Alors le carrousel montre la carte, sans bouton pour la masquer
Et sans annonce lisible, il n'y a pas de section annonces

# CA-3 — exercices à suivre
Étant donné dans sa classe, dans sa matière : un exercice dû dans 3 jours que 2 élèves sur 3 n'ont pas fait,
  un exercice en retard d'1 jour, un exercice dû dans 10 jours, un exercice fait par tous, un exercice sans échéance,
  et un exercice d'une autre matière dû demain
Quand il ouvre /teachers
Alors « Activités » montre le retard d'abord, puis l'exercice dû dans 3 jours avec « 2 élèves sur 3 ne l'ont pas fait »
Et aucune des quatre autres lignes
Et chaque ligne mène au suivi de l'exercice dans sa classe

# CA-4 — exercices à suivre : 3 lignes puis « Voir plus », nombre fixe de requêtes
Étant donné quatre exercices à suivre dans deux classes
Alors 3 lignes sont visibles, la 4e est masquée et « Voir plus » la révèle
Et le nombre de requêtes de /teachers ne dépend pas du nombre de classes

# CA-5 — catalogue de l'enseignant
Étant donné un enseignant de Mathématiques avec une classe de Tle D
Et des cours publiés : Maths Tle D, Maths Tle (sans série), Maths Tle C, Maths 3ème, Physique Tle D
Quand il ouvre /courses
Alors il voit Maths Tle D et Maths Tle (sans série), et aucun autre
Et sans classe de l'année il ne voit aucun cours et l'invitation à déclarer ses classes

# CA-6 — recherche masquée sur téléphone, pour tous les rôles
Quand un élève, un enseignant ou l'équipe ouvre /courses
Alors le formulaire de recherche porte la classe qui le cache sous 640 px
Et avec un filtre actif, un lien « Tout voir », visible sur téléphone seulement, ramène à /courses

# CA-7 — fiche essentielle : ligne compacte par classe
Étant donné un exercice assigné à Tle D 2 pour le 8 octobre et non assigné à Tle D 3
Quand l'enseignant ouvre la fiche
Alors la ligne Tle D 2 dit « Tle D 2 », « Pour jeu. 8 oct. » sous le nom, « Assigné » et un bouton ✕ nommé « Retirer … de Tle D 2 »
Et la ligne Tle D 3 dit « Tle D 3 » et un bouton « Assigner »
Et le bouton « Ouvrir » de l'exercice est caché sous 640 px

# CA-8 — page d'une classe
Étant donné une classe avec deux cours, quatre exercices assignés et deux élèves
Quand l'enseignant l'ouvre
Alors les sections se suivent : cours en bande défilante, « Exercices assignés » (3 visibles, « Voir plus »), élèves
Et le code de récupération de chaque élève est une entrée d'un menu ⋮ à droite de sa ligne
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | rien : `Entities::Catalog::LevelAudience` sert telle quelle à l'enseignant ; aucune règle, aucun port |
| Infrastructure | `Queries::Catalog::TeacherAudienceQuery` (niveaux de ses classes, sa matière) ; `CourseCatalogQuery` reçoit `material_id:` ; `Queries::Classroom::TeacherFollowUpsQuery` (exercices à suivre, 3 requêtes) |
| Delivery | `TeacherHomesController` (annonces, activités) ; `CoursesController` (portée de l'enseignant) ; aucune route |
| UI | `teacher_homes/show`, `_classroom_card`, `_follow_ups` (nouveau) ; `catalog/courses/index` ; `catalog/essentials/_exercise_progress` ; `classroom/assignments/_toggle` (forme compacte) ; `classroom/classrooms/show`, `_courses`, `_assigned_exercises`, `_roster` |

## 6. Décisions rattachées

- Pas d'ADR : aucun port, aucune table, aucun contrat. Les lectures suivent l'ADR-0067 (nombre fixe de requêtes).
- [UDR-0077](../../decisions/udr/0077-organisation-des-ecrans-enseignant.md) — amende UDR-0026 / 0069 §3.1 (accueil), UDR-0013 (catalogue), UDR-0015 / 0069 §3.8 (bascules de la fiche), UDR-0027 / 0062 §3.4 (page classe).

# Recette par rôle sur le jeu standard

Cinq parcours courts, un par rôle, joués sur les comptes du [jeu de test standard](../guide/onboarding.md#le-jeu-de-test-standard-en-local). Chantier [`standard-de-test`](../chantiers/standard-de-test/memo.md), ADR standard-de-test §4 points 7 à 9.

| Rôle | Parcours | Compte de départ |
|---|---|---|
| Élève | [eleve.md](eleve.md) | `0100000166` (Tle D du Lycée Modèle Horizon) |
| Enseignant | [enseignant.md](enseignant.md) | `0500000011` (mathématiques, lycée et collège) |
| Direction | [direction.md](direction.md) | `0700000010` (Lycée Modèle Horizon) |
| DRENA | [drena.md](drena.md) | `0700003000` (équipe terrain, DRENA Abidjan 1) |
| Équipe | [equipe.md](equipe.md) | `0700001000` (admin) |

Il n'y a pas de compte DRENA : le parcours DRENA est celui d'un compte équipe sur le tableau de bord filtré par DRENA.

## Préparer

```bash
bin/jeu-standard --reset   # base locale recréée, comptes affichés (PIN 2468 partout)
bin/dev                    # puis http://localhost:3000/login
```

Ou `bin/tester-pr <PR> --demo` : même jeu. Les comptes équipe demandent aussi le code à six chiffres (TOTP) : `bin/jeu-standard` affiche le secret de développement et le code actuel ; la variable `STANDARD_TEAM_PIN` change le PIN équipe.

Le trimestre d'activité (séances, notes, lacunes, devoirs rendus et en retard) existe dans le lycée (Tle D, 1ère A1) et dans le grand établissement (Tle D 1, 1ère A1 1). Les chiffres exacts changent avec la date de chargement ; ce qui se vérifie, c'est qu'il y en a et que l'écran les montre sans erreur.

## Comment jouer un parcours

1. Écran de connexion `/login` : contact, PIN `2468`.
2. Suivre les étapes du fichier du rôle, **deux fois** : à 390 px de large (outils de développement du navigateur, ou `bin/tester-pr --telephone`), puis sur ordinateur.
3. Un résultat attendu non obtenu est un défaut du chantier : on le note dans la PR, on ne passe pas.
4. Un parcours se termine par la déconnexion.

À 390 px, partout : aucun défilement horizontal de la page, aucun texte coupé, les boutons restent atteignables au pouce.

## La règle : on rejoue seulement ce qu'on touche

La recette n'est **pas** rejouée après chaque déploiement, ni à chaque PR. Un chantier rejoue un parcours **uniquement** s'il touche ce rôle ou un écran de la table ci-dessous. Un chantier qui ne touche ni rôle ni écran écrit « aucun : ne touche ni rôle ni écran » dans la section « Prouvé sur le jeu standard » de sa PR (voir le [modèle de PR](../../.github/pull_request_template.md)).

Une vague de leçons ne rejoue aucun parcours : sa preuve est `bin/preuve-vague <dossier>` (valider.rb, rendu des leçons, captures dans `tmp/preuves/`).

## Table écran → parcours

Si ton chantier touche la route ou le contrôleur de la colonne de gauche, rejoue les parcours de la colonne de droite.

| Écran | Routes et contrôleurs principaux | Parcours |
|---|---|---|
| Connexion, code secret, second facteur | `/login`, `Identity::SessionsController`, `SecondFactorsController`, `PinResetsController` | tous (étape 1) |
| Profil et menu du compte | `Identity::Profile*Controller`, `/students/menu`, `/teachers/menu` | élève, enseignant |
| Accueil élève | `/students`, `Classroom::StudentHomesController` | élève |
| Classe de l'élève, archive | `/students/classroom`, `/students/archive`, `Classroom::StudentClassroomsController`, `StudentArchivesController` | élève |
| Choix, changement de classe, inscription élève | `/student-signup`, `/students/classroom/*`, `Classroom::Student*Controller` | élève |
| Page d'un cours (leçon), fiche, essentiels | `/courses/:slug`, `/courses/:slug/fiche`, `Catalog::CoursesController`, `EssentialsController` | élève, enseignant |
| Pages publiques niveaux, séries, matières | `/niveaux/*`, `/matieres/:slug`, `Catalog::LevelPagesController`, `SeriesPagesController`, `MaterialPagesController` | élève |
| Exercice, séance, résultat, indices | `/exercises/:id`, `/sessions/:id`, `Assessment::*Controller` | élève |
| Accueil enseignant, choix des classes enseignées | `/teachers`, `/teachers/classrooms`, `Classroom::TeacherHomesController`, `TeachingSelectionsController`, `TeachingsController` | enseignant |
| Classe vue par l'enseignant, fiche d'un élève | `/classrooms/:id`, `/classrooms/:id/students/:id`, `Classroom::ClassroomsController`, `ClassroomStudentsController` | enseignant |
| Cours d'une classe | `/classrooms/:id/courses/:slug`, `Classroom::ClassroomCoursesController`, `ClassroomEssentialsController` | enseignant |
| Devoirs : création, suivi | `/classrooms/:id/assignments/*`, `Classroom::AssignmentsController`, `AssignmentFollowUpsController` | enseignant |
| Jours de séance | `/classrooms/:id/session_days/edit`, `Classroom::SessionDaysController` | enseignant |
| Messages, annonces, aide | `Communication::*Controller` (boîte, messages, articles, aide) | élève, enseignant, direction |
| Espace direction : accueil, activité récente, recherche d'un élève | `/school-admin/*`, `SchoolAdmin::SchoolsController`, `ActivitiesController`, `StudentSearchesController` | direction |
| Direction : niveaux, classes, enseignants, personnel | `SchoolAdmin::Levels*`, `Classrooms*`, `Teachers*`, `StaffMembers*`, `Departed*` | direction |
| Accueil équipe, référentiel | `/teams`, `/teams/referential`, `Teams::HomesController`, `ReferentialsController` | équipe |
| Tableau de bord équipe, filtre DRENA, établissements de la DRENA | `/teams/dashboard`, `Teams::DashboardsController`, `Queries::School::TeamDashboardQuery` | DRENA |
| Croissance | `/teams/growth`, `Teams::GrowthController` | DRENA, équipe |
| Établissements, DRENA, plan des classes (équipe) | `Teams::SchoolsController`, `DrenasController`, `ClassroomPlansController`, `School*Controller` | équipe |
| Contenu : cours, essentiels, exercices, imports | `Teams::CoursesController`, `ImportsController`, `ExercisesController` | équipe, élève (la leçon publiée se lit) |
| Blog et annonces de l'équipe | `Teams::ArticlesController`, `Communication::ArticlesController` | équipe, élève |
| Demandes de rattachement à un établissement | `Teams::JoinRequestsController`, `School::TeacherSchoolJoinsController` | équipe, enseignant |
| Demandes de suppression de compte | `Teams::DeletionRequestsController`, `AccountDeletionsController` | équipe |
| Référentiel : niveaux, séries, matières | `Teams::LevelsController`, `SeriesController`, `MaterialsController`, `LevelSeriesController` | équipe |
| Comptes : recherche, invitations, suppression | `Teams::AccountLookupsController`, `InvitationsController`, `AccountDeletionsController` | équipe |

Un écran absent de la table : ajoute sa ligne dans la même PR que le chantier qui le crée.

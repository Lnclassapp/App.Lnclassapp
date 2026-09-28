# PRD — Barème des classes modifiable par l'équipe

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Le barème du nombre de classes générées par établissement (ADR-0030) est une constante du code ; l'import des établissements et la génération des classes manquantes (ADR-0056) le lisent. Le porteur veut que l'équipe le modifie depuis l'écran ([memo](memo.md)). Le barème passe en base, repris à l'identique au déploiement, et un écran « Barème des classes » rejoint le référentiel de l'équipe ([ADR-0058](../../decisions/adr/0058-bareme-des-classes-en-base.md), [UDR-0045](../../decisions/udr/0045-bareme-des-classes.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (tout sous-rôle) | voir le barème, modifier le nombre public et privé d'une ligne | créer une ligne hors du référentiel, modifier les classes existantes par le barème |
| Teacher, Student, School admin | — | voir l'écran, ouvrir la modale, modifier (403) |

Règle : `Policies::Classroom::ManageClassroomPlanPolicy` (équipe), vérifiée à la lecture et à la modification (ADR-0028).

## 3. Parcours utilisateur

### Chemin nominal

1. Depuis l'accueil équipe (section « Référentiel », tuile « Barème des classes ») ou l'aide de l'écran Niveaux, l'équipe ouvre « Barème des classes ».
2. Un bandeau rappelle que le barème s'applique aux **prochains** imports et générations, et que les classes existantes ne changent pas.
3. Quatre totaux : collège public, lycée public, collège privé et mixte, lycée privé et mixte.
4. Le tableau liste, par position de niveau, une ligne par niveau du premier cycle et une ligne par couple niveau × série liée du second cycle, avec le nombre public et le nombre privé ; une ligne sans nombre porte « Non défini ».
5. « Modifier » (menu ⋮ de la ligne) ouvre une modale : nombre public, nombre privé (0 à 30, 0 = aucune classe), rappel du garde-fou.
6. « Enregistrer » : toast « Barème de « Tle D » enregistré. », la ligne et les totaux sont mis à jour sans rechargement ; chaque nombre changé est tracé dans le journal d'audit.
7. Le prochain import ou la prochaine génération donne à chaque établissement le nombre enregistré.

### Accès depuis l'écran Établissements *(demande du porteur du 2026-09-28, ajoutée après la phase 3)*

8. Sur « Établissements », à droite de « Importer des établissements », un menu **« Classes »** (déclencheur libellé, chevron) propose « Générer les classes manquantes » (ouvre la confirmation existante, UDR-0043) et « Barème des classes » (mène à l'écran).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Nombre vide, négatif, décimal ou > 30 | 422 : la modale se rouvre, erreur sous le champ, valeurs gardées ; rien d'écrit |
| Même valeur ressaisie | toast de succès ; aucune écriture, aucun audit |
| Ligne inconnue (niveau ou série inconnu, couple non lié, série sur un niveau du premier cycle) | 404 |
| Référentiel vide | état vide : « Aucun niveau pour l'instant », lien vers Niveaux ; totaux à 0 |
| Niveau du second cycle sans série liée | ligne « Aucune série liée : aucune classe », sans menu, lien vers Séries |
| Ligne non définie (nouveau niveau, nouvelle série liée) | badge « Non défini », compteur en tête ; à l'import et à la génération, 0 classe et ligne comptée comme sautée |
| Non-équipe | 403 |
| Échap ou « Annuler » dans la modale | rien n'est écrit |

## 4. Critères d'acceptation

```gherkin
# BC-01 — l'écran montre le barème et les totaux
Étant donné le référentiel de développement et son barème repris
Quand l'équipe ouvre « Barème des classes »
Alors elle voit une ligne par niveau du premier cycle et une par couple niveau × série liée, avec public et privé
Et les totaux lycée public 77, lycée privé et mixte 38, collège public 28, collège privé et mixte 12
Et le bandeau dit que les classes déjà créées ne changent pas

# BC-02 — modifier une ligne
Étant donné l'écran du barème
Quand l'équipe choisit « Modifier » dans le menu de « 6ème », saisit 5 en public et 2 en privé, puis enregistre
Alors le toast « Barème de « 6ème » enregistré. » s'affiche, la ligne montre 5 et 2, le total lycée public passe à 78
Et la page n'a pas été rechargée
Et le journal d'audit porte une seule entrée « classroom_plan.changed » (public, de 4 à 5)

# BC-03 — saisie refusée
Quand l'équipe saisit 31, -1, 2.5 ou rien
Alors la modale se rouvre en 422 avec l'erreur sous le champ, et le barème n'a pas changé

# BC-04 — ligne non définie
Étant donné une série E liée à la Tle après la reprise
Alors l'écran montre « Tle E » « Non défini » et le compte des lignes à renseigner
Et un lycée importé ne reçoit aucune Tle E, et le rapport compte une série sautée

# BC-05 — garde-fou
Étant donné un établissement qui a déjà ses classes
Quand l'équipe modifie le barème
Alors ses classes ne changent pas (ni nombre, ni nom)

# BC-06 — la génération et l'import lisent le barème
Étant donné un lycée public sans classe
Quand l'équipe passe la 6ème publique à 6 puis lance la génération des classes manquantes
Alors le lycée reçoit 6 classes de 6ème (79 classes au total)
Et un établissement importé ensuite reçoit aussi le nouveau nombre

# BC-07 — reprise du barème au déploiement
Étant donné un référentiel 6ème à Tle, séries A1, A2, C, D liées à la 2nde, la 1ère et la Tle
Quand la reprise s'exécute
Alors le barème donne lycée public 89, lycée privé 44, collège public 28, collège privé 12, exactement comme l'ancien barème
Et la relancer n'écrit rien de plus
Et une série non prévue par l'ancien barème en Tle reste non définie

# BC-08 — autorisation
Étant donné un enseignant connecté
Quand il ouvre l'écran, la modale ou envoie une modification
Alors il reçoit 403, et rien n'est écrit

# BC-09 — performance
Étant donné 500 établissements sans classe
Quand la génération s'exécute
Alors elle se termine toujours en moins de 60 s, avec une seule lecture du barème

# BC-10 — référentiel
Quand l'équipe ouvre l'accueil ou l'écran Niveaux
Alors l'accueil propose la tuile « Barème des classes », et un niveau sans aucun nombre positif au barème est signalé « Hors barème »

# BC-11 — menu « Classes » de l'écran Établissements (demande du porteur du 2026-09-28)
Étant donné l'écran Établissements, au bureau comme à 390 px
Quand l'équipe ouvre le menu « Classes », à droite de « Importer des établissements »
Alors il propose « Générer les classes manquantes » et « Barème des classes »
Et « Générer les classes manquantes » ouvre la confirmation, qui lance la génération
Et « Barème des classes » mène à l'écran du barème
```

| Critère | Test |
|---|---|
| BC-01, BC-02, BC-03 | `test/system/teams/classroom_plan_test.rb`, `test/controllers/teams/classroom_plans_controller_test.rb` |
| BC-02, BC-03 (règles) | `test/domain/use_cases/classroom/update_classroom_plan_line_test.rb`, `test/domain/dtos/classroom/classroom_plan_line_input_test.rb` |
| BC-01 (lecture) | `test/domain/use_cases/classroom/show_classroom_plan_test.rb`, `test/domain/entities/classroom/default_classroom_plan_test.rb` |
| BC-04 | `test/domain/entities/classroom/default_classroom_plan_test.rb`, `test/domain/use_cases/school/import_schools_test.rb` |
| BC-05, BC-06 | `test/system/teams/classroom_plan_test.rb`, `test/domain/use_cases/school/import_schools_test.rb`, `test/jobs/classroom/generate_missing_classrooms_job_test.rb` |
| BC-07 | `test/db/classroom_plan_data_migration_test.rb` |
| BC-08 | `test/controllers/teams/classroom_plans_controller_test.rb`, `test/domain/policies/classroom/manage_classroom_plan_policy_test.rb` |
| BC-09 | `test/performance/classroom/generate_missing_classrooms_performance_test.rb` (`PERF=1`) |
| BC-10 | `test/controllers/teams/homes_controller_test.rb`, `test/infrastructure/queries/catalog/levels_query_test.rb`, `test/controllers/teams/levels_controller_test.rb` |
| BC-11 | `test/controllers/teams/classroom_generations_controller_test.rb`, `test/system/school/generate_classrooms_test.rb`, `test/system/teams/classroom_plan_test.rb` |
| Repository | `test/infrastructure/repositories/classroom/classroom_plan_repository_test.rb`, `test/db/schema_constraints_test.rb` |

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Classroom::ClassroomPlan` (entrées du barème, valeur) ; `Entities::Classroom::DefaultClassroomPlan` devient une fonction pure `rows_for(school:, lookup:, plan:)`, `sheet(plan:, lookup:)` ; port `Ports::Classroom::ClassroomPlanRepositoryPort` ; `UseCases::Classroom::ShowClassroomPlan`, `UseCases::Classroom::UpdateClassroomPlanLine` ; `Policies::Classroom::ManageClassroomPlanPolicy` ; `Dtos::Classroom::ClassroomPlanLineInput` ; action d'audit `classroom_plan.changed` |
| Infrastructure | table `classroom_plan_entries` + reprise de données ; `Orm::ClassroomPlanEntry` ; `Repositories::Classroom::ClassroomPlanRepository` ; import et génération câblés sur le repository ; `LevelsQuery` (« Hors barème ») ; `TeamHomeQuery` (total) |
| Delivery | `GET /teams/classroom-plan`, `GET /teams/classroom-plan/:level_slug(/:series_slug)/edit`, `PATCH /teams/classroom-plan/:level_slug(/:series_slug)` → `Teams::ClassroomPlansController` |
| UI | `teams/classroom_plans/{show,edit,update}` + `_line_row`, `_totals`, `_undefined` ; tuile de l'accueil ; aide et badge de l'écran Niveaux ; menu « Classes » de l'en-tête de `teams/schools/index` |

## 6. Décisions rattachées

- [ADR-0058](../../decisions/adr/0058-bareme-des-classes-en-base.md) — Le barème des classes est en base, modifiable par l'équipe, repris à l'identique (amende ADR-0030 et ADR-0056)
- [UDR-0045](../../decisions/udr/0045-bareme-des-classes.md) — Écran « Barème des classes » (amende UDR-0032, UDR-0018, UDR-0036 et, pour le menu « Classes », UDR-0043)

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Génération, 500 établissements (mix du plan) | 3,0 s (journal `generer-classes`) | < 60 s, sans régression notable | voir [journal](journal.md) |

# Journal — Import des établissements : second cycle pour tous

## Ce qu'on a appris sur la codebase

**Root cause**

- **Chaîne d'appels** : `Teams::ImportsController` → `School::ImportSchoolsJob` → `UseCases::School::ImportSchools#validate_root` → `build_school` → `cycle_of` → `Entities::School::School.cycle_for(name:)` ; puis `#write` / `plan_for` → `Entities::Classroom::DefaultClassroomPlan.rows_for`.
- **Cause (fichiers)** : `app/domain/use_cases/school/import_schools.rb:104` (`cycle_of` : cycle du fichier, sinon deviné du nom) et `app/domain/entities/school/school.rb:28` (`cycle_for` : « collège » dans le nom → `first`). `app/domain/entities/classroom/default_classroom_plan.rb:38` écarte alors tout le second cycle.
- **En une phrase sans les mots du symptôme** : le cycle d'un établissement importé est déduit de son nom (ou du fichier) au lieu d'être le même pour tous, et la génération des classes obéit à ce cycle.
- **Trou de test** : `import_schools_test.rb:121` fige la règle « collège → first » comme comportement voulu ; aucun test n'exprime « tout établissement importé a le second cycle ». Le test de reproduction se place donc en domaine, dans ce fichier.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Cas d'usage d'archivage d'une classe | Spec manquante, pas un bug | à ouvrir (`/feature`) |

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
| 2026-10-09 | Colonne `cycle` du fichier ignorée (pas d'erreur) ; `cycle_for` supprimée | « tous les établissements » : aucune exception par fichier | ADR-0087 |
| 2026-10-09 | `GrantSecondCycle` exemptée de policy (réparation sans acteur, console) | Pas d'acteur en rake ; bornée au second cycle | ADR-0087 §6 |

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Cas d'usage d'archivage d'une classe | Spec manquante, pas un bug | `archivage-classes` |
| Lancer `bin/rails schools:grant_second_cycle` sur Develop (aucun établissement en Staging ni en production, porteur 2026-10-10) | Aucun accès shell au conteneur depuis la session | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-10 (sur `Develop`) |
| **PR** | aucune : commit direct sur `Develop`, branche de la session |
| **ADR produits** | ADR-0087 |
| **UDR produits** | — |

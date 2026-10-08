# Plan — « Lnclass Teacher » (app Android des enseignants)

> PRD : [prd-teacher.md](prd-teacher.md) · ADR-0085 · UDR-0081. Même découpage que l'app élèves ([plan.md](plan.md)) : un socle, puis cinq lots en parallèle.

```
Lot T0 (socle) ──┬── Lot TA  en-tête et panneau de l'enseignant (site)
                 ├── Lot TB  pages servies à la coque enseignants
                 ├── Lot TC  refus croisés à la connexion
                 ├── Lot TD  ouverture comptée, pilotage
                 └── Lot TE  module Android teacher et socle partagé
```

Le Lot T0 gèle `LNCLASS_APPS` (`:android_teacher`), la route `teacher_menu`, la forme de `config.x.android` et les clés de locales.

---

## Lot T0 — Socle

- **Fichiers** :
  - `app/controllers/application_controller.rb` : jeton `LnclassTeacherAndroid` → `:android_teacher` ;
  - `config/routes/classroom.rb` : `get "teachers/menu"` → `classroom/teacher_menus#show`, `as: :teacher_menu` ;
  - `config/application.rb` : `config.x.android = { apps: { student: { package_name:, store_url: }, teacher: { package_name:, store_url: } }, cert_fingerprints: }`, lus dans `ANDROID_PACKAGE_NAME`, `ANDROID_TEACHER_PACKAGE_NAME`, `ANDROID_STUDENT_STORE_URL`, `ANDROID_TEACHER_STORE_URL`, `ANDROID_CERT_FINGERPRINTS` ;
  - `app/controllers/identity/asset_links_controller.rb` : adaptation minimale à la nouvelle forme, une déclaration par app ;
  - `docs/guide/configuration.md` : les nouvelles variables ;
  - les locales de l'UDR-0081 : panneau de l'enseignant (`invite`), messages de refus des §3.4, `app_openers_android_teachers`.
- **Tests** : `test/controllers/application_controller_test.rb` (jeton enseignants), `test/routing/app_android_routes_test.rb` (`teacher_menu`), `test/controllers/identity/asset_links_controller_test.rb` (deux déclarations).
- **Done quand** : la suite du périmètre est verte et les contrats sont gelés.

## Lot TA — En-tête et panneau de l'enseignant (site)

- **Fichiers** : `app/views/shared/navigation/_header.html.erb` (branche élève **ou** enseignant), `_account_panel.html.erb` (entrées par rôle), `app/controllers/classroom/teacher_menus_controller.rb` et sa vue (nouveaux).
- **Tests** : `test/controllers/classroom/teacher_menus_controller_test.rb`, `test/integration/identity/teacher_header_test.rb`, et le test système du panneau étendu à l'enseignant ; les tests existants qui décrivaient l'ancien en-tête de l'enseignant sont adaptés.
- **Done quand** : CA-T6 ; captures 390 px et ordinateur, en clair et en sombre.

## Lot TB — Pages servies à la coque enseignants

- **Fichiers** : `app/views/layouts/shell.html.erb` (pont pour l'enseignant, `teacher_menu_path`), `public/android/v1/path-configuration.json` (règle de l'ADR-0085 §4.3).
- **Tests** : `test/integration/app_android_shell_test.rb` (CA-T1), `test/integration/app_android_path_configuration_test.rb` (CA-T2).

## Lot TC — Refus croisés à la connexion

- **Fichiers** : `app/domain/dtos/identity/credentials_input.rb` (`android_teacher`), `app/domain/use_cases/identity/authenticate.rb` (`WRONG_APP_FOR`, l'app proposée dans les erreurs), `app/controllers/identity/sessions_controller.rb`, `app/views/identity/sessions/new.html.erb` (les quatre messages de l'UDR-0081 §3.4, liens Play Store ou site).
- **Tests** : `test/domain/use_cases/identity/authenticate_test.rb`, `test/controllers/identity/sessions_controller_test.rb` (CA-T3, CA-T4).

## Lot TD — Ouverture comptée, pilotage

- **Fichiers** : `app/controllers/homepage_controller.rb` (toute coque reconnue), `app/infrastructure/queries/school/team_dashboard_query.rb` (`android_teachers`), `app/views/teams/dashboards/_key_figures.html.erb`.
- **Tests** : `test/controllers/homepage_controller_test.rb`, `test/infrastructure/queries/school/team_dashboard_query_test.rb`, `test/controllers/teams/dashboards_controller_test.rb` (CA-T5 ; nombre de requêtes inchangé).

## Lot TE — Module Android `teacher` et socle partagé

- **Fichiers** :
  - `android/shell/**` : bibliothèque, code commun extrait de `android/student` ;
  - `android/student/**` : allégé, sans changement de comportement ;
  - `android/teacher/**` : nouveau, avec les icônes validées le 2026-10-08 ;
  - `android/settings.gradle.kts` ;
  - `bin/android-build` : `[student|teacher] <variante>` ;
  - `test/guards/android_project_test.rb` : couvre les deux modules.
- **Tests** : le garde (CA-T8 côté dépôt), puis les compilations `bin/android-build teacher recette` et `bin/android-build recette`.
- **Done quand** : les APK `lnclass-teacher-develop.apk` et `lnclass-teacher-recette.apk` sont signées avec la clé de test et envoyées au porteur.

## Après les lots

- Variables Railway `ANDROID_TEACHER_PACKAGE_NAME` sur Develop (`com.lnclass.teacher.develop`) et Staging (`com.lnclass.teacher.recette`).
- `bin/ci` complet ; PR ; captures.

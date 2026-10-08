# Plan d'exécution — App Android « Lnclass » pour les élèves

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [PRD](prd.md) · [ADR-0084](../../decisions/adr/0084-coque-android-eleves-hotwire-native.md) · [UDR-0080](../../decisions/udr/0080-en-tete-eleve-panneau-du-compte-et-barres-de-l-app-android.md) · ADR-0070 (amendé le 2026-10-08).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  migration users.android_opened_at · port mark_app_opened(channel:) gelé + adaptateur
  ApplicationController#lnclass_app · routes (student_menu, assetlinks) · locales · placement ui_modal :drawer
  dépendance @hotwired/hotwire-native-bridge · durées des tests système
  ↓
  ├─► Lot A « en-tête élève et panneau du compte (site) »      CA-7, CA-8      ┐
  ├─► Lot B « pages servies à la coque »                      CA-1, CA-2, CA-9 │
  ├─► Lot C « enseignant refusé dans l'app »                  CA-3, CA-4      ├─ en parallèle
  ├─► Lot D « ouverture de l'app comptée, pilotage »          CA-5, CA-6      │
  └─► Lot E « la coque Android »                              CA-10           ┘
```

Le Lot 0 gèle `mark_app_opened(user_id:, at:, channel: :pwa)`, l'aide `lnclass_app` / `lnclass_app?` et les noms de routes. Un lot qui doit changer l'un d'eux **s'arrête** et le Lot 0 rouvre.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrat) + fichiers partagés
- **Fichiers**     : `db/migrate/<horodatage>_add_android_opened_at_to_users.rb` · `db/schema.rb`
                     `app/domain/ports/identity/user_repository_port.rb` *(`mark_app_opened(user_id:, at:, channel: :pwa)`)*
                     `app/infrastructure/repositories/identity/user_repository.rb` *(canal → colonne ; `anonymize` efface aussi `android_opened_at`)*
                     `app/controllers/application_controller.rb` *(`lnclass_app`, `lnclass_app?`, ADR-0084 §4.1)*
                     `config/routes.rb` · `config/routes/classroom.rb` *(`get "students/menu"` → `classroom/student_menus#show`, `as: :student_menu`)* · `config/routes/identity.rb` *(`get ".well-known/assetlinks"` → `identity/asset_links#show`, format json)*
                     `config/application.rb` *(`config.x.android` : identifiant et empreintes lus dans `ANDROID_CERT_FINGERPRINTS`)*
                     `config/locales/shared/navigation.fr.yml` *(clés `account_panel`)* · `config/locales/identity/sessions.fr.yml` *(clés `wrong_app`)* · `config/locales/teams/dashboards.fr.yml` *(clé `app_openers_android`)*
                     `app/helpers/components_helper.rb` · `app/assets/stylesheets/application.tailwind.css` *(placement `:drawer`, UDR-0080 §3.2)*
                     `package.json` · `yarn.lock` *(`@hotwired/hotwire-native-bridge`)*
                     `script/ci/test_timings.yml`
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/repositories/identity/user_repository_test.rb` (canal `:android` date `android_opened_at`, `:pwa` date `app_opened_at`, anonymisation efface les deux) · `test/controllers/application_controller_test.rb` (`lnclass_app` : User-Agent de la coque → `:android_student` ; « Hotwire Native » sans jeton → `nil` ; navigateur → `nil`) · `test/routing/app_android_routes_test.rb` · `test/helpers/components_helper_test.rb` (`ui_modal placement: :drawer`)
- **Done quand**   : `bin/ci` vert ; les routes répondent (même en 404 tant que leurs contrôleurs n'existent pas) ; le contrat du port est gelé et implémenté ; RecordAppOpen passe `channel: :pwa` sans autre changement

---

## Lot A — En-tête de l'élève et panneau du compte (site)

- **Couche**       : delivery + ui
- **Fichiers**     : `app/views/shared/navigation/_header.html.erb` *(branche élève, UDR-0080 §3.1)*
                     `app/views/shared/navigation/_account_panel.html.erb` *(nouveau, §3.2)*
                     `app/controllers/classroom/student_menus_controller.rb` *(nouveau, élève seulement)*
                     `app/views/classroom/student_menus/show.html.erb` *(nouveau)*
                     `app/views/classroom/student_homes/show.html.erb` *(retrait de l'entrée d'aide du menu et du second rendu de la carte d'aide)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/student_menus_controller_test.rb` (CA-8 : élève → 200 et contenu ; enseignant → refus) · `test/integration/identity/student_header_test.rb` (CA-7 : élève sans logo, avatar à gauche, aide et interrupteur ; enseignant inchangé) · `test/system/identity/account_panel_test.rb` (CA-7 et CA-8 à 390 px : pas de défilement horizontal, panneau ouvert par l'avatar, Échap le ferme)
- **Done quand**   : sur le site, un élève à 390 px voit son avatar à gauche, « Besoin d'aide ? » et l'interrupteur à droite ; toucher l'avatar ouvre le panneau ; un enseignant ne voit aucun changement. Captures 390 px et ordinateur, clair et sombre, envoyées au porteur

---

## Lot B — Pages servies à la coque

- **Couche**       : delivery + ui
- **Fichiers**     : `app/views/layouts/shell.html.erb` *(sans en-tête ni barre basse si `lnclass_app?` ; élément du pont pour l'élève)*
                     `app/views/shared/navigation/_install_banner.html.erb` *(rien dans la coque)*
                     `app/javascript/controllers/bridge/account_controller.js` *(composant de pont `account`)*
                     `public/android/v1/path-configuration.json`
                     `app/controllers/identity/asset_links_controller.rb` *(nouveau, JSON depuis `config.x.android`)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/app_android_shell_test.rb` (CA-1) · `test/integration/app_android_path_configuration_test.rb` (CA-2 : JSON valide, règles des séances, du panneau et de l'aide) · `test/controllers/identity/asset_links_controller_test.rb` (CA-9)
- **Done quand**   : une page élève servie avec le User-Agent de la coque n'a ni en-tête ni barre basse, porte l'élément du pont et jamais la pop-up d'installation ; la configuration des chemins et `assetlinks.json` répondent en JSON

---

## Lot C — Enseignant refusé dans l'app

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/dtos/identity/credentials_input.rb` *(`client`, `"web"` par défaut)*
                     `app/domain/use_cases/identity/authenticate.rb` *(`:wrong_app` après PIN correct, aucune session)*
                     `app/controllers/identity/sessions_controller.rb` *(passe `client` depuis `lnclass_app`, rend le refus en 422)*
                     `app/views/identity/sessions/new.html.erb` *(message de refus, UDR-0080 §3.4)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/authenticate_test.rb` (CA-3, CA-4 : enseignant, direction et équipe refusés avec PIN correct, aucune session ; PIN faux identique à celui d'un élève ; élève accepté) · `test/controllers/identity/sessions_controller_test.rb` (CA-3 avec le User-Agent de la coque : 422, message, aucun cookie de session)
- **Done quand**   : avec le User-Agent de la coque, un enseignant au PIN correct lit « Cette app est réservée aux élèves » et n'a pas de session ; un élève entre ; sur le site, rien ne change

---

## Lot D — Ouverture de l'app comptée, pilotage

- **Couche**       : domaine + delivery + infrastructure (query) + ui
- **Fichiers**     : `app/domain/use_cases/identity/record_app_open.rb` *(paramètre `channel:`)*
                     `app/controllers/homepage_controller.rb` *(`source=android` venu de la coque → canal `:android`)*
                     `app/infrastructure/queries/school/team_dashboard_query.rb` *(`app_openers` gagne `android_students`)*
                     `app/views/teams/dashboards/_key_figures.html.erb` *(ligne « dont app Android »)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/record_app_open_test.rb` · `test/controllers/homepage_controller_test.rb` (CA-5 : coque → `android_opened_at` ; navigateur avec `source=android` → rien) · `test/infrastructure/queries/school/team_dashboard_query_test.rb` et `test/controllers/teams/dashboards_controller_test.rb` (CA-6 ; nombre de requêtes inchangé, 17 / 20)
- **Done quand**   : un élève qui ouvre l'app est daté ; l'équipe lit « dont app Android : N élèves » dans la tuile existante

---

## Lot E — La coque Android

- **Couche**       : android
- **Fichiers**     : `android/settings.gradle.kts` · `android/build.gradle.kts` · `android/gradle.properties` · `android/gradle/wrapper/*` · `android/gradlew`
                     `android/student/build.gradle.kts` *(minSdk 28, variantes `recette` et `production`, User-Agent `LnclassStudentAndroid/<version>`)*
                     `android/student/src/main/AndroidManifest.xml` *(liens `/c/` et `/join`, `autoVerify`)*
                     `android/student/src/main/java/com/lnclass/student/*.kt` *(application, activité principale avec trois onglets, composant de pont `account`, barre du haut)*
                     `android/student/src/main/assets/json/path-configuration.json` *(copie embarquée de celle du Lot B)*
                     `android/student/src/main/res/**` *(icônes validées le 2026-10-08, couleurs, chaînes, icônes d'onglets)*
                     `android/.gitignore` *(`*.jks`, `*.keystore`, `local.properties`, `build/`)*
                     `bin/android-build`
- **Dépend de**    : Lot 0 (noms des routes) ; la copie embarquée de la configuration des chemins est réalignée sur celle du Lot B au merge
- **Test associé** : `test/guards/android_project_test.rb` (CA-10 côté dépôt : `minSdk 28`, identifiants, adresses des variantes, jeton du User-Agent, onglets, aucun fichier de clé, configuration embarquée identique à celle de `public/`) · compilation `bin/android-build recette` (APK produit, `minSdkVersion` 28 lu par `aapt`)
- **Done quand**   : `bin/android-build recette` produit `lnclass-recette.apk`, envoyé au porteur, qui l'installe sur son téléphone : connexion, accueil, onglets, exercice en plein écran, panneau du compte

---

## Couverture des critères d'acceptation

| Critère (PRD §4) | Lot |
|---|---|
| CA-1 Le site reconnaît l'app | B (aide `lnclass_app` : Lot 0) |
| CA-2 Configuration des chemins | B |
| CA-3 Enseignant refusé | C |
| CA-4 Élève accepté | C |
| CA-5 Ouverture comptée | D |
| CA-6 Pilotage | D |
| CA-7 En-tête élève | A |
| CA-8 Panneau du compte | A |
| CA-9 Liens ouverts dans l'app | B |
| CA-10 La coque | E |

Aucun critère orphelin.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes*.rb`, `config/application.rb`, `config/locales/**` | Lot 0 |
| `app/controllers/application_controller.rb` | Lot 0 |
| `app/domain/ports/identity/user_repository_port.rb` · `app/infrastructure/repositories/identity/user_repository.rb` | Lot 0 |
| `app/helpers/components_helper.rb` · `application.tailwind.css` | Lot 0 |
| `package.json` · `yarn.lock` · `script/ci/test_timings.yml` · `db/**` | Lot 0 |
| `_header`, `_account_panel`, `student_menus/*`, `student_homes/show` | Lot A |
| `layouts/shell`, `_install_banner`, `bridge/account_controller.js`, `public/android/**`, `asset_links_controller` | Lot B |
| `credentials_input`, `authenticate`, `sessions_controller`, `sessions/new` | Lot C |
| `record_app_open`, `homepage_controller`, `team_dashboard_query`, `_key_figures` | Lot D |
| `android/**`, `bin/android-build` | Lot E |

Une nouvelle durée de test système (Lots A, B) s'inscrit dans `script/ci/test_timings.yml` **au merge**, par l'intégrateur (Lot 0 en est propriétaire). Budget du chantier : 15 s.

## Dispatch

```
Vague 1 : Lot 0                                → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D ‖ Lot E → 5 agents, worktrees isolés
```

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.**
>
> Ici, c'est une personne, sur un vrai téléphone Android 9 ou plus, avec l'APK de recette. Elle refait le parcours :
> - installation, connexion d'un élève, accueil, Cours, Ma classe ;
> - un exercice en plein écran, puis son résultat ;
> - le panneau du compte et le thème ;
> - « Besoin d'aide ? ».
>
> Chemin d'erreur : un compte enseignant refusé avec son PIN correct, et le mode avion pendant la navigation.
>
> Puis le test fermé du Play Store : au moins 12 élèves pendant 14 jours d'affilée (compte personnel, ADR-0070 amendé).

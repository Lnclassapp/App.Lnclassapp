# Plan d'exécution — Un élève change de classe ou d'établissement

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Contexte borné porteur de la règle : `classroom` (le profil touche `identity`). **Aucune migration.** Un commit par lot, documentation du lot comprise.
> **Ne démarre qu'après** les réponses du porteur aux questions 1 à 9 du [memo](memo.md#ce-que-le-grill-a-révélé) et l'acceptation de l'ADR-0095 et des UDR-0101 à 0103.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : use case ChangeClassroom, action d'audit, routes, local du partial de la cascade
  ↓
  ├─► Lot A  « Changer de classe » : cascade, confirmation, envoi (UDR-0102 §3.1, §3.2)  ┐
  ├─► Lot B  Profil : la ligne Classe ouvre « Changer de classe » (UDR-0101)              │
  ├─► Lot C  Lien /c/<jeton> d'un élève déjà inscrit → confirmation (UDR-0102 §3.3)        ├─ en parallèle
  └─► Lot D  Historique : période de chaque classe (UDR-0103)                              ┘
```

Vagues de dispatch :

```
Vague 1 : Lot 0              → 1 agent, séquentiel
Vague 2 : Lot A ‖ B ‖ C ‖ D  → 4 agents, worktrees isolés (feature/changement-etablissement-eleve-lot-a … -lot-d)
```

Si le porteur répond « non » à la question 6, le Lot C disparaît. Si la question 5 est « non », le Lot A filtre la cascade sur les autres établissements (UDR-0102 à amender).

---

## Lot 0 — Socle

- **Couche**       : domaine + delivery (routes) + ui (local partagé)
- **Fichiers**     : `app/domain/use_cases/classroom/change_classroom.rb`
                     `app/domain/entities/identity/audit_action.rb`
                     `config/routes/classroom.rb`
                     `app/views/classroom/student_registrations/_class_picker.html.erb` *(local `current_classroom_public_id:`, défaut `nil`)*
                     `app/controllers/school/level_classrooms_controller.rb` *(lit `current` dans l'URL du cadre, UDR-0102 §4)*
                     `app/views/school/level_classrooms/index.html.erb` *(case désactivée « Ta classe » quand `current` est passé)*
                     `config/locales/classroom/student_classroom_choices.fr.yml` *(clés d'erreur `same_classroom`, `no_active_classroom` ; badge « Ta classe »)*
- **Dépend de**    : —
- **Test associé** : `test/domain/use_cases/classroom/change_classroom_test.rb`
                     `test/domain/entities/identity/audit_action_test.rb`
                     `test/infrastructure/repositories/classroom/membership_repository_test.rb` *(retour dans une ancienne classe : même ligne rouverte)*
                     `test/routing/v1_routes_test.rb`
                     `test/controllers/school/level_classrooms_controller_test.rb`
- **Done quand**   : `ChangeClassroom` déplace un élève à classe active (ancienne adhésion `left_at` sans `removed_at`, nouvelle principale, trace écrite) et refuse : non-élève, sans classe active, même classe, classe complète, archivée, retiré sans lien ; un échec d'écriture laisse l'ancienne adhésion ouverte ; les trois routes sont définies ; inscription et « Choisis ta classe » rendent la cascade à l'identique

Contrats gelés : `ChangeClassroom#call(actor:, dto: Dtos::Classroom::StudentRegistrationInput)` → `success(Classroom)` | `:forbidden` | `:invalid` | `:not_found` | `:conflict` ; routes `new_student_classroom_change_path`, `confirm_student_classroom_change_path` (paramètres de la cascade sous `student_classroom_change`, ou `link_token`), `student_classroom_change_path` (POST) ; local `_class_picker` `current_classroom_public_id:`.

---

## Lot A — « Changer de classe » : cascade, confirmation, envoi

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/classroom_change_preview_query.rb`
                     `app/controllers/classroom/student_classroom_changes_controller.rb`
                     `app/views/classroom/student_classroom_changes/new.html.erb`
                     `app/views/classroom/student_classroom_changes/confirm.html.erb`
                     `config/locales/classroom/student_classroom_changes.fr.yml`
                     `test/system/classroom/classroom_change_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/student_classroom_changes_controller_test.rb`
                     `test/infrastructure/queries/classroom/classroom_change_preview_query_test.rb`
                     `test/system/classroom/classroom_change_test.rb`
- **Done quand**   : depuis `/students/classroom/change`, un élève à classe active choisit une classe d'un autre établissement, voit « Tu quittes / Tu rejoins », confirme et arrive sur l'accueil de la nouvelle classe ; « Annuler » n'écrit rien ; refus (complète, retiré, même classe) affichés en tête ; élève sans classe redirigé ; autres rôles refusés ; parcours sans JS vert ; captures 390 px et 1 280 px envoyées au porteur

---

## Lot B — Profil : la ligne « Classe » ouvre « Changer de classe »

- **Couche**       : ui
- **Fichiers**     : `app/views/identity/profiles/_student_row.html.erb` *(local `frame:`, défaut `"modal"`)*
                     `app/views/identity/profiles/_student_information.html.erb`
                     `config/locales/identity/profiles.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/identity/profiles_controller_test.rb`
                     `test/system/identity/profile_test.rb`
- **Done quand**   : la ligne « Classe » du profil d'un élève à classe active porte « Changer » et un chevron, mène en pleine page à « Changer de classe », avec le nom accessible « Changer classe, … » ; Photo, Nom, Numéro ouvrent toujours leur fenêtre ; sans classe, la ligne est absente ; captures 390 px et 1 280 px

---

## Lot C — Lien d'une autre classe ouvert par un élève déjà inscrit

- **Couche**       : delivery
- **Fichiers**     : `app/controllers/classroom/joins_controller.rb`
                     `test/system/classroom/join_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/joins_controller_test.rb`
                     `test/system/classroom/join_test.rb`
- **Done quand**   : un élève à classe active qui ouvre `/c/<jeton>` d'une autre classe est redirigé (303) vers `confirm_student_classroom_change_path(link_token:)` ; le lien de sa propre classe mène à l'accueil ; lien mort et classe archivée inchangés ; visiteur et élève sans classe inchangés

---

## Lot D — Historique : période de chaque classe

- **Couche**       : infrastructure (query) + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/student_archive_query.rb`
                     `app/views/classroom/student_archives/show.html.erb`
                     `config/locales/classroom/student_archives.fr.yml`
- **Dépend de**    : Lot 0 *(aucun contrat consommé ; dépend seulement de la décision)*
- **Test associé** : `test/infrastructure/queries/classroom/student_archive_query_test.rb`
                     `test/system/classroom/student_archive_test.rb`
- **Done quand**   : « Mes classes » montre « depuis le … » et le badge « Actuelle » pour la classe en cours, « du … au … » pour une classe quittée, l'année scolaire dans la ligne de détail ; toujours 3 requêtes ; captures 390 px et 1 280 px

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/classroom.rb` | Lot 0 |
| `app/domain/use_cases/classroom/change_classroom.rb` | Lot 0 |
| `app/domain/entities/identity/audit_action.rb` | Lot 0 |
| `app/views/classroom/student_registrations/_class_picker.html.erb` | Lot 0 |
| `app/controllers/school/level_classrooms_controller.rb`, `app/views/school/level_classrooms/index.html.erb` | Lot 0 |
| `config/locales/classroom/student_classroom_choices.fr.yml` | Lot 0 |
| `app/controllers/classroom/student_classroom_changes_controller.rb`, ses vues, sa locale, sa query | Lot A |
| `test/system/classroom/classroom_change_test.rb` | Lot A |
| `app/views/identity/profiles/_student_row.html.erb`, `_student_information.html.erb`, `config/locales/identity/profiles.fr.yml` | Lot B |
| `app/controllers/classroom/joins_controller.rb`, `test/system/classroom/join_test.rb` | Lot C |
| `app/infrastructure/queries/classroom/student_archive_query.rb`, `student_archives/show`, sa locale | Lot D |

Aucun fichier listé par deux lots parallèles.

## Portes de sortie

- [ ] Réponses du porteur aux questions 1 à 9 consignées dans le memo ; ADR-0095 et UDR-0101 à 0103 acceptées
- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : parcours cascade, parcours lien, refus, sans JS
- [ ] `bin/ci-quiet` vert, écrit dans la PR (CI GitHub coupée, ADR-0069)
- [ ] Revue `security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer` sur le diff final (use case et routes touchés)
- [ ] Captures 390 px et ordinateur de chaque écran envoyées au porteur
- [ ] Index ADR/UDR régénérés par `script/docs/build_index` et ligne du chantier dans `docs/chantiers/README.md`, au commit de clôture
- [ ] `journal.md` complété

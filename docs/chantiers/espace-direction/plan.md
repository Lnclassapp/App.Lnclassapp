# Plan d'exécution — Espace direction, ce qui reste de la V2

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [`prd.md`](prd.md) (ED-01 à ED-72), [ADR-0092](../../decisions/adr/0092-fonctions-de-direction-droits-par-rang-et-changement-de-classe.md), [UDR-0092](../../decisions/udr/0092-fonction-de-direction-et-gestes-par-rang.md), [UDR-0093](../../decisions/udr/0093-changer-un-eleve-de-classe.md), [UDR-0094](../../decisions/udr/0094-chercher-un-eleve-dans-l-etablissement.md).

## Préalables au Lot 0

- [x] Q1 à Q9 du [memo](memo.md) tranchées par le porteur (2026-10-16) ; PRD, ADR et UDR alignés au Lot 0.
- [x] ADR-0092, UDR-0092 et UDR-0094 `Accepté` ; UDR-0093 `Abandonnée` (Q5).
- [x] Branche de code : `feature/espace-direction-v2`, partie de `feature/multi-etablissements-enseignant` (PR #250, policies de la direction sur les enseignants communes). L'ancienne `feature/espace-direction` reste telle quelle.
- [x] Comptes de direction sans fonction en production : **aucun** (DIR-4, Lnclass n'est pas lancé).
- [ ] Mesures « avant » du PRD §7 : non relevées (pas de base de mesure dans la session ; voir journal).

## Amendement du Lot 0 (2026-10-16, réponses du porteur)

- **Lot D retiré** (Q5) : la direction ne change pas un élève de classe. Aucune voie `transfer`, aucun `MoveStudent`, aucune modale.
- **Lot B réduit** (DIR-4) : « Préciser ma fonction » sort ; il reste « Changer la fonction » par l'équipe et la restauration d'un ancien chef (ED-25). `school_admin/staff_positions` n'existe pas.
- **La fonction est obligatoire** : `school_staffs.position` `NOT NULL` ; une invitation de direction porte sa fonction.
- **Exécution** : un seul agent, les lots s'enchaînent dans l'ordre 0, A, B, C, E, F (un commit chacun, documentation comprise) ; le tableau de collision reste valable pour les lots restants.

## Graphe

```
Lot F « Recette du profil côté direction » (tests seuls, sans dépendance) ──────────────┐
                                                                                         │
Lot 0 — SOCLE (séquentiel)                                                               │
  migration (position, chef unique, transfer) · StaffPosition · Staff · Actor            │
  ports et adaptateurs · journal · requête du bloc « Direction »                         │
  drapeaux d'affichage par policy (iso-comportement) · libellé de fonction               │
  routes · locales · fabriques                                                           │
  ↓                                                                                      │
  ├─► Lot A « Choisir sa fonction en arrivant »         ┐                                │
  ├─► Lot B « Préciser ou changer une fonction »        │                                │
  ├─► Lot C « Droits par fonction »                     ├─ en parallèle, fichiers disjoints
  └─► Lot E « Trouver un élève dans l'établissement »   ┘ ◄──────────────────────────────┘
```

**Règles gelées.**

1. Les lots A à E **implémentent** les contrats du Lot 0 ; aucun ne change un port, une entité, une migration, une route, une locale ou une fabrique. Un lot qui en a besoin s'arrête : le Lot 0 rouvre.
2. **Le Lot 0 prépare les vues des gestes** (drapeaux calculés par la policy, note du rang vie scolaire sous condition) **sans changer le comportement** : tant que le Lot C n'a pas changé les policies, aucun drapeau ne change et la note ne s'affiche jamais. Le Lot C ne touche que les policies et leurs tests.
3. Aucun lot vertical n'ajoute de fabrique dans `test/support/factories/` ; ses aides vivent dans son fichier de test.
4. Aucun lot vertical n'écrit dans `docs/` : il remonte ses notes au porteur du chantier, qui tient `journal.md` (un commit par lot, documentation comprise, selon `CLAUDE.md`).
5. Leçon d'`espace-direction` (2026-09-28) et de `gestion-etablissement-direction` : chaque méthode de port ajoutée a son adaptateur **dans le Lot 0** ; avant de toucher un `Data.define` (`Staff`, `Actor`), chercher tous ses appelants (`grep -rn 'Staff.new\|Actor.new' app test`).

---

## Lot 0 — Socle

- **Couche**       : infrastructure (migrations, `Orm::`, adaptateurs, requête) + domaine (entités, ports, journal) + delivery (drapeaux, routes) + ui (libellé, notes conditionnelles)
- **Fichiers**     : db/migrate/<horodatage>_add_position_to_school_staffs.rb
                     db/migrate/<horodatage>_allow_transfer_student_arrival.rb
                     db/schema.rb
                     app/infrastructure/orm/school_staff.rb
                     app/domain/entities/school/staff_position.rb (nouveau)
                     app/domain/entities/school/staff.rb
                     app/domain/entities/identity/actor.rb
                     app/domain/entities/identity/audit_action.rb
                     app/domain/entities/classroom/student_arrival_channel.rb
                     app/domain/ports/school/staff_repository_port.rb
                     app/infrastructure/repositories/school/staff_repository.rb
                     app/infrastructure/repositories/identity/user_repository.rb
                     app/infrastructure/queries/school/school_staff_query.rb
                     app/controllers/school_admin/schools_controller.rb
                     app/controllers/school_admin/levels_controller.rb
                     app/controllers/school_admin/teachers_controller.rb
                     app/controllers/school_admin/departed_teachers_controller.rb
                     app/controllers/concerns/teams/school_staff_block.rb
                     app/views/school_admin/schools/show.html.erb
                     app/views/school_admin/levels/show.html.erb
                     app/views/school_admin/teachers/index.html.erb
                     app/views/school_admin/departed_teachers/index.html.erb
                     app/views/shared/_school_staff.html.erb (libellé de fonction, UDR-0092 §3.2)
                     app/views/teams/schools/show.html.erb (local `position_url` du bloc « Direction »)
                     app/views/classroom/classrooms/_roster.html.erb (voie `transfer`)
                     config/routes/school_admin.rb
                     config/routes/teams.rb
                     config/locales/shared/staff_positions.fr.yml (nouveau)
                     config/locales/shared/school_staff.fr.yml
                     config/locales/school_admin/classrooms.fr.yml · levels.fr.yml · schools.fr.yml · teachers.fr.yml · departed_teachers.fr.yml · staff_positions.fr.yml (nouveau) · student_moves.fr.yml (nouveau) · student_searches.fr.yml (nouveau)
                     config/locales/identity/school_staff_registrations.fr.yml
                     config/locales/teams/staff_invitations.fr.yml · school_staff.fr.yml
                     config/locales/classroom/classrooms.fr.yml (`via.transfer`)
                     test/support/factories/identity.rb (`create_school_admin(position:)`)
- **Dépend de**    : — (préalables cochés)
- **Test associé** : test/db/schema_constraints_test.rb (ED-01, ED-02 : valeurs de `position`, un `head` actif, `transfer` accepté)
                     test/domain/entities/school/staff_position_test.rb (rang, ED-03)
                     test/domain/entities/school/staff_test.rb (`position`)
                     test/domain/entities/identity/actor_test.rb · audit_action_test.rb
                     test/infrastructure/repositories/school/staff_repository_test.rb (`head_taken?`, `set_position`, `attach*` avec `position`, conflit sur l'index, `restore` en conflit)
                     test/infrastructure/repositories/identity/user_repository_test.rb (ED-05 : `staff_position` de l'acteur)
                     test/infrastructure/queries/school/school_staff_query_test.rb (`position` dans la ligne)
                     test/controllers/school_admin/schools_controller_test.rb (ED-04, côté direction)
                     test/controllers/teams/schools_controller_test.rb (ED-04, côté équipe)
                     toute la suite `test/controllers/school_admin/` et `test/system/school_admin/` verte **sans modification** (iso-comportement des drapeaux)
- **Done quand**   : `bin/rails db:migrate` passe sur une copie de la base de `Develop` ; le bloc « Direction » affiche « Fonction à préciser » sur chaque compte existant ; tous les gestes de la direction marchent comme avant ; `bin/rails routes | grep -E 'staff_position|student_move|student_search'` liste les routes des lots B, D, E

---

## Lot A — Choisir sa fonction en arrivant

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/dtos/identity/school_staff_registration_input.rb
                     app/domain/dtos/identity/school_staff_invitation_input.rb
                     app/domain/use_cases/identity/register_school_staff.rb
                     app/domain/use_cases/identity/invite_school_staff.rb
                     app/domain/use_cases/identity/accept_invitation.rb
                     app/controllers/identity/school_staff_registrations_controller.rb
                     app/controllers/teams/staff_invitations_controller.rb
                     app/views/identity/school_staff_registrations/_form.html.erb
                     app/views/teams/staff_invitations/new.html.erb
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/identity/register_school_staff_test.rb (ED-10, ED-11, ED-12)
                     test/domain/use_cases/identity/invite_school_staff_test.rb (ED-14, ED-15)
                     test/domain/use_cases/identity/accept_invitation_test.rb (ED-14, position recopiée)
                     test/controllers/identity/school_staff_registrations_controller_test.rb (422 et messages)
                     test/controllers/teams/staff_invitations_controller_test.rb
                     test/integration/identity/school_staff_registration_concurrency_test.rb (ED-13 : deux chefs simultanés)
                     test/system/identity/school_staff_registration_test.rb (parcours à 390 px)
- **Done quand**   : une personne s'inscrit comme « Secrétaire » avec le code et lit « Secrétaire » sur sa ligne du bloc « Direction » ; une seconde inscription comme chef est refusée avec le message ; l'équipe invite un éducateur et l'invité arrive « Éducateur »

---

## Lot B — Changer une fonction (réduit par DIR-4 : sans « Préciser ma fonction » ni `school_admin/staff_positions`)

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/use_cases/school/set_staff_position.rb (nouveau)
                     app/domain/policies/school/set_staff_position_policy.rb (nouveau)
                     app/domain/use_cases/school/restore_school_staff.rb (conflit du chef, ED-25)
                     app/controllers/school_admin/staff_positions_controller.rb (nouveau)
                     app/controllers/teams/school_staff_positions_controller.rb (nouveau)
                     app/controllers/teams/school_staff_restorations_controller.rb
                     app/views/school_admin/staff_positions/edit.html.erb (nouveau)
                     app/views/school_admin/staff_positions/update.turbo_stream.erb (nouveau)
                     app/views/teams/school_staff_positions/edit.html.erb (nouveau)
                     app/views/teams/school_staff_positions/update.turbo_stream.erb (nouveau)
                     app/views/teams/school_staff_restorations/create.turbo_stream.erb
                     app/views/shared/_school_staff.html.erb (menus « Préciser ma fonction » et « Changer la fonction »)
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/policies/school/set_staff_position_policy_test.rb (ED-21, ED-22)
                     test/domain/use_cases/school/set_staff_position_test.rb (ED-20, ED-23, ED-24, journal)
                     test/domain/use_cases/school/restore_school_staff_test.rb (ED-25)
                     test/controllers/school_admin/staff_positions_controller_test.rb (403 hors cas, 404 hors établissement)
                     test/controllers/teams/school_staff_positions_controller_test.rb
                     test/controllers/teams/school_staff_restorations_controller_test.rb
                     test/system/school_admin/staff_positions_test.rb (ED-20 au téléphone, sans JavaScript)
- **Done quand**   : une direction sans fonction choisit « Chef d'établissement » depuis son ⋮, sa ligne se met à jour sans rechargement et le menu disparaît ; l'équipe change « Secrétaire » en « Éducateur » depuis la fiche ; une requête forgée d'une direction sur une fonction renseignée reçoit 403

---

## Lot C — Droits par fonction

- **Couche**       : domaine (policies)
- **Fichiers**     : app/domain/policies/school/manage_school_structure_policy.rb
                     app/domain/policies/school/manage_school_teachers_policy.rb
                     app/domain/policies/school/remove_school_staff_policy.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/policies/school/manage_school_structure_policy_test.rb (ED-30, ED-35, ED-36)
                     test/domain/policies/school/manage_school_teachers_policy_test.rb (ED-31, ED-35)
                     test/domain/policies/school/remove_school_staff_policy_test.rb (ED-32)
                     test/controllers/school_admin/school_life_rights_test.rb (nouveau : ED-30 à ED-34, requêtes forgées en 403 et gestes masqués)
                     test/system/school_admin/school_life_rights_test.rb (nouveau : ED-33 à 390 px et sur ordinateur)
- **Done quand**   : une secrétaire connectée ne voit ni « + », ni « − », ni archivage, ni « Retirer » d'un enseignant ou d'une direction, lit la note de l'UDR-0092 §3.5, et ses requêtes forgées reçoivent 403 ; un chef, un adjoint et un compte sans fonction font tout comme avant

---

## Lot D — Changer un élève de classe (retiré, Q5)

> Retiré par le porteur le 2026-10-16. Le contenu ci-dessous reste pour l'historique ; rien n'en est construit.

- **Couche**       : domaine + infrastructure (requête) + delivery + ui
- **Fichiers**     : app/domain/use_cases/classroom/move_student.rb (nouveau)
                     app/domain/policies/classroom/move_student_policy.rb (nouveau)
                     app/infrastructure/queries/school/move_targets_query.rb (nouveau)
                     app/controllers/school_admin/student_moves_controller.rb (nouveau)
                     app/controllers/school_admin/classrooms_controller.rb (drapeau `@movable`)
                     app/views/school_admin/student_moves/new.html.erb (nouveau)
                     app/views/school_admin/student_moves/create.turbo_stream.erb (nouveau)
                     app/views/school_admin/classrooms/show.html.erb (item ⋮ « Changer de classe », voie `transfer`)
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/policies/classroom/move_student_policy_test.rb (ED-47, ED-50)
                     test/domain/use_cases/classroom/move_student_test.rb (ED-40, ED-42, ED-44, ED-45, ED-46, ED-48 ; double du port qui vérifie `via: "transfer"`)
                     test/infrastructure/queries/school/move_targets_query_test.rb (ED-43)
                     test/integration/school_admin/student_move_concurrency_test.rb (ED-49)
                     test/controllers/school_admin/student_moves_controller_test.rb (codes 422, 403, 404 ; ED-51 sans frame)
                     test/system/school_admin/student_move_test.rb (ED-40, ED-41 : la ligne quitte la liste, l'enseignant de la cible voit « Nouveau » et « Changé de classe »)
- **Done quand**   : depuis la page de la 6ème 3, une direction met un élève en 6ème 2 ; la ligne disparaît sans rechargement ; l'enseignant de la 6ème 2 voit l'élève « Nouveau », « Changé de classe » ; le résultat d'un devoir de la 6ème 3 compte toujours dans son suivi

---

## Lot E — Trouver un élève dans l'établissement

- **Couche**       : infrastructure (requête) + delivery + ui
- **Fichiers**     : app/infrastructure/queries/school/student_search_query.rb (nouveau)
                     app/controllers/school_admin/student_searches_controller.rb (nouveau)
                     app/views/school_admin/student_searches/show.html.erb (nouveau)
                     app/views/school_admin/classrooms/_school_card.html.erb (formulaire, UDR-0094 §3.1)
- **Dépend de**    : Lot 0
- **Test associé** : test/infrastructure/queries/school/student_search_query_test.rb (ED-60, ED-61, ED-62, ED-64, ED-65 ; plan d'exécution qui utilise l'index trigramme)
                     test/controllers/school_admin/student_searches_controller_test.rb (ED-63, ED-66, aucun numéro dans la réponse)
                     test/system/school_admin/student_search_test.rb (ED-60 : de l'accueil à la classe filtrée, 390 px)
- **Done quand**   : depuis l'accueil, une direction tape « kouas », voit les élèves de ses classes avec leur classe, et un toucher l'amène à la page de la classe filtrée sur ce nom ; p95 < 100 ms sur un jeu de 2 000 élèves

---

## Lot F — Recette du profil côté direction

- **Couche**       : tests seuls (aucun fichier de `app/`)
- **Fichiers**     : test/controllers/identity/profile_pins_controller_test.rb
                     test/controllers/identity/profile_photos_controller_test.rb
- **Dépend de**    : —
- **Test associé** : les deux fichiers ci-dessus (ED-70, ED-71, ED-72, avec `create_school_admin`)
- **Done quand**   : les trois scénarios passent avec un compte de direction sans changer `app/` ; un échec ouvre un chantier `bugfix` à part, et ce lot s'arrête

---

## Vérification de collision

> Deux lots parallèles ne listent jamais le même fichier.

| Fichier | Lot propriétaire |
|---|---|
| `db/migrate/*`, `db/schema.rb` | Lot 0 |
| `config/routes/school_admin.rb`, `config/routes/teams.rb` | Lot 0 |
| `config/locales/**` (toutes les clés des lots A à E) | Lot 0 |
| `test/support/factories/identity.rb` | Lot 0 |
| `app/domain/entities/school/staff.rb`, `staff_position.rb`, `identity/actor.rb`, `identity/audit_action.rb`, `classroom/student_arrival_channel.rb` | Lot 0 |
| `app/domain/ports/school/staff_repository_port.rb`, `app/infrastructure/repositories/school/staff_repository.rb` | Lot 0 |
| `app/infrastructure/repositories/identity/user_repository.rb`, `queries/school/school_staff_query.rb` | Lot 0 |
| `app/controllers/school_admin/{schools,levels,teachers,departed_teachers}_controller.rb` et leurs vues | Lot 0 |
| `app/controllers/concerns/teams/school_staff_block.rb`, `app/views/teams/schools/show.html.erb` | Lot 0 |
| `app/views/classroom/classrooms/_roster.html.erb` | Lot 0 |
| `app/views/shared/_school_staff.html.erb` | Lot 0 (libellé), puis **Lot B seul** parmi les lots parallèles |
| Inscription et invitation de la direction (DTO, use cases, contrôleurs, vues) | Lot A |
| `set_staff_position*`, `staff_positions/*`, `school_staff_positions/*`, `restore_school_staff.rb`, `school_staff_restorations*` | Lot B |
| `app/domain/policies/school/{manage_school_structure,manage_school_teachers,remove_school_staff}_policy.rb` | Lot C |
| `move_student*`, `move_targets_query.rb`, `student_moves/*`, `school_admin/classrooms_controller.rb`, `school_admin/classrooms/show.html.erb` | Lot D |
| `student_search*`, `student_searches/*`, `school_admin/classrooms/_school_card.html.erb` | Lot E |
| `test/controllers/identity/profile_{pins,photos}_controller_test.rb` | Lot F |

**Collisions avec les autres chantiers des vagues V3 à V6** (ouverts en parallèle le 2026-10-16), à vérifier à l'ouverture du Lot 0 :

| Fichier ou contrat | Ce chantier | Autre chantier probable | Règle |
|---|---|---|---|
| `Entities::Identity::Actor`, `UserRepository#actor` | `staff_position` | V4 `sous-roles-equipe` (`team_role`) | Un seul à la fois : le Lot 0 qui fusionne le premier ; l'autre rebase et rejoue les tests d'acteur |
| `classroom/classrooms/_roster.html.erb` | voie `transfer` (une clé) | V3 `vie-de-la-classe` (page classe) | Le Lot 0 d'ici ne touche qu'une ligne ; fusion avant, ou reprise de la clé dans l'autre chantier |
| `school_admin/classrooms/show.html.erb` | Lot D | V3 `rapports-de-classe` si la direction y gagne des rapports | Pas de chevauchement de lots ; l'ordre de fusion décide |
| `config/routes/*.rb`, `config/locales/**` | Lot 0 | tous | Les Lots 0 fusionnent l'un après l'autre (feuille de route, chevauchement V2 / V4) |
| `school_staffs` | `position` | V2 `annuaire-equipe` (retrait d'une direction par l'équipe) | Colonnes distinctes ; l'anonymisation garde `position` |

## Portes de sortie

- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : inscription d'une secrétaire, gestes masqués, changement de classe, recherche, à 390 px et sur ordinateur (captures envoyées au porteur, non commitées)
- [ ] Pureté du domaine, rubocop, tests, parcours système, brakeman : `bin/ci-quiet` vert, verdict écrit dans la PR
- [ ] Mesures « après » du PRD §7 relevées
- [ ] Sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) une fois sur le diff final (policies, routes et use cases touchés)
- [ ] ADR-0092 et UDR-0092 à 0094 `Accepté` ; index régénérés par `script/docs/build_index` au commit de clôture
- [ ] `journal.md` complété ; feuille de route §5 et §6 mises à jour (ID-10, ID-11, ID-20, SC-11, SC-12, SC-16, SC-20, SC-21, SC-25)

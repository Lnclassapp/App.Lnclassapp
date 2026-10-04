# Plan d'exécution — Inscription de la direction sans invitation

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Spécifications : [`prd.md`](prd.md) · [ADR-0077](../../decisions/adr/0077-inscription-de-la-direction-par-le-code-et-retrait.md) · [UDR-0070](../../decisions/udr/0070-inscription-de-la-direction-et-comptes-direction.md).

## Graphe

```
Lot 0 — SOCLE (séquentiel) : migration, entité Staff, port étendu + adaptateur, query, routes, locales, bloc partagé
  ↓
  ├─► Lot A « S'inscrire comme direction » (page + accueil)        ┐
  ├─► Lot B « Voir et retirer une direction » (côté direction)     ├─ en parallèle
  └─► Lot D « Compte archivé : connexion refusée, suppression J+30 »┘
            ↓
      Lot C « L'équipe retire et restaure » (dépend de B : réutilise ArchiveSchoolStaff)
```

**Le Lot 0 gèle les contrats.** Les lots verticaux *implémentent* et *utilisent* `StaffRepositoryPort`, `Entities::School::Staff` et `SchoolStaffQuery` ; ils ne les redéfinissent pas. Un lot qui a besoin de changer un port ou une méthode de la query **s'arrête** : le Lot 0 rouvre. **Aucun lot parallèle ne démarre avant que le Lot 0 soit mergé** dans `feature/inscription-direction`.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     :
  - `db/migrate/20261004090000_add_joining_and_archiving_to_school_staffs.rb`, `db/schema.rb`
  - `app/domain/entities/school/staff.rb`
  - `app/domain/ports/school/staff_repository_port.rb`
  - `app/domain/ports/identity/registration_repository_port.rb`, `app/infrastructure/repositories/identity/registration_repository.rb` (`create_school_admin`, ajouté à la demande du Lot A)
  - `app/domain/entities/identity/audit_action.rb` (les 4 actions `school_staff.*`, ajoutées après le départ de la vague 2)
  - `app/infrastructure/repositories/school/staff_repository.rb` (les 7 méthodes de l'ADR-0077 §4.2)
  - `app/infrastructure/orm/school_staff.rb`
  - `app/infrastructure/queries/school/school_staff_query.rb`
  - `config/routes/identity.rb`, `config/routes/school_admin.rb`, `config/routes/teams.rb` (routes de l'UDR-0070 §3.0, vers des contrôleurs encore absents)
  - locales `fr` de tout le chantier, textes de l'UDR-0070 :
    - `config/locales/identity/school_staff_registrations.fr.yml`
    - `config/locales/teams/school_staff.fr.yml`
    - `config/locales/shared/school_staff.fr.yml`
    - clés ajoutées dans `config/locales/homepage/index.fr.yml`, `config/locales/school_admin/classrooms.fr.yml`, `config/locales/teams/homes.fr.yml`
  - `app/views/shared/_school_staff.html.erb` (bloc « Direction », UDR-0070 §3.4, utilisé par B et C)
  - fabrique : `create_school_admin(joined_via:, joined_at:, archived_at:, archived_by:)` dans `test/support/factories/identity.rb`
- **Dépend de**    : —
- **Test associé** :
  - `test/domain/entities/school/staff_test.rb`
  - `test/infrastructure/repositories/school/staff_repository_test.rb` (dont le test à deux threads d'ID-04 et les contraintes en base)
  - `test/infrastructure/queries/school/school_staff_query_test.rb`
  - `test/db/school_staffs_constraints_test.rb`
  - `test/architecture/port_contracts_test.rb` vert
  - `test/views/shared/school_staff_partial_test.rb`
- **Couvre**       : ID-04 (repository), ID-08
- **Done quand**   : la migration passe sur une base de production copiée (les lignes existantes valent `invitation`), `bin/rails test` est vert et `bin/rails routes | grep -E "school_staff|staff_member"` liste les 5 routes de l'UDR-0070 §3.0

---

## Lot A — S'inscrire comme direction

- **Couche**       : domaine + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/identity/school_staff_registration_input.rb`
  - `app/domain/policies/identity/register_school_staff_policy.rb`
  - `app/domain/use_cases/identity/register_school_staff.rb`
  - `app/controllers/identity/school_staff_registrations_controller.rb`
  - `app/views/identity/school_staff_registrations/new.html.erb`, `app/views/identity/school_staff_registrations/_form.html.erb`
  - `app/views/homepage/index.html.erb` (lien discret, section `#etablissements`, pied de page)
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/identity/register_school_staff_test.rb`
  - `test/domain/policies/identity/register_school_staff_policy_test.rb`
  - `test/controllers/identity/school_staff_registrations_controller_test.rb`
  - `test/integration/identity/school_staff_registration_rate_limit_test.rb`
  - `test/system/identity/school_staff_registration_test.rb` (parcours depuis la page d'accueil, 390 px)
- **Couvre**       : ID-01, ID-02, ID-03, ID-05, ID-06, ID-07, ID-09
- **Done quand**   : depuis la page d'accueil, un visiteur clique « Créer mon compte de direction », s'inscrit avec le code de A et arrive sur « Travail des élèves » ; au 4ᵉ compte par le code, il lit le refus du plafond

---

## Lot B — Voir et retirer une direction (côté direction)

- **Couche**       : domaine + delivery + ui
- **Fichiers**     :
  - `app/domain/policies/school/remove_school_staff_policy.rb`
  - `app/domain/use_cases/school/archive_school_staff.rb`
  - `app/controllers/school_admin/staff_members_controller.rb`
  - `app/views/school_admin/staff_members/destroy.turbo_stream.erb`
  - `app/views/school_admin/schools/show.html.erb`, `app/controllers/school_admin/schools_controller.rb` (bloc « Direction »)
  - `app/views/school_admin/classrooms/index.html.erb`, `app/controllers/school_admin/classrooms_controller.rb` (bandeau d'arrivée)
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/policies/school/remove_school_staff_policy_test.rb` (toutes les branches de l'ADR-0077 §7)
  - `test/domain/use_cases/school/archive_school_staff_test.rb`
  - `test/controllers/school_admin/staff_members_controller_test.rb`
  - `test/controllers/school_admin/schools_controller_test.rb`, `test/controllers/school_admin/classrooms_controller_test.rb` (complétés)
  - `test/system/school_admin/staff_members_test.rb`
- **Couvre**       : ID-10, ID-11, ID-12, ID-13, ID-14, ID-15, ID-16
- **Done quand**   : Kofi (10 jours) voit le bandeau d'arrivée d'Aya et la retire depuis Établissement ; Aya est déconnectée ; Aya (2 jours) n'a aucun menu ⋮

---

## Lot C — L'équipe retire et restaure

- **Couche**       : domaine + delivery + ui
- **Fichiers**     :
  - `app/domain/policies/school/restore_school_staff_policy.rb`
  - `app/domain/use_cases/school/restore_school_staff.rb`
  - `app/controllers/teams/school_staff_members_controller.rb`, `app/controllers/teams/school_staff_restorations_controller.rb`
  - `app/views/teams/school_staff_members/destroy.turbo_stream.erb`, `app/views/teams/school_staff_restorations/create.turbo_stream.erb`
  - `app/views/teams/schools/_archived_staff.html.erb`, `app/views/teams/schools/show.html.erb`, `app/controllers/teams/schools_controller.rb`
  - `app/views/teams/homes/_archived_staff.html.erb`, `app/views/teams/homes/show.html.erb`, `app/controllers/teams/homes_controller.rb`
- **Dépend de**    : Lot 0, Lot B (`ArchiveSchoolStaff`, `RemoveSchoolStaffPolicy`)
- **Test associé** :
  - `test/domain/use_cases/school/restore_school_staff_test.rb`
  - `test/domain/policies/school/restore_school_staff_policy_test.rb`
  - `test/controllers/teams/school_staff_members_controller_test.rb`, `test/controllers/teams/school_staff_restorations_controller_test.rb`
  - `test/controllers/teams/homes_controller_test.rb`, `test/controllers/teams/schools_controller_test.rb` (complétés)
  - `test/system/teams/school_staff_test.rb`
- **Couvre**       : ID-18, ID-19, ID-20, ID-21
- **Done quand**   : un membre `field` retire Kofi depuis la fiche de A, le voit dans « Directions retirées » (fiche et accueil), puis le restaure ; un membre `content` ne voit ni la carte ni « Restaurer »

---

## Lot D — Compte archivé : connexion refusée, suppression à J+30

- **Couche**       : domaine + infrastructure
- **Fichiers**     :
  - `app/infrastructure/repositories/identity/user_repository.rb` (`#authenticate`, `#actor_for`)
  - `app/domain/policies/school/purge_archived_staff_policy.rb`
  - `app/domain/use_cases/school/purge_archived_staff.rb`
  - `app/jobs/school/purge_archived_staff_job.rb`
  - `config/recurring.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/infrastructure/repositories/identity/user_repository_test.rb` (complété)
  - `test/domain/use_cases/school/purge_archived_staff_test.rb`
  - `test/jobs/school/purge_archived_staff_job_test.rb`
  - `test/integration/identity/archived_staff_sign_in_test.rb`
  - `test/config/recurring_test.rb` (ou celui qui lit déjà `config/recurring.yml`)
- **Couvre**       : ID-17, ID-22
- **Done quand**   : un compte direction archivé reçoit « Numéro ou PIN incorrect. » avec son bon PIN ; la tâche, lancée à la main, anonymise un compte archivé depuis 30 jours et 1 minute, et laisse intact un compte archivé depuis 29 jours

---

## Couverture des critères

| Critère | Lot |
|---|---|
| ID-01, ID-02, ID-03, ID-05, ID-06, ID-07, ID-09 | A |
| ID-04 | 0 (repository) + A (use case) |
| ID-08 | 0 |
| ID-10 à ID-16 | B |
| ID-17, ID-22 | D |
| ID-18 à ID-21 | C |

Aucun critère orphelin.

## Dispatch

```
Vague 1 : Lot 0                 → 1 agent, séquentiel, sur feature/inscription-direction
Vague 2 : Lot A ‖ Lot B ‖ Lot D → 3 agents, worktrees isolés
Vague 3 : Lot C                 → 1 agent, après le merge de B
```

Worktrees **courts** : le nom de la base de test dérive du nom du répertoire et doit tenir sous 63 caractères (journal de `gestion-etablissement-direction`).

```bash
git worktree add /home/user/id-lot-a -b feature/inscription-direction-lot-a feature/inscription-direction
```

Brief de chaque agent :
- le chemin **absolu** de son worktree, utilisé avec `git -C` ;
- son lot recopié en entier ;
- le lien vers ce PRD et vers l'UDR-0070 ;
- l'ordre test rouge → domaine → infrastructure → delivery → UI ;
- l'interdiction de toucher un fichier hors de son champ `Fichiers`.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/identity.rb`, `config/routes/school_admin.rb`, `config/routes/teams.rb` | Lot 0 |
| `config/locales/**` du chantier (y compris `homepage/index.fr.yml`, `school_admin/classrooms.fr.yml`, `teams/homes.fr.yml`) | Lot 0 |
| `db/migrate/…`, `db/schema.rb` | Lot 0 |
| `app/domain/ports/school/staff_repository_port.rb`, `app/infrastructure/repositories/school/staff_repository.rb` | Lot 0 |
| `app/infrastructure/queries/school/school_staff_query.rb` | Lot 0 |
| `app/views/shared/_school_staff.html.erb` | Lot 0 |
| `test/support/factories/identity.rb` | Lot 0 |
| `app/views/homepage/index.html.erb` | Lot A |
| `app/views/school_admin/schools/show.html.erb`, `app/views/school_admin/classrooms/index.html.erb` | Lot B |
| `app/domain/use_cases/school/archive_school_staff.rb`, `app/domain/policies/school/remove_school_staff_policy.rb` | Lot B (lus par C, jamais modifiés) |
| `app/views/teams/schools/show.html.erb`, `app/views/teams/homes/show.html.erb` | Lot C |
| `app/infrastructure/repositories/identity/user_repository.rb`, `config/recurring.yml` | Lot D |

Le contrôle mécanique (`awk … | uniq -d`) ne sort qu'un doublon : `config/recurring.yml`, cité deux fois à l'intérieur du seul Lot D. Il n'y a aucune collision entre lots. `ArchiveSchoolStaff` et `RemoveSchoolStaffPolicy` appartiennent à B ; C les utilise après le merge de B, sans les modifier.

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

## Phase 5

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.

Ici, il rejoue au minimum :
- le parcours accueil → inscription → « Travail des élèves » ;
- le refus du plafond au 4ᵉ compte ;
- le retrait d'Aya par Kofi, puis la tentative de connexion d'Aya ;
- la restauration par l'équipe.

La revue `security-reviewer` est **obligatoire** avant la PR : une inscription sans compte connecté ouvre un accès au travail des élèves.

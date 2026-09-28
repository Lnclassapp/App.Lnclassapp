# ADR-0066 : L'espace direction — une policy à gestes pour deux niveaux de droits, bornée à l'établissement de l'acteur

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, avec ses retours)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md) — critères ED-01 à ED-47, ED-55, ED-57 à ED-64 |
| **Remplace** | — |
| **Amende** | [ADR-0044](./0044-rattachement-de-la-direction-par-invitation.md) (droits par fonction, invitations), [ADR-0057](./0057-code-d-etablissement.md) (la direction voit et régénère le code), [ADR-0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md) (la direction ajoute des classes, retire et réintègre un enseignant), [ADR-0031](./0031-second-facteur-totp-pour-l-equipe.md) (second facteur de la direction), [ADR-0040](./0040-classe-principale-unique-de-l-eleve.md) (changement de classe) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Un établissement existe dans Lnclass, importé par l'équipe avec ses classes générées (ADR-0030, ADR-0056), mais personne dans l'établissement ne peut l'administrer. L'ADR-0044 a fixé comment la direction **entre** (invitation, une école par membre, quatre fonctions, second facteur), sans rien coder : la table `school_staffs` n'existe pas, `Actor` ne connaît pas la fonction, `HomeDestination` envoie tout `school_admin` sur l'écran d'attente, `SecondFactorPolicy` ne connaît que `team`.

Le grill du chantier a précisé ce que la direction **fait**, et il contredit l'ADR-0044 sur deux points :

- **Deux niveaux de droits** (grill 8) : le Proviseur et le Censeur **gèrent** (retirer un enseignant, régénérer le code d'établissement, retirer un membre du personnel, inviter) ; l'Éducateur et la Secrétaire **voient tout l'établissement**, ajoutent des classes et changent un élève de classe. L'ADR-0044 laissait inviter tout membre et ne laissait détacher que le Proviseur.
- **Le code d'établissement** (Q2) : la direction le voit et le régénère. L'ADR-0057 le réservait à l'équipe par `School::ManageSchoolPolicy`, qui autorise aussi l'import, les DRENA et la **validation des enseignants en attente** — que la direction ne fait pas (Q1). Élargir cette policy donnerait à la direction un geste que le porteur a refusé.

Les autres gestes sont nouveaux : ajouter la classe suivante d'un niveau (Q3, ADR-0059), retirer un enseignant sans rien supprimer (grill 7) et le réintégrer (relecture du porteur, 2026-09-28), changer de classe un élève de l'établissement, retrouvé dans la liste ou par son matricule (grill 1, ADR-0065). Chacun doit refuser la direction d'un autre établissement.

À la relecture de la phase Décider (2026-09-28), le porteur a retiré de la V2 le rattachement d'un élève venu d'un autre établissement ou sans classe cette année : la direction ne cherche que les élèves de son établissement. Il a ajouté la **réintégration** d'un enseignant retiré par le Proviseur ou le Censeur, et porté la limite des invitations à 30 par heure.

Une contrainte d'existant pèse sur le changement de classe : l'index unique `(classroom_id, student_id)` de `classroom_students` (ADR-0040) interdit à un élève de revenir dans une classe qu'il a quittée. Or le cas nommé par le grill, « erreur de classe », est précisément un aller-retour.

## 2. Moteurs de décision

1. **Aucune fuite inter-établissements** : chaque geste compare l'établissement de l'acteur à celui de la ressource, dans le domaine, et chaque cas d'usage a son test de refus.
2. **Une seule table de droits**, lisible et testée cellule par cellule, plutôt qu'une policy par geste qui répète la même comparaison.
3. Aucune action de la direction n'efface le travail d'un élève ni d'un enseignant (ADR-0036).
4. Réutiliser les use cases de l'équipe (`AddLevelClassroom`, `RegenerateSchoolCode`) plutôt que les dupliquer.
5. Ne donner à la direction **aucun** geste que le porteur a écarté (validation des comptes en attente, modification de classe, création libre, retrait de classe).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Élargir `ManageSchoolPolicy` et `ManageClassroomPolicy` au `school_admin` de l'école | Deux fichiers touchés | Donne à la direction la validation des comptes en attente, l'import, la création libre et le retrait de classe : refusés par le porteur |
| B — Une policy par geste (`InviteStaffPolicy`, `DetachStaffPolicy`, `RegenerateCodePolicy`…) | Chaque geste nommé | Huit fichiers qui répètent la même comparaison d'établissement et la même liste de fonctions ; une divergence passe inaperçue |
| C — **Une policy à gestes `School::StaffPolicy`, table fonction × geste** | Une comparaison, une table, un test paramétré qui parcourt la table ; l'équipe y garde tous les gestes | Retenue — les gestes sont des symboles à tenir à jour |
| D — Rôles fins en base (`school_roles` de l'ancien) | Souple | Écarté par l'ADR-0044 : quatre fonctions fermées |

Pour le changement de classe :

| Option | Pour | Contre |
|---|---|---|
| E — Rouvrir l'ancienne ligne (`left_at = NULL`) | Aucune migration | Perd la trace du passage dans l'autre classe ; `joined_at` ment |
| F — **Index unique partiel `(classroom_id, student_id) WHERE left_at IS NULL`** | L'historique garde chaque passage ; l'aller-retour marche | Une migration d'index ; deux lignes possibles pour un même couple (voir coûts) |

Options C et F retenues.

## 4. Décision

> **Nous donnons à l'acteur de la direction sa fonction et son établissement, nous exigeons son second facteur comme pour l'équipe, et nous autorisons chacun de ses gestes par une seule policy à gestes, `Policies::School::StaffPolicy`, qui compare l'établissement de l'acteur à celui de la ressource et applique une table fonction × geste ; l'équipe y garde tous les gestes sur tous les établissements.**

### 4.1 L'acteur de la direction

- `Entities::Identity::Actor` gagne `position` (`nil` par défaut).
- `UserRepositoryPort#actor_for(user_id:)`, pour un `school_admin` : `school_id` et `position` sont ceux de la ligne `school_staffs` **active** (`left_at IS NULL`) **dont l'établissement est `active`** ; sinon les deux valent `nil`. Pour les autres rôles, rien ne change.
- `Entities::Identity::HomeDestination` : un `school_admin` avec `school_id` va sur `:school_admin_home` ; sans, sur `:pending_account` (écran d'attente, variante direction, UDR-0052). Il garde son profil.
- `Entities::Identity::User#school_admin?` est ajouté.

### 4.2 Second facteur (amendement de l'ADR-0031, application de l'ADR-0044 C-20)

- `Entities::Identity::SessionState#privileged?` = rôle `team` ou `school_admin`. `ResolveSession` ne construit pas d'acteur pour une session privilégiée non vérifiée ; `SecondFactorPolicy` accepte les sessions privilégiées. Activation, vérification et codes de secours sont ceux de l'ADR-0031.
- **Deux écrans changent** : après la vérification, `Identity::SecondFactorsController` renvoie vers l'accueil **du rôle** (`redirect_to_home`), et non plus vers `team_home_path` ; le bouton « Terminé » des codes de secours (`identity/second_factor_enrollments/backup_codes`) mène à `home_path_for(role)`. Le sous-titre « Obligatoire pour les comptes de l'équipe. » devient « Obligatoire pour l'équipe et la direction. » (UDR-0052 §3.12).
- `ResetSecondFactorPolicy` : l'équipe réinitialise le second facteur d'un membre de l'équipe **ou** d'un `school_admin`, jamais le sien. Personne de la direction ne réinitialise un second facteur.
- **Direction sans établissement** : `AuthenticatedController#hold_detached_school_admin` renvoie un `school_admin` sans `school_id` vers l'écran d'attente sur **toute** page connectée, sauf l'écran d'attente, le profil (`identity/profile*`, `identity/account_photos`) et la déconnexion — comme `hold_pending_teacher` (ADR-0063). Le catalogue ne lui est donc plus ouvert.

### 4.3 La table des droits

`Policies::School::StaffPolicy#call(actor:, school:, gesture:)` — `school` est un `Entities::School::School`.

0. Geste hors de la table → `ArgumentError`, quel que soit l'acteur.
1. `actor.team?` → succès, quel que soit l'établissement (sous-rôles : V4).
2. Sinon `:forbidden` si l'acteur n'est pas `school_admin`, n'a pas de fonction, si `actor.school_id != school.id`, ou si l'établissement n'est pas `active`.
3. Sinon `:forbidden` (`errors: { base: [:position] }`) si la fonction n'a pas le geste :

| Geste | Proviseur `principal` | Censeur `censor` | Éducateur `educator` | Secrétaire `secretary` | Équipe |
|---|---|---|---|---|---|
| `:read` — tableau de bord, classes, enseignants, élèves, personnel, code | ✅ | ✅ | ✅ | ✅ | ✅ |
| `:add_classroom` — classe suivante d'un niveau (ADR-0059) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `:place_student` — changer un élève de l'établissement de classe | ✅ | ✅ | ✅ | ✅ | ✅ |
| `:invite_staff` — inviter Censeur, Éducateur, Secrétaire | ✅ | ✅ | | | ✅ |
| `:invite_principal` — inviter un Proviseur | | | | | ✅ |
| `:regenerate_code` — régénérer le code d'établissement | ✅ | ✅ | | | ✅ |
| `:detach_teacher` — retirer un enseignant de l'établissement | ✅ | ✅ | | | ✅ |
| `:reinstate_teacher` — réintégrer un enseignant retiré de l'établissement | ✅ | ✅ | | | ✅ |
| `:detach_staff` — retirer un membre du personnel | ✅ | ✅ | | | ✅ |

`:invite_principal` est réservé à l'équipe : un établissement n'a qu'un Proviseur actif, qui ne peut donc jamais en inviter un second, et « seule l'équipe retire ou remplace le Proviseur » (memo). La passation d'un Proviseur à son successeur n'existe pas en V2 (point à confirmer, §9).

Règles attachées aux gestes, dans les use cases (la policy ne voit pas la cible) :

- **Nul ne se retire lui-même** (`:forbidden`, `errors: { base: [:self] }`).
- **Seule l'équipe retire un Proviseur** (`:forbidden`, `errors: { base: [:principal] }`) : un établissement sans Proviseur reste géré par son Censeur, ou par l'équipe.
- Gestes **absents** de la table, donc refusés à toute la direction : valider ou refuser un enseignant en attente (Q1, ADR-0063 inchangé), créer une classe au nom libre, retirer une classe (« − »), modifier une classe (CL-02, V3), régénérer ou fermer le code d'adhésion d'une classe, importer, gérer DRENA et référentiels.

### 4.4 Les gestes et leurs use cases

**Règle des deux barrières.** Chaque use case de la direction reçoit `school_id:` — le contrôleur y passe **toujours** `current_actor.school_id`, jamais un paramètre de l'URL — et appelle `StaffPolicy` avec cet établissement, lu **avant** toute écriture. Donc :

- établissement différent de celui de l'acteur → **`:forbidden`** (policy) — c'est le test de refus inter-établissements **au niveau du use case** ;
- ressource (classe, enseignant, membre, élève) hors de l'établissement reçu → **`:not_found`** — c'est ce que voit le contrôleur (404), puisqu'il passe toujours le bon établissement.

**Rien d'écrit sur un refus.** `TransactionPort#call` n'annule que sur exception : un use case qui écrit plusieurs lignes vérifie d'abord tout ce qui peut l'être sans écrire (fonction, établissement actif, Proviseur déjà présent), puis lève `Aborted` sur un `Result` en échec tardif (index unique sous concurrence), comme `JoinWithCode`.

| Use case et signature | Geste | Écritures (une transaction) | Refus | Audit |
|---|---|---|---|---|
| `School::InviteStaffMember#call(actor:, school_id:, dto:)` (ADR-0044) — `dto` : `Dtos::School::StaffInvitationInput` (`contact`, `position`) | `:invite_staff`, ou `:invite_principal` si `position == "principal"` | révoque les invitations expirées du numéro, crée `invitations` (`kind: "school_staff"`, 72 h) | `:conflict` : numéro qui a déjà un compte (`contact: [:taken]`), invitation en cours (`contact: [:already_invited]`), Proviseur actif pour une invitation de Proviseur (`position: [:principal_taken]`), établissement non actif (`base: [:school_inactive]`) | `invitation.sent` `{ school_public_id:, position: }` |
| `Identity::AcceptInvitation#call(token:, dto:)` (étendu) | — (le visiteur n'a que le lien, ADR-0028) | vérifie d'abord établissement actif et Proviseur libre ; compte `school_admin`, `school_staffs` (fonction, établissement, `invited_by_id`), invitation acceptée ; `Aborted` si l'index du Proviseur refuse sous concurrence | `:conflict` (`base: [:no_longer_valid]`) : **rien n'est créé** | `invitation.accepted` `{ school_public_id:, position: }` |
| `School::DetachStaffMember#call(actor:, school_id:, user_public_id:)` (ADR-0044) | `:detach_staff` | `school_staffs.left_at`, suppression de **toutes** les sessions du compte | `:not_found` (membre d'un autre établissement ou déjà parti), `:forbidden` (`self`, `principal`) | `staff.detached` `{ school_public_id:, position: }` |
| `School::RegenerateSchoolCode#call(actor:, public_id:)` (ADR-0057, policy changée) | `:regenerate_code` | inchangées | inchangés | inchangé (`school.changed`, `code_regenerated`) |
| `Classroom::AddLevelClassroom#call(actor:, school_public_id:, level_slug:, series_slug:)` (ADR-0059, policy changée) | `:add_classroom` | inchangées | inchangés (`school_inactive`, `school_draft`, `name_taken`…) | inchangé |
| `School::DetachTeacher#call(actor:, school_id:, teacher_public_id:)` (nouveau) | `:detach_teacher` | supprime la ligne `teacher_schools` de cet établissement et les lignes `teacher_classrooms` des classes de cet établissement (liaisons, comme `WithdrawTeaching`, ADR-0030) ; **écrit un départ ouvert** `teacher_school_departures` ; **ne touche** ni aux assignations, ni aux sessions, ni aux classes, ni au compte, ni à la demande `school_join_requests` | `:not_found` (enseignant dont l'école principale n'est pas celle-ci) | `teacher.detached` `{ school_public_id:, classrooms_count: }` |
| `School::ReinstateTeacher#call(actor:, school_id:, teacher_public_id:)` (nouveau) | `:reinstate_teacher` | rend la ligne `teacher_schools` principale de cet établissement et **clôt le départ** (`reinstated_at`, `reinstated_by_id`) par `SchoolRepositoryPort#reinstate_teacher` ; **ne rend pas** les déclarations `teacher_classrooms` : l'enseignant reprend ses classes en s'y déclarant (`DeclareTeaching`), comme en V1 (décision **déléguée**, amendable, §9) | `:not_found` : aucun départ ouvert de cet établissement, compte anonymisé, **ou enseignant rattaché entre-temps à un autre établissement** (une seule école en V2) — la même réponse, sans dire lequel | `teacher.reinstated` `{ school_public_id: }` |
| `School::RejoinSchoolWithCode#call(actor:, dto:)` (nouveau) — policy `Policies::School::RejoinSchoolPolicy` : enseignant **sans** école principale et **sans** demande `pending` (une demande `rejected` n'empêche pas) | — | ligne `teacher_schools` principale (`attach_teacher`), comme l'inscription par code (ADR-0057) | code inconnu, remplacé, établissement inactif ou brouillon, **ou établissement qui a retiré cet enseignant sans le réintégrer** (`departed?` : départ ouvert) : la même erreur que l'inscription (`school_code: [:inclusion]`) ; `:forbidden` hors policy | `school.changed` `{ change: "teacher_rejoined" }`, sujet l'établissement |
| `School::FindStudentForPlacement#call(actor:, school_id:, dto:)` (nouveau, lecture sous règle) — `dto` : `Dtos::School::StudentLookupInput` (`student_number`) | `:place_student` | aucune | hors format : `:invalid` ; élève qui n'est pas **de cet établissement** (règle ci-dessous), inconnu ou anonymisé : **`:not_found` neutre** (ADR-0065) ; succès : l'élève (`public_id`, nom, matricule, classe actuelle) | aucun |
| `School::PlaceStudent#call(actor:, school_id:, classroom_public_id:, student_public_id:)` (nouveau) — l'élève est **toujours** désigné par son identifiant public, qu'il vienne de la liste ou de la recherche par matricule ; aucun matricule n'est reçu | `:place_student` | verrou de la classe cible (`lock_by_public_id`, comme `JoinWithCode`), clôt l'adhésion principale active (`left_at`), crée la nouvelle adhésion principale ; `Aborted` si l'écriture échoue | élève qui n'est pas de cet établissement : `:not_found` ; classe hors de l'établissement, archivée ou d'une autre année : `:not_found` ; classe pleine : `:forbidden` `classroom_full` ; déjà dans cette classe : `:conflict` `already_member` | `student.placed` `{ classroom_public_id:, from_classroom_public_id: }` |

**Élève de l'établissement** (`Entities::School::StudentPlacement.placeable?(membership:, school_id:, school_year:)`, distinct d'`Entities::Classroom::Placement`, qui place une classe dans un niveau) : un élève non anonymisé dont l'adhésion principale active (`left_at IS NULL`) est dans une classe **active**, de l'**année scolaire en cours**, de **cet établissement**. Tout autre élève — sans adhésion active, dans une classe archivée ou d'une autre année, ou dans un autre établissement — n'est **ni trouvé ni déplacé** par la direction, avec la même réponse neutre : il rejoint sa classe par son code d'adhésion (ADR-0040). La recherche et le changement de classe appliquent la même règle. Le rattachement d'un élève venu d'ailleurs et le changement d'établissement d'un élève sont hors V2 (backlog `changement-etablissement-eleve`).

**Changement de classe** (amendement de l'ADR-0040) : l'index unique `(classroom_id, student_id)` devient **partiel**, `WHERE left_at IS NULL`. Un élève peut avoir plusieurs lignes, closes, pour la même classe ; une seule ouverte. Ses résultats restent attachés à leurs devoirs.

**Départ d'un enseignant** : table `teacher_school_departures` (`teacher_id` → users, `school_id` → schools, `detached_by_id` → users, `created_at`, puis `reinstated_at` et `reinstated_by_id` → users, nuls tant que le départ est **ouvert** ; `CHECK` : les deux nuls ou les deux présents ; index unique partiel `(teacher_id, school_id) WHERE reinstated_at IS NULL`, un seul départ ouvert par couple ; clés `RESTRICT`). Elle garde la trace de chaque retrait et de chaque réintégration (ce que la suppression des liaisons efface). Un départ ouvert empêche l'enseignant retiré de revenir **seul**, par le code diffusé, dans l'établissement qui l'a retiré, et le fait figurer dans la liste « Enseignants retirés » de cet établissement.

**Réintégration** (relecture du porteur, 2026-09-28) : le Proviseur ou le Censeur réintègre, depuis la page « Enseignants », un enseignant de la liste des retirés de **son** établissement (départ ouvert, compte non anonymisé, sans école principale). Il retrouve l'établissement ; il ne retrouve pas ses classes d'office (décision déléguée, §9).

### 4.5 Ports (gelés au Lot 0a, **implémentés au Lot 0a**)

`test/architecture/port_contracts_test.rb` exige qu'un adaptateur implémente chaque méthode de son port : chaque méthode ajoutée ici est donc implémentée dans le même lot socle que le port.

| Port | Méthode | Contrat |
|---|---|---|
| `Ports::School::StaffRepositoryPort` (**nouveau**) | `attach(user_id:, school_id:, position:, invited_by_id:, at:)` | `Result(StaffMember)` \| `failure(:conflict, errors: { base: [:other_school] })` \| `failure(:conflict, errors: { position: [:principal_taken] })` (index uniques) ; `ArgumentError` si le compte n'est pas `school_admin` (aucun `CHECK` ne peut lire `users`) |
| | `find_active(user_public_id:, school_id:)` | `Entities::School::StaffMember \| nil` |
| | `principal_active?(school_id:)` | `Boolean` |
| | `detach(id:, at:)` | `true` |
| `Ports::Identity::UserRepositoryPort` | `actor_for` | + `position` (§4.1) |
| | `find_student_by_number(student_number:)`, `update_student_number(user_id:, student_number:)` | ADR-0065 |
| `Ports::Identity::RegistrationRepositoryPort` | `create_student` | conflit `student_number` (ADR-0065) — implémenté au Lot F avec l'inscription |
| `Ports::Classroom::MembershipRepositoryPort` | `primary_for(student_id:)` | `Membership` gagne `school_id`, `school_year`, `classroom_public_id` et `classroom_name` de la classe, **avec valeur par défaut `nil`** (`initialize` à défauts, comme `Actor`) : les appelants existants ne changent pas |
| `Ports::Classroom::ClassroomRepositoryPort` | `lock_by_public_id(public_id:)` (**nouveau**) | verrou, `Classroom` avec `active_students_count` \| `nil` |
| `Ports::Classroom::TeachingRepositoryPort` | `withdraw_all_in_school(teacher_id:, school_id:)` (**nouveau**) | `Integer` (lignes supprimées) |
| `Ports::School::SchoolRepositoryPort` | `detach_teacher(teacher_id:, school_id:, detached_by_id:, at:)` (**nouveau**) | supprime la ligne `teacher_schools`, écrit le départ ; `Result \| failure(:not_found)` |
| | `departed?(teacher_id:, school_id:)` (**nouveau**) | `Boolean` : un départ **ouvert** existe |
| | `reinstate_teacher(teacher_id:, school_id:, reinstated_by_id:, at:)` (**nouveau**) | rend la ligne `teacher_schools` principale, clôt le départ ouvert ; `Result` \| `failure(:not_found)` (aucun départ ouvert) \| `failure(:conflict, errors: { base: [:other_school] })` (école principale prise entre-temps) |
| `Ports::School::JoinRequestRepositoryPort` | `pending_for(teacher_id:)` (**nouveau**) | `Entities::School::JoinRequest \| nil` (demande `pending` de l'enseignant) |

Entités nouvelles : `Entities::School::StaffMember` (`id, user_id, school_id, position, invited_by_id, joined_at, left_at`), `Entities::School::StaffPosition` (`ALL`, `MANAGERS = %w[principal censor]`, table des gestes de §4.3) et `Entities::School::StudentPlacement` (règle « élève de l'établissement »). `Entities::Identity::Invitation::POSITIONS` reste dans `identity` (pas de dépendance d'un contexte à l'autre) ; un test vérifie qu'il égale `StaffPosition::ALL`.

### 4.6 Lectures (CQRS, ADR-0006)

Chaque liste lit l'établissement **de l'acteur** et lui seul ; aucune ne renvoie un numéro de téléphone ni une note d'élève.

| Query | Contenu | Pagination |
|---|---|---|
| `Queries::School::DirectionSchoolQuery` | nom, DRENA, type, statut, code (affiché `K7M-4QZ`) de l'établissement de l'acteur | — |
| `Queries::School::DirectionClassroomsQuery` | classes actives de l'année de l'établissement, par niveau, avec effectif et plafond (filtres et choix de classe) | — |
| `Queries::School::StaffMembersQuery` | membres actifs : nom, fonction, date d'arrivée, `user_public_id` | non (≤ quelques dizaines) |
| `Queries::School::SchoolTeachersQuery` | enseignants dont l'école principale est celle-ci, non anonymisés : nom, matière, classes de l'année dans cet établissement ; filtre par classe | 20 par page |
| `Queries::School::DepartedTeachersQuery` | enseignants retirés de cet établissement et réintégrables : départ ouvert, compte non anonymisé, **sans école principale** ; nom, matière, date du retrait, `public_id` | 20 par page |
| `Queries::School::SchoolStudentsQuery` | élèves de l'établissement (« élève placé » de l'ADR-0062 dans une classe de cet établissement, la même règle que `StudentPlacement`) : nom, matricule, classe ; filtre par classe | 20 par page |
| `Queries::School::SchoolDashboardQuery` | ADR-0067 | — |

**Limites de débit** (en plus de l'ADR-0065) : l'invitation (`staff_invitations#create`, direction et équipe) est bornée à **30 par heure et par compte** (un lycée a beaucoup de personnel, porteur, 2026-09-28) — elle dit si un numéro a un compte Lnclass ; le retour par code (`school_rejoins#create`) à **10 par minute et par adresse**, compteur propre.

## 5. Conséquences

### 🟢 Positives

- L'établissement se gère sans l'équipe : classes, personnel, code, enseignants, élèves.
- Une seule table dit qui peut quoi ; un test paramétré la parcourt, cellule vide comprise.
- Les gestes que le porteur a refusés restent refusés par construction : `ManageSchoolPolicy` et `ManageClassroomPolicy` ne changent pas.
- Le retrait d'un enseignant ne perd ni classe, ni devoir, ni résultat ; l'enseignant garde son compte et peut rejoindre un **autre** établissement par son code ; le départ reste tracé ; un retrait par erreur se défait par la réintégration.
- Le changement de classe garde l'historique complet de l'élève.

### 🔴 Coûts consentis

- **Deux notions « établissement » dans `Actor`** selon le rôle : l'école principale d'un enseignant, le rattachement actif d'une direction. Une policy qui oublie le rôle pourrait confondre les deux ; `StaffPolicy` teste le rôle d'abord.
- **Un établissement inactif coupe sa direction sans prévenir** : elle voit l'écran d'attente. C'est voulu (memo), mais aucune notification.
- **Un Proviseur parti bloque la fonction** tant que l'équipe ne l'a pas retiré ; **seule l'équipe invite un Proviseur** : pas de passation directe d'un Proviseur à son successeur.
- **L'index partiel de `classroom_students`** autorise plusieurs lignes closes pour un même couple : une lecture historique « l'élève est passé par cette classe » doit dédoublonner.
- **Retirer un enseignant supprime ses déclarations** d'enseignement (liaisons) : on ne sait plus dans quelles classes il a enseigné, sauf par l'audit et par `classroom_assignments.assigned_by_id` ; `teacher_school_departures` garde seulement l'établissement. **La réintégration ne les rend pas** : l'enseignant se redéclare dans ses classes.
- **Un enseignant retiré ne revient pas seul** dans l'établissement qui l'a retiré : le code l'y refuse ; seuls le Proviseur ou le Censeur le réintègrent. Sans ce refus, le retrait n'aurait aucun effet : le code est diffusé à tous les enseignants. L'équipe a le geste dans la table (règle 1) mais **aucun écran** de réintégration en V2.
- **Un enseignant retiré qui a rejoint un autre établissement n'est plus réintégrable** (une seule école en V2) : il disparaît de la liste des retirés, sans que la direction sache pourquoi.
- **L'invitation est un oracle des numéros** : elle dit à un Proviseur ou un Censeur si un numéro a déjà un compte Lnclass, numéros d'élèves compris. Borné à 30 invitations par heure et par compte, tracé par `invitation.sent` ; le message ne dit ni le rôle ni le nom du compte.
- **L'enseignant retiré reste en session** : il est renvoyé vers l'écran d'attente à sa requête suivante (garde de l'ADR-0063), sans fermeture de session.
- **Un enseignant retiré qui avait une demande approuvée** (démarrage à froid) ne peut pas en recréer une : l'index unique `school_join_requests.teacher_id` l'en empêche. Il revient seulement par un code d'établissement.
- **Une invitation ne vise qu'un numéro sans compte** : un enseignant qui devient Censeur, ou un ancien membre qu'on réinvite, doit utiliser un autre numéro, ou attendre un chantier de rattachement d'un compte existant.
- **Les invitations en cours ne se listent pas** : le lien s'affiche une fois ; une invitation perdue attend son expiration (72 h) avant d'être réémise.
- Les listes de la direction affichent les initiales, pas la photo : `ReadUserPolicy` (ADR-0060) n'est pas élargie à la direction dans ce chantier.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/school/staff_position.rb
# 🧠 DOMAINE · Entities::School::StaffPosition
# Rôle : les quatre fonctions de la direction (ADR-0044) et la table des gestes de chaque fonction
# ADR  : 0044, 0066
module Entities
  module School
    module StaffPosition
      ALL = %w[principal censor educator secretary].freeze
      MANAGERS = %w[principal censor].freeze
      EVERYONE = %i[read add_classroom place_student].freeze
      MANAGE = %i[invite_staff regenerate_code detach_teacher reinstate_teacher detach_staff].freeze
      GESTURES = {
        "principal" => [ *EVERYONE, *MANAGE ],
        "censor" => [ *EVERYONE, *MANAGE ],
        "educator" => EVERYONE,
        "secretary" => EVERYONE
      }.freeze
      # :invite_principal n'est à aucune fonction : l'équipe seule (StaffPolicy, règle 1).
      ALL_GESTURES = [ *EVERYONE, *MANAGE, :invite_principal ].freeze

      def self.allows?(position, gesture)
        raise ArgumentError, "geste inconnu : #{gesture.inspect}" unless ALL_GESTURES.include?(gesture)

        GESTURES.fetch(position, []).include?(gesture)
      end
    end
  end
end
```

```ruby
# app/domain/policies/school/staff_policy.rb
# 🧠 DOMAINE · Policies::School::StaffPolicy
# Rôle : geste de la direction sur son établissement actif, selon sa fonction ; l'équipe a tous les gestes partout
# ADR  : 0028, 0044, 0066
module Policies
  module School
    class StaffPolicy
      def call(actor:, school:, gesture:)
        raise ArgumentError, "geste inconnu : #{gesture.inspect}" unless Entities::School::StaffPosition::ALL_GESTURES.include?(gesture)
        return Shared::Result.success if actor&.team?
        return Shared::Result.failure(:forbidden) unless member_of?(actor, school)
        return Shared::Result.failure(:forbidden, errors: { base: [ :position ] }) unless
          Entities::School::StaffPosition.allows?(actor.position, gesture)

        Shared::Result.success
      end

      private

      def member_of?(actor, school)
        actor&.school_admin? && !actor.position.nil? && !school.nil? && actor.school_id == school.id && school.status == "active"
      end
    end
  end
end
```

```ruby
# db/migrate/20260929090100_create_school_staffs.rb — ADR-0044 §6, inchangé
# db/migrate/20260929090300_create_teacher_school_departures.rb
create_table :teacher_school_departures do |t|
  t.references :teacher, null: false, foreign_key: { to_table: :users }, index: false
  t.references :school, null: false, foreign_key: true
  t.references :detached_by, null: false, foreign_key: { to_table: :users }
  t.datetime :created_at, null: false
  t.datetime :reinstated_at
  t.references :reinstated_by, foreign_key: { to_table: :users }
end
add_index :teacher_school_departures, %i[teacher_id school_id], unique: true, where: "reinstated_at IS NULL",
          name: "index_teacher_school_departures_one_open"
add_check_constraint :teacher_school_departures, "(reinstated_at IS NULL) = (reinstated_by_id IS NULL)",
                     name: "teacher_school_departures_reinstated_pair"

# db/migrate/20260929090200_partial_unique_classroom_students.rb
class PartialUniqueClassroomStudents < ActiveRecord::Migration[8.1]
  def change
    remove_index :classroom_students, %i[classroom_id student_id],
                 name: "index_classroom_students_on_classroom_id_and_student_id", unique: true
    add_index :classroom_students, %i[classroom_id student_id], unique: true, where: "left_at IS NULL",
              name: "index_classroom_students_one_open_per_classroom"
  end
end
```

`Entities::Identity::AuditAction::ALL` gagne `staff.detached`, `teacher.detached`, `teacher.reinstated`, `student.placed` et `student_number.changed` (ADR-0065).

Contrôleur de base : `SchoolAdmin::BaseController < AuthenticatedController`, `allow_roles :school_admin`, puis `redirect_to pending_account_path if current_actor.school_id.nil?`. La garde du second facteur est celle d'`Authentication` (acteur `nil` tant que la session n'est pas vérifiée).

## 7. Comment vérifier que la décision est respectée

- `test/domain/policies/school/staff_policy_test.rb` : **chaque cellule** de la table (§4.3), y compris les vides ; un membre d'un établissement A refusé sur B pour **chaque** geste ; établissement inactif refusé ; `school_admin` sans fonction refusé ; équipe acceptée partout ; geste inconnu → `ArgumentError` pour l'équipe, un membre et un visiteur.
- `test/architecture/port_contracts_test.rb` (existant) : chaque méthode ajoutée au §4.5 a son adaptateur dès le Lot 0a.
- `test/architecture/use_case_policies_test.rb` (existant) : chaque nouveau use case prend `policy:` (dont `RejoinSchoolWithCode` → `RejoinSchoolPolicy`).
- `test/domain/use_cases/school/rejoin_school_with_code_test.rb` : l'établissement qui a retiré l'enseignant (départ ouvert) répond comme un code invalide.
- `test/domain/use_cases/school/reinstate_teacher_test.rb` : l'enseignant retrouve l'établissement sans aucune déclaration de classe ; le départ est clos ; refus Éducateur et Secrétaire ; établissement B → `:forbidden` ; enseignant retiré de B, anonymisé ou rattaché ailleurs → `:not_found` ; retiré de nouveau ensuite → un second départ ouvert est accepté.
- Un test de use case par geste du §4.4, dont un **refus inter-établissements** et, pour les gestes de gestion, un **refus Éducateur et Secrétaire**.
- `test/domain/use_cases/school/detach_teacher_test.rb` : aucune assignation, session, classe ni demande touchée ; seules les déclarations des classes de **cet** établissement disparaissent.
- `test/infrastructure/repositories/school/staff_repository_test.rb` : second rattachement actif → `:conflict other_school` ; second Proviseur actif → `:conflict principal_taken`.
- `test/db/schema_constraints_test.rb` : `school_staffs` (fonction, index) ; `classroom_students` accepte deux lignes closes et refuse deux ouvertes pour un couple ; `teacher_school_departures` accepte un départ clos et un ouvert pour un couple, refuse deux ouverts et un `reinstated_at` sans `reinstated_by_id`.
- `test/integration/school_admin_access_test.rb` : **chaque** route `SchoolAdmin::` redirige un `school_admin` connecté par PIN seul vers le second facteur, et répond 403 à `student`, `teacher`, `team` (test paramétré sur `Rails.application.routes`, comme l'ADR-0031).
- `test/domain/use_cases/identity/resolve_session_test.rb` : pas d'acteur pour une session `school_admin` non vérifiée.
- Les tests existants de `ReviewJoinRequest`, `CreateClassroom`, `RemoveLevelClassroom` gardent leur refus du `school_admin` (policies inchangées).

## 8. Remplace, complète, amende

- **Amende l'ADR-0044** : invitations par le Proviseur et le Censeur seulement, un Proviseur par l'équipe seule ; retrait d'un membre par le Proviseur, le Censeur ou l'équipe, jamais de soi ni d'un Proviseur par la direction ; `School::InviteStaffPolicy` n'existe pas, `StaffPolicy` la remplace ; une invitation ne vise qu'un numéro sans compte ; journal `staff.detached` avec la fonction.
- **Amende l'ADR-0057** : `RegenerateSchoolCode` est autorisé par `StaffPolicy` (`:regenerate_code`) ; toute la direction lit le code ; `ManageSchoolPolicy` reste à l'équipe.
- **Amende l'ADR-0030** (et crée `teacher_school_departures`) : `AddLevelClassroom` est autorisé par `StaffPolicy` (`:add_classroom`) ; `CreateClassroom` et `RemoveLevelClassroom` restent à l'équipe (`ManageClassroomPolicy`) ; la direction retire un enseignant de l'établissement (`DetachTeacher`) et le réintègre (`ReinstateTeacher`), et un enseignant sans école rejoint un **autre** établissement par son code (`RejoinSchoolWithCode`).
- **Amende l'ADR-0031** : le second facteur et sa réinitialisation par l'équipe valent pour `school_admin`.
- **Amende l'ADR-0040** : index unique partiel `WHERE left_at IS NULL` ; la direction change de classe un élève de son établissement (pas de rattachement d'un élève venu d'ailleurs).
- **Complète l'ADR-0063** : la direction ne valide pas les comptes en attente (Q1) ; `ReviewJoinRequest` et `VouchForTeacher` ne changent pas.

## 9. Points à confirmer par le porteur

Relus et acceptés par le porteur le 2026-09-28, avec ses retours. **Le porteur « ne connaît pas bien le fonctionnement de l'administration » et garde ces droits de base pour le moment : la table du §4.3 sera revue avec des directions réelles** (Proviseurs, Censeurs, Éducateurs, Secrétaires en poste) après les premiers établissements ; toute case changée amende cet ADR.

Décisions prises par délégation (memo, 2026-09-28), amendables :

- La direction n'a **pas** le « − » (retrait de la dernière classe jamais utilisée) : seulement le « + » (Q3 le limite à « ajouter la classe suivante »).
- Toute la direction **lit** le code d'établissement ; seuls le Proviseur et le Censeur le régénèrent : **accepté tel quel** par le porteur le 2026-09-28.
- Une invitation ne vise qu'un numéro **sans** compte Lnclass : **gardé** par le porteur le 2026-09-28.
- ~~Un enseignant retiré revient seulement par un code d'établissement, jamais dans l'établissement qui l'a retiré (aucun écran ne lève ce refus en V2)~~ : **amendé par le porteur le 2026-09-28** : il ne revient toujours pas **seul** par le code, mais le Proviseur ou le Censeur le **réintègre** depuis la page « Enseignants ».
- **La réintégration rend l'établissement, pas les classes** (délégué, amendable) : l'enseignant se redéclare dans ses classes, comme en V1. Rendre les déclarations d'origine demanderait de les garder dans le départ.
- **Seule l'équipe invite un Proviseur** ; pas de passation d'un Proviseur à son successeur. (Le memo disait « seul un Proviseur invite un Proviseur » et « un seul Proviseur actif » : les deux ensemble rendaient le geste impossible.)
- ~~Invitations bornées à 10 par heure et par compte~~ : **30 par heure et par compte** (porteur, 2026-09-28).
- La direction voit le **code d'adhésion** de ses classes sans pouvoir le régénérer ni le fermer : **confirmé** par le porteur le 2026-09-28 ; ce code est généré à la création de la classe, y compris pour une classe ajoutée par la direction (`ClassroomRepository#create`, ED-64).
- Un établissement inactif renvoie sa direction à l'écran d'attente.
- ~~La direction rattache par son matricule un élève sans classe cette année~~ : **retiré par le porteur le 2026-09-28** : la direction ne cherche et ne déplace que les élèves de son établissement.

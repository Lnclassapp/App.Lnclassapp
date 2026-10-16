# ADR-0094 : Un enseignant se rattache lui-même à trois établissements au plus, travaille dans un établissement courant gardé par sa session, et chaque direction n'agit que sur son rattachement
<!-- index
titre: Un enseignant se rattache lui-même à trois établissements au plus, travaille dans un établissement courant gardé par sa session, et chaque direction n'agit que sur son rattachement
statut: Accepté *(porteur, 2026-10-16 ; amendé le 2026-10-16 : MET-4, MET-8)* — *amende 0030, 0062, 0071, 0081, 0083 ; complète 0028, 0063*
problematique: `teacher_schools` inchangée (lignes secondaires enfin écrites) ; `sessions.current_school_id` ; `actor.school_id` = établissement courant vérifié à chaque requête, défaut le principal ; `JoinSchoolWithCode` élargi (écran d'attente, lien `/i/<jeton>` connecté, « Ajouter un établissement ») sous verrou et plafond 3 ; `LeaveSchool` ; `SwitchCurrentSchool` ; `DetachTeacher` promeut un principal ; `ReinstateTeacher` rattache en secondaire. Chantier `multi-etablissements-enseignant`.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) — amendé le 2026-10-16 (§10, MET-4 ; §11, MET-8) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/multi-etablissements-enseignant`](../../chantiers/multi-etablissements-enseignant/prd.md) — critères ME-01 à ME-24 |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'[ADR-0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md) a gardé la table n-n `teacher_schools` avec un drapeau `primary` et limité l'enseignant à **une** ligne en V1, en promettant que « la V3 ajoute le sélecteur d'école en levant la règle "une ligne" dans le use case, sans toucher au schéma ». Depuis, trois décisions ont bougé le terrain :

- l'[ADR-0071](./0071-gestes-de-la-direction-sur-son-etablissement.md) donne à la direction le retrait et la réintégration d'un enseignant, écrits pour un enseignant à un seul établissement : retirer supprime sa seule ligne, et la réintégration refuse un enseignant qui a déjà un établissement ;
- l'[ADR-0083](./0083-inscription-enseignant-en-deux-voies.md) retire le code d'établissement côté enseignant (lien `/i/<jeton>` ou choix dans la DRENA) et rattache **sans preuve** ; un enseignant connecté qui ouvre un lien est renvoyé vers son accueil ;
- l'ADR-0073 puis l'ADR-0083 arrêtent la création de demandes en attente.

Aujourd'hui, `Actor#school_id` vaut l'établissement **principal** ([ADR-0028](./0028-policies-de-domaine-par-use-case.md)), et toutes les policies de l'enseignant le comparent : se déclarer dans une classe, publier une annonce, inviter un collègue. Quatre lectures de l'enseignant ne filtrent pas par établissement et mélangeraient deux établissements dont les classes portent les mêmes noms (« 6ème 1 »). L'inventaire complet est dans le [memo](../../chantiers/multi-etablissements-enseignant/memo.md#inventaire--comment-un-enseignant-est-rattaché-aujourdhui).

## 2. Moteurs de décision

1. **Chaque direction ne voit et ne touche que sa part** : aucune lecture ni aucun geste d'une direction ne dépend d'un autre établissement de l'enseignant.
2. **Ne pas réécrire les policies** : une vingtaine de règles comparent déjà `actor.school_id` ; les garder justes vaut mieux que les multiplier.
3. **Pas de rattachement sans l'accord de l'enseignant**, et pas de recherche d'un compte par son numéro par une direction.
4. **Aucune production d'élève perdue** (ADR-0036) : quitter ou être retiré garde sessions, résultats et devoirs archivés lisibles.
5. Une donnée nouvelle seulement si un geste la lit.

## 3. Options envisagées

**Comment l'enseignant travaille dans plusieurs établissements**

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Vue fusionnée : `actor.school_ids`, toutes les classes ensemble | Aucun état à garder | Chaque policy passe d'une égalité à une appartenance ; les annonces et l'invitation doivent demander « quel établissement ? » à chaque fois ; les classes homonymes se côtoient |
| B — Le drapeau `primary` **est** l'établissement courant ; changer réécrit `teacher_schools` | Aucune colonne ; vaut sur tous les appareils | Le lien personnel « Inviter un collègue » se résout vers le principal (ADR-0063, 0083) : un lien partagé depuis A mènerait à B après un changement. Le pilotage changerait de DRENA à chaque bascule |
| C — **Un établissement courant par session** (`sessions.current_school_id`), vérifié à chaque requête ; le principal reste stable | Les policies ne changent pas ; le principal garde son sens (lien personnel, pilotage, défaut) ; une colonne nullable | Retenue — chaque appareil a le sien, et une colonne de plus sur `sessions` |

**Qui rattache l'enseignant à un autre établissement**

| Option | Pour | Contre |
|---|---|---|
| D — La direction, par le numéro (ID-09 de l'ancienne application) | La direction contrôle qui entre | Rattache sans l'accord de l'enseignant ; révèle qu'un numéro a un compte ; dépend de l'espace direction complet (V2, au backlog) |
| E — **L'enseignant, par le lien de l'établissement ou par la liste de sa DRENA** | Même règle que l'inscription (ADR-0083) ; le lien de la direction existe déjà | Retenue — sans preuve, comme l'inscription ; borné par le plafond et par la règle des départs |

Options C et E retenues.

## 4. Décision

> **Nous laissons un enseignant se rattacher lui-même à trois établissements au plus, par le lien d'invitation d'un établissement ou par la liste de sa DRENA ; il travaille dans un établissement courant, gardé par sa session et vérifié à chaque requête, qui devient `actor.school_id` ; l'établissement principal reste le premier et n'est remplacé que s'il le quitte ou en est retiré ; chaque direction ne lit et ne retire que le rattachement de son établissement.**

### 4.1 Données

**`teacher_schools` ne change pas.** Une ligne par établissement ; `primary` marque l'établissement principal, unique par l'index partiel existant. Une ligne secondaire a `primary = false`.

**`sessions.current_school_id`** (contexte `identity`, migration du Lot 0) :

| Colonne | Contrainte |
|---|---|
| `current_school_id` | `bigint NULL`, FK `schools` `ON DELETE SET NULL` |

Pas d'index : la session est toujours lue par `token_digest`. `NULL` signifie « l'établissement principal ». Seule une session d'enseignant l'écrit.

**Plafond** : `Entities::School::TeacherSchools::MAX = 3`.

### 4.2 L'acteur

`Ports::Identity::UserRepositoryPort#actor_for(user_id:, current_school_id: nil)` : pour un enseignant, `school_id` est `current_school_id` **s'il a une ligne `teacher_schools` pour cet établissement**, sinon son établissement principal, sinon `nil`. Une seule requête :

```sql
SELECT school_id FROM teacher_schools
WHERE teacher_id = $1 AND (school_id = $2 OR "primary")
ORDER BY (school_id = $2) DESC LIMIT 1
```

`ResolveSession` passe `session.current_school_id`. Pour les autres rôles, rien ne change. Conséquences :

- toutes les policies qui comparent `actor.school_id` portent désormais sur **l'établissement courant**, sans modification ;
- une session qui désigne un établissement quitté ou retiré retombe sur le principal à la requête suivante, sans écriture ;
- la garde de `AuthenticatedController` (`school_id` nil → écran d'attente) ne vaut que pour un enseignant **sans aucun** établissement.

### 4.3 Policies

| Policy | Règle |
|---|---|
| `Policies::School::JoinSchoolWithCodePolicy#call(actor:, pending_request:, schools_count:)` (**amendée**) | `teacher`, sans demande `pending`, et `schools_count < TeacherSchools::MAX` → succès. `schools_count` 0 : l'écran d'attente, comme avant ; ≥ 1 : un établissement de plus. Au plafond : `:forbidden` avec `errors: { base: [:schools_limit] }` |
| `Policies::School::SwitchCurrentSchoolPolicy#call(actor:, attached:)` (**nouvelle**) | `teacher` et `attached` (une ligne `teacher_schools` existe pour cet établissement) → succès ; sinon `:forbidden` |
| `Policies::School::LeaveSchoolPolicy#call(actor:, attached:, schools_count:)` (**nouvelle**) | `teacher`, `attached` et `schools_count >= 2` → succès ; dernier établissement : `:forbidden` avec `errors: { base: [:last_school] }` ; non rattaché : `:not_found` |
| ~~`Policies::Identity::InviteColleaguePolicy#call(actor:, school:, primary_school_id:)`~~ | **Remplacé au §11 (MET-8)** : la policy garde sa forme d'origine, sur l'établissement courant |
| `ManageSchoolTeachersPolicy`, `ManageSchoolStructurePolicy`, `DeclareTeachingPolicy`, `PublishPolicy`, `VouchPolicy` | **Inchangées.** Elles lisent l'établissement courant à travers `actor.school_id`. `TeachPolicy`, `ReadClassroomPolicy` et les policies d'une classe : **amendées** au §10 (MET-4) |

### 4.4 Use cases

Écritures dans une transaction ; un refus après une écriture lève et ressort en `Result` (`raise Aborted`, comme `DetachTeacher`).

| Use case | Signature | Écritures | Refus | Audit |
|---|---|---|---|---|
| `School::JoinSchoolWithCode` (**amendé**) | `call(actor:, dto:)` ; `dto` : `SchoolJoinInput` (DRENA → établissement) **ou** `SchoolInviteJoinInput` (`token`) | `attach_teacher_within_cap(teacher_id:, school_id:, primary: schools_count.zero?, cap: MAX, at:)` ; si `primary: false`, la session passe sur le nouvel établissement (`set_current_school`) | `:forbidden` (policy, plafond) ; `:invalid` `school_public_id: [:inclusion]` (même erreur neutre : inconnu, inactif, autre DRENA, **départ ouvert**, lien invalide) ; `:conflict` `base: [:already_attached]` (déjà rattaché) ; `:conflict` `base: [:schools_limit]` (plafond atteint sous verrou) | `school.changed`, `{ change: "teacher_joined", via: "standard" \| "colleague" \| "direction" \| "team" }` |
| `School::SwitchCurrentSchool` (**nouveau**) | `call(actor:, session_id:, school_public_id:)` | `SessionRepositoryPort#set_current_school(id:, school_id:)` | `:forbidden` (policy) ; `:not_found` (établissement inconnu) | aucun : un choix d'affichage |
| `School::LeaveSchool` (**nouveau**) | `call(actor:, school_public_id:)` | `withdraw_all_in_school` ; `archive_all_by_teacher_in_school(archived_by_id: actor.user_id)` ; `detach_teacher` ; `promote_primary` ; **pas** de `teacher_school_departures` (il peut revenir) | `:forbidden` (dernier établissement) ; `:not_found` (non rattaché) | `teacher.left`, sujet le compte, `{ school_id:, classrooms_count:, assignments_archived: }` |
| `School::DetachTeacher` (**amendé**, ADR-0071) | inchangée | après `detach_teacher` : `promote_primary(teacher_id:)` | inchangés | inchangé |
| `School::ReinstateTeacher` (**amendé**, ADR-0071) | inchangée | `attach_teacher_within_cap(primary: schools_count.zero?)` ; ferme le départ | `:not_found` : pas de départ ouvert, ou anonymisé (« a un établissement » n'est plus un refus) ; **`:conflict` `base: [:schools_limit]`** au plafond | inchangé |

`Entities::Identity::AuditAction::ALL` gagne `teacher.left`.

Rejoindre ne crée **aucune** ligne `school_join_requests` (ADR-0083 §4.3) et ne change pas `teacher_profiles.joined_via` : la voie du second établissement est dans le journal d'audit.

### 4.5 Ports (gelés au Lot 0)

| Port | Méthode | Contrat |
|---|---|---|
| `Ports::School::SchoolRepositoryPort` | `attach_teacher_within_cap(teacher_id:, school_id:, primary:, cap:, at:)` (**nouveau**) | Verrouille la ligne `users` de l'enseignant (`FOR UPDATE`), compte ses lignes, insère. → `Result` succès \| `:conflict` `already_attached` \| `:conflict` `schools_limit` |
| | `school_ids_for(teacher_id:)` (**nouveau**) | `[Integer]`, le principal en premier, puis par `created_at`, `id` |
| | `promote_primary(teacher_id:)` (**nouveau**) | Si aucune ligne principale ne reste, marque la plus ancienne. → `Integer \| nil` (l'établissement principal) |
| | `attach_teacher`, `detach_teacher`, `primary_school_id_for` | Inchangés |
| `Ports::Identity::SessionRepositoryPort` | `set_current_school(id:, school_id:)` (**nouveau**) | `true` |
| `Ports::Identity::UserRepositoryPort` | `actor_for(user_id:, current_school_id: nil)` (**amendé**) | `Entities::Identity::Actor` (§4.2) |
| `Ports::Identity::InviteLinkRepositoryPort` | `resolve(token:)` | Inchangé |

`Entities::Identity::SessionState` gagne `current_school_id`. Nouvelle entité `Entities::School::TeacherSchools` (`MAX`, et `primary_for(rows)` si un use case en a besoin ; Ruby pur).

### 4.6 Lectures (CQRS, ADR-0006)

| Query | Changement |
|---|---|
| `Queries::School::TeacherSchoolsQuery#call(teacher_id:, current_school_id:)` (**nouvelle**) | Établissements de l'enseignant : `public_id`, nom, sigle, DRENA, `primary`, `current` ; une requête. Lue par le panneau du compte et « Mes établissements » |
| `TeacherHomeQuery`, `TeacherFollowUpsQuery`, `CatalogAssignmentTargetsQuery`, `TeacherAudienceQuery` | Reçoivent `school_id:` (l'établissement courant) et ne lisent que les classes de cet établissement |
| `ShellUserQuery`, `ProfileQuery` | La ligne de détail de l'enseignant nomme l'**établissement courant** |
| `ReferralQuery` (page « Inviter un collègue ») | ~~Nomme l'établissement principal~~ — remplacé au §11 (MET-8) : le lien de l'établissement courant et le lien de parrainage |
| `DepartedTeachersQuery` | Perd la condition « sans établissement principal » (`WITHOUT_SCHOOL`) : la condition devient « pas rattaché à **cet** établissement » |
| `DrenaSchoolsQuery`, `TeamDashboardQuery` (comptes par DRENA) | Comptent les **rattachements** (toutes les lignes `teacher_schools` non anonymisées), plus seulement le principal (memo, question 10). La ligne d'une DRENA reste la somme de ses établissements (critère RE-08 de l'ADR-0062) : un enseignant de deux établissements d'une même DRENA y compte deux fois |
| `SchoolTeachersQuery`, `StudentWorkQuery`, `SchoolActivityQuery`, `SchoolDetailQuery`, `GrowthMetricsQuery` | **Inchangées** : déjà bornées à un établissement, ou comptées une fois au national |

Aucune lecture de la direction ne joint `teacher_schools` sur un autre établissement que le sien. Le nombre de requêtes de chaque écran reste fixe (ADR-0067).

## 5. Conséquences

### 🟢 Positives

- Un enseignant enseigne dans deux ou trois établissements avec un seul compte, sans que les classes se mélangent.
- Aucune policy existante n'est réécrite : leur règle « même établissement » porte désormais sur l'établissement courant.
- Chaque direction garde exactement ses gestes de l'ADR-0071, sur sa part ; elle ne voit rien des autres établissements.
- Le lien d'invitation que la direction partage déjà sert aussi aux enseignants inscrits ailleurs : aucun nouvel outil pour elle.
- Un retrait de l'établissement principal ne met plus en attente un enseignant qui a un autre établissement.

### 🔴 Coûts consentis

- **Rattachement sans preuve, désormais multiplié par trois** : n'importe quel enseignant peut se rattacher à trois établissements actifs et voir leurs élèves dans les classes où il se déclare. C'est la règle de l'ADR-0083 jusqu'à la certification ; le plafond la borne, la direction peut retirer.
- **Un établissement courant par appareil** : l'enseignant peut se croire dans A alors que son autre appareil est dans B. Le nom de l'établissement courant est dans l'en-tête de chaque page (UDR-0098).
- **Une colonne de plus sur `sessions`**, lue à chaque requête dans la requête existante de l'acteur (pas de requête de plus).
- **Le lien personnel ne mène qu'au principal** : un enseignant ne peut pas inviter un collègue dans son second établissement par son lien ; il partage celui de la direction s'il l'a.
- **Le pilotage compte un enseignant dans chaque DRENA** où il est rattaché : la somme des DRENA peut dépasser le total national. Accepté sans note à l'écran (les libellés « N enseignants » ne changent pas) ; la définition « enseignant d'une DRENA » de l'ADR-0062 est amendée en conséquence au Lot D.
- **Quitter archive les devoirs actifs** de l'enseignant dans cet établissement, comme un retrait (ADR-0071) : un collègue de la même classe qui s'en servait doit le redonner.
- **La recherche de comptes de l'équipe** affiche encore le seul principal (dette, journal).

## 6. Notes d'implémentation

```ruby
# app/domain/entities/school/teacher_schools.rb
# 🧠 DOMAINE · Entities::School::TeacherSchools
# Rôle : plafond des établissements d'un enseignant
# ADR  : 0094
module Entities
  module School
    module TeacherSchools
      MAX = 3
    end
  end
end
```

```ruby
# app/infrastructure/repositories/identity/user_repository.rb (extrait)
def actor_for(user_id:, current_school_id: nil)
  user = Orm::User.find(user_id)
  Entities::Identity::Actor.new(user_id:, role: user.role.to_sym, team_role: user.team_role,
                                school_id: school_id_of(user, current_school_id))
end

# L'établissement courant d'un enseignant s'il y est encore rattaché, sinon son principal (ADR-0094 §4.2).
def school_id_of(user, current_school_id)
  return Orm::SchoolStaff.active.where(user_id: user.id).pick(:school_id) if user.role == "school_admin"

  Orm::TeacherSchool.where(teacher_id: user.id)
                    .where("teacher_schools.school_id = ? OR teacher_schools.primary", current_school_id)
                    .order(Arel.sql(Orm::TeacherSchool.sanitize_sql([ "(teacher_schools.school_id = ?) DESC", current_school_id ])))
                    .pick(:school_id)
end
```

```ruby
# app/infrastructure/repositories/school/school_repository.rb (extrait)
# Verrou de la ligne users : deux « Rejoindre » simultanés ne dépassent pas le plafond (même motif que attach_by_code, ADR-0077).
def attach_teacher_within_cap(teacher_id:, school_id:, primary:, cap:, at:)
  Orm::TeacherSchool.transaction(requires_new: true) do
    Orm::User.where(id: teacher_id).lock.pick(:id)
    return ::Shared::Result.failure(:conflict, errors: { base: [ :already_attached ] }) if Orm::TeacherSchool.exists?(teacher_id:, school_id:)
    return ::Shared::Result.failure(:conflict, errors: { base: [ :schools_limit ] }) if Orm::TeacherSchool.where(teacher_id:).count >= cap

    Orm::TeacherSchool.create!(teacher_id:, school_id:, primary:, created_at: at)
  end
  ::Shared::Result.success
end

def promote_primary(teacher_id:)
  current = primary_school_id_for(teacher_id:)
  return current if current

  oldest = Orm::TeacherSchool.where(teacher_id:).order(:created_at, :id).first
  oldest&.update_columns(primary: true)
  oldest&.school_id
end
```

## 7. Comment vérifier que la décision est respectée

- Tests de policy : `JoinSchoolWithCodePolicy` accepte 0, 1, 2 établissements et refuse 3 (`:schools_limit`) et une demande en attente ; `SwitchCurrentSchoolPolicy` refuse un établissement non rattaché ; `LeaveSchoolPolicy` refuse le dernier établissement.
- Test de repository : `actor_for` rend l'établissement courant s'il est rattaché, le principal sinon (session vers un établissement quitté), `nil` sans établissement ; `attach_teacher_within_cap` sous deux threads ne dépasse pas 3 ; `promote_primary` choisit le plus ancien.
- Tests de use case : retirer le principal d'un enseignant de deux établissements le laisse avec un principal et hors de l'écran d'attente ; réintégrer un enseignant qui a un autre établissement le rattache en secondaire ; quitter archive ses devoirs actifs de cet établissement et seulement de celui-là, sans départ.
- **Tests de refus de la direction** (porte de la V3) : sur « Accueil », « Enseignants », « Enseignants retirés », la confirmation du retrait et l'activité, la direction de A ne lit ni le nom, ni les classes, ni les devoirs de B pour un enseignant des deux.
- Test système : un enseignant de A ouvre connecté le lien de la direction de B, rejoint, se retrouve dans B ; son accueil ne montre que les classes de B ; il repasse dans A par le menu du compte.

## 8. Remplace, complète, amende

- **Amende l'ADR-0030** : la règle « une ligne par enseignant » est levée (trois au plus) ; « l'école visible est toujours l'école principale » devient « l'établissement visible est l'établissement courant, le principal par défaut » ; « seule l'équipe change l'école d'un enseignant » devient « l'enseignant rejoint et quitte lui-même un établissement ».
- **Amende l'ADR-0071** : `DetachTeacher` promeut un principal ; `ReinstateTeacher` rattache en secondaire un enseignant qui a déjà un établissement ; `DepartedTeachersQuery` montre aussi l'enseignant parti ailleurs ; `JoinSchoolWithCodePolicy` accepte un enseignant déjà rattaché, sous le plafond.
- **Amende l'ADR-0083** : un enseignant **connecté** qui ouvre un lien `/i/<jeton>` valide se voit proposer de rejoindre l'établissement au lieu d'être renvoyé vers son accueil ; la voie est écrite dans l'audit.
- **Complète l'ADR-0028** : `actor.school_id` d'un enseignant est l'établissement courant de sa session.
- **Amende l'ADR-0062** : « DRENA d'un enseignant : celle de son établissement principal » devient « un enseignant compte dans chaque établissement, donc dans chaque DRENA, où il est rattaché » ; le total national (`GrowthMetricsQuery`, enseignants distincts) ne change pas.
- **Complète l'ADR-0063** : le lien personnel mène à l'établissement principal ; aucun rattachement supplémentaire ne crée de demande.

## 9. Points à confirmer par le porteur

Tranchés par le porteur le 2026-10-16 ([memo](../../chantiers/multi-etablissements-enseignant/memo.md#réponses-du-porteur-2026-10-16)) : les recommandations des questions 1 à 8, 10 et 11 sont acceptées telles quelles. Question 9 : les matières de l'enseignant seront choisies **par établissement**, par le chantier `enseignant-plusieurs-matieres`, qui démarre après celui-ci. Point d'extension laissé : la ligne `teacher_schools` (un rattachement enseignant-établissement) est l'endroit où ce chantier rangera les matières ; aucune lecture ni aucun geste de ce chantier ne suppose une matière unique par établissement.

## 10. Amendement du 2026-10-16 — chaque établissement est un espace autonome (réponse MET-4)

> Réponse du porteur ([memo](../../chantiers/multi-etablissements-enseignant/memo.md#réponses-du-porteur-2026-10-16), Q3 et Q4) : « un compte, un numéro de téléphone, plusieurs établissements ; chaque établissement a son interface autonome et complète (classes, niveaux, annonces, à faire…) ; l'établissement courant cloisonne tout l'espace enseignant ». Elle **remplace la recommandation de la question 11** (la page d'une classe d'un autre établissement s'ouvrait) et complète les §4.3 et §4.6.

**Règle.** Tout ce que l'enseignant lit ou fait porte sur l'établissement courant. Une donnée d'un autre de ses établissements n'existe pas tant qu'il n'y est pas passé, même par son adresse.

| Où | Changement |
|---|---|
| `Policies::Classroom::ClassroomTeacher` (**nouveau**, Ruby pur) | Fait commun : `teaches?(actor, classroom)` = lié par `teacher_classrooms` **et** `classroom.school_id == actor.school_id` ; `elsewhere?` = lié, mais dans un autre établissement ; `OTHER_SCHOOL` = `:forbidden`, `errors: { base: [:other_school] }` |
| `TeachPolicy`, `ReadClassroomPolicy`, `FollowAssignmentPolicy`, `SetSessionDaysPolicy` (**amendées**, §4.3 disait « inchangées ») | `teaches?` remplace `teacher_ids.include?` ; `elsewhere?` → `OTHER_SCHOOL`. `AssignPolicy` suit `TeachPolicy` |
| `ManageClassroomMembersPolicy` (**amendée**) | `teaches?` ; hors établissement courant : `:not_found`, comme pour un inconnu |
| `RendersResult` | `OTHER_SCHOOL` → HTML : `303` vers l'accueil, toast « Cette classe n'est pas dans l'établissement où vous êtes. Changez d'établissement depuis votre compte. » ; Turbo Stream : le même toast en `403`. Aucun établissement n'est nommé |
| `ManageOwnPolicy` (annonces, **amendée**) | L'annonce d'un enseignant n'existe (`:not_found`) que dans l'établissement où il l'a écrite |
| Plafond des annonces (amende l'ADR-0081 §4.1) | `Message#cap_school_id` : une annonce à des classes (celle d'un enseignant) se compte **par établissement** ; les autres, par auteur comme avant. `MessageRepositoryPort#live_of(author_id:, now:, school_id: nil)` ; `AuthoredMessagesQuery#page` et `#departing` reçoivent `school_id:` pour l'enseignant |
| `JoinRequestsQuery#for_colleague(teacher_id:, school_id:)` | Les demandes de l'établissement courant (n'était que le principal) |
| Lectures déjà bornées au Lot A | Accueil (classes, niveaux, activités), sélection des classes, catalogue, cibles d'« Assigner », annonces reçues (`ReadableMessages`, par `reader.school_id`), « Mes annonces », formulaire d'annonce, en-tête et profil |

**Preuve.** Un test de non-fuite par écran (`test/controllers/school/current_school_isolation_test.rb`) : dans A, le contenu de la page (`main`) ne contient ni le nom de B, ni ses classes, ni ses niveaux, ni ses exercices à suivre, ni ses annonces ; les pages d'une classe de B, de son suivi et de son « Assigner » renvoient à l'accueil ; l'annonce de B est introuvable. Seul le panneau du compte nomme B : c'est le sélecteur.

**Point d'extension (chantier `enseignant-plusieurs-matieres`).** La ligne `teacher_schools` est le rattachement enseignant-établissement ; les matières par établissement s'y attachent (table fille `teacher_school_materials`, ou colonne). Toutes les lectures de l'enseignant reçoivent déjà `school_id:` (l'établissement courant) : la matière de l'établissement courant s'y lira sans changer leurs appelants. Ce chantier ne lit encore que `teacher_profiles.material_id`.

**Coût consenti.** Un lien partagé vers une classe de B, ouvert dans A, ne l'affiche pas : l'enseignant passe dans B depuis son compte, puis rouvre le lien.

## 11. Amendement du 2026-10-16 — deux liens d'invitation (réponse MET-8)

> Réponse du porteur (memo, Q8) : « deux liens séparés. "Inviter un collègue de mon établissement" : lien rattaché à l'établissement courant. "Inviter un autre collègue" : lien sans établissement (parrainage), le collègue choisit son établissement. » Elle **remplace** la recommandation de la question 8 (« le lien personnel mène toujours au principal »), l'amendement de `InviteColleaguePolicy` du §4.3 (`primary_school_id:`, retiré) et le coût « Le lien personnel ne mène qu'au principal » du §5. Elle complète l'ADR-0063 et l'ADR-0083 §4.1.

**Données.** Migration `teacher_schools.invite_token` (`varchar(12)`, défaut tiré par la base comme `referral_token`, index unique, contrainte `^[0-9a-f]{12}$`) : **un lien par rattachement enseignant-établissement**. `teacher_profiles.referral_token` devient le **lien de parrainage**, sans établissement. Le jeton d'un établissement quitté disparaît avec sa ligne : son lien devient inconnu.

**Résolution** (`InviteLinkRepository#resolve`, ordre ADR-0083 §5 prolongé) : 1. `teacher_schools.invite_token` → l'établissement de la ligne, voie `colleague`, le collègue en parrain ; 2. `teacher_profiles.referral_token` → `InviteLink(sponsor: true, school_id: nil)`, valide tant que le collègue n'est pas anonymisé ; 3. direction ; 4. équipe.

| Où | Règle |
|---|---|
| `InviteLinkRepositoryPort::InviteLink` | `+ sponsor` (défaut `false`) ; `valid?` : un parrainage vaut par son parrain, un autre lien par son établissement actif |
| `RegisterTeacher` | Lien d'établissement : l'établissement du lien (inchangé), parrainage `source: "link"`. **Parrainage** : l'établissement choisi (DRENA puis établissement, mêmes erreurs neutres), voie `colleague`, parrainage `source: "sponsor"` (valeur déjà admise par `referrals_source_values`) avec l'établissement choisi |
| `JoinSchoolWithCode` (lien ouvert connecté) | Un parrainage ne rattache à rien : `:invalid` `invite_invalid` ; la page dit « Ce lien sert à inscrire un nouveau collègue » |
| `InviteColleaguePolicy#call(actor:, school:)` | Revient à sa forme d'origine : `school` est l'**établissement courant** (`actor.school_id`), actif |
| `ReferralQuery#call(teacher_id:, school_id:)` | `Row(school_name, school_token, referral_token, referred_count)` : le lien de l'établissement courant et le lien de parrainage ; le compteur compte tous les filleuls |
| `RecordReferralShare` | Inchangé (sa forme d'origine) : un partage compté, quel que soit le lien |

**Écrans** : UDR-0098 §3.6.

**Coûts consentis.** Un lien d'établissement déjà partagé cesse de marcher si l'enseignant quitte cet établissement. Les liens « personnels » déjà partagés avant ce chantier (le jeton du profil) deviennent des liens de parrainage : l'invité choisit son établissement au lieu de l'avoir rempli ; Lnclass n'est pas encore lancé (réponse DIR-4 du porteur), aucun lien n'a circulé.

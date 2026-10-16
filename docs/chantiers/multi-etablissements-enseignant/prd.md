# PRD — Un enseignant dans plusieurs établissements

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
>
> **Écrit sur les recommandations du memo** (questions 1 à 8, 10 et 11), **acceptées par le porteur le 2026-10-16** ; la 9 relève de `enseignant-plusieurs-matieres` (matières choisies par établissement, chantier suivant).

## 1. Contexte

Un enseignant n'a aujourd'hui qu'un établissement, alors que la table `teacher_schools` en accepte plusieurs ([memo](memo.md)). Ce chantier lui permet d'en rejoindre trois au plus, par le lien d'invitation d'un établissement ou par la liste de sa DRENA, de passer de l'un à l'autre et d'en quitter un. Chaque direction continue de gérer **sa part** de l'enseignant, sans rien voir des autres établissements.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher (rattaché) | Rejoindre un établissement actif de son choix (lien `/i/<jeton>` ouvert connecté, ou DRENA → établissement) tant qu'il en a moins de 3 ; passer d'un établissement à l'autre ; quitter un établissement s'il lui en reste un autre ; tout ce qu'il fait aujourd'hui, **dans l'établissement courant** | Rejoindre un établissement qui l'a retiré (départ ouvert) ; dépasser 3 établissements ; quitter son dernier établissement ; se déclarer dans une classe, publier une annonce ou inviter hors de l'établissement courant (ou du principal pour l'invitation) |
| Teacher (sans établissement) | Inchangé : écran d'attente, DRENA → établissement (ADR-0071, 0083) | — |
| SchoolAdmin | Voir, retirer et réintégrer un enseignant **dans son établissement** (ADR-0071), même s'il en a d'autres ; partager son lien d'invitation | Voir quoi que ce soit d'un autre établissement de l'enseignant ; rattacher un enseignant par son numéro |
| Team | Voir tous les rattachements (fiche d'établissement, badge « Établissement secondaire ») ; pilotage par établissement et par DRENA | Retirer un enseignant (inchangé, ADR-0071) |
| Student | Inchangé | — |

Règles d'autorisation : `JoinSchoolWithCodePolicy` (amendée), `SwitchCurrentSchoolPolicy`, `LeaveSchoolPolicy` (nouvelles), `ManageSchoolTeachersPolicy` (inchangée). `actor.school_id` d'un enseignant est son **établissement courant** ([ADR-0094](../../decisions/adr/0094-enseignant-multi-etablissements-et-etablissement-courant.md) §4.2).

## 3. Parcours utilisateur

### Chemin nominal — rejoindre par le lien de la direction

1. M. Koné enseigne au Lycée moderne d'Abobo (A). Il commence des heures au Collège Saint-Michel (B), dont la direction lui envoie son lien d'invitation sur WhatsApp.
2. Il ouvre le lien, connecté : « Rejoindre Collège Saint-Michel ? » (UDR-0099 §3.4). Il confirme.
3. Il arrive sur la sélection des classes de B, avec le toast « Vous avez rejoint Collège Saint-Michel. Sélectionnez vos classes. ». Il se déclare en 4ème 2.
4. Son accueil montre B et ses classes de B seulement, avec « Collège Saint-Michel · Changer ».
5. Le lendemain, il ouvre le panneau du compte, touche « Lycée moderne d'Abobo » : il est dans A, ses classes de A seulement.
6. La direction de B voit M. Koné dans « Enseignants » avec « 4ème 2 ». La direction de A le voit avec ses classes de A. Aucune des deux ne voit l'autre établissement.

### Chemin nominal — ajouter depuis « Mes établissements »

1. Depuis le panneau du compte, « Mes établissements » : une carte, A, « Principal », « Vous êtes ici ».
2. « Ajouter un établissement » : DRENA, puis établissement, « Rejoindre l'établissement ».
3. Même arrivée qu'au parcours précédent.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Lien d'un établissement qui l'a retiré | Carte « Rejoindre ? » ; au `POST`, « Ce lien n'est plus valable » ; rien n'est écrit |
| Déjà dans l'établissement du lien | « Vous êtes déjà dans <nom> », bouton « Aller dans cet établissement » |
| Trois établissements déjà | Lien : « Vous avez déjà 3 établissements » ; page : la carte « Ajouter » est remplacée par une phrase |
| Lien invalide (inconnu, établissement inactif, collègue anonymisé) | « Ce lien n'est plus valable », bouton « Mes établissements » |
| Quitter un établissement secondaire | Confirmation ; classes retirées et devoirs actifs archivés **dans cet établissement** ; il peut le rejoindre de nouveau |
| Quitter l'établissement principal | Même chose ; le plus ancien des restants devient principal |
| Dernier établissement | Pas de menu « Quitter » |
| La direction de A retire M. Koné, A étant son principal | Il garde B, qui devient principal ; pas d'écran d'attente ; B ne voit rien changer |
| La direction de A réintègre M. Koné, qui a B | Rattaché à A en plus de B (secondaire) ; au plafond, toast neutre et rien n'est écrit |
| Session sur un établissement quitté ou retiré | La page suivante est dans le principal, sans message |
| Une classe de B ouverte alors qu'il est dans A | La page s'ouvre, nomme B ; se déclarer ou écrire une annonce y est refusé avec « Changez d'établissement depuis votre compte » |
| Compte élève, direction ou équipe connecté qui ouvre `/i/<jeton>` | Renvoi vers son accueil, inchangé |

## 4. Critères d'acceptation

```gherkin
# Rejoindre (UDR-0099)

Scénario: ME-01 — rejoindre par le lien de la direction, connecté
  Étant donné un enseignant rattaché au seul établissement A
  Et le lien d'invitation de la direction de l'établissement actif B
  Quand il ouvre ce lien et confirme « Rejoindre l'établissement »
  Alors il a deux rattachements, A principal et B secondaire
  Et sa session est dans B
  Et le journal d'audit contient « school.changed » avec change « teacher_joined » et via « direction » pour B

Scénario: ME-02 — rejoindre par « Ajouter un établissement »
  Étant donné un enseignant rattaché au seul établissement A
  Quand il choisit la DRENA de B, puis B, dans « Mes établissements »
  Alors il est rattaché à B en secondaire et arrive sur la sélection des classes de B

Scénario: ME-03 — jamais l'établissement qui l'a retiré
  Étant donné un enseignant de A retiré de B par la direction de B
  Quand il tente de rejoindre B par le lien de B ou par la liste de sa DRENA
  Alors il reçoit l'erreur neutre et n'est pas rattaché à B

Scénario: ME-04 — trois établissements au plus
  Étant donné un enseignant rattaché à A, B et C
  Quand il tente de rejoindre D
  Alors il reçoit « Vous avez atteint 3 établissements » et n'est pas rattaché à D
  Et deux « Rejoindre » simultanés d'un enseignant qui en a deux ne lui en laissent jamais plus de 3

Scénario: ME-05 — déjà dans l'établissement
  Étant donné un enseignant rattaché à A et B
  Quand il ouvre le lien de B
  Alors il voit « Vous êtes déjà dans B » et aucun rattachement n'est écrit

Scénario: ME-06 — aucune demande en attente
  Quand un enseignant rattaché rejoint un autre établissement
  Alors aucune ligne « school_join_requests » n'est créée
  Et sa voie d'arrivée (« joined_via ») ne change pas

# Établissement courant (UDR-0098)

Scénario: ME-07 — l'accueil ne montre que l'établissement courant
  Étant donné un enseignant déclaré en « 6ème 1 » de A et en « 6ème 1 » de B
  Et sa session est dans B
  Quand il ouvre son accueil, son catalogue ou « Assigner un exercice »
  Alors il ne voit que la « 6ème 1 » de B et les niveaux enseignés dans B

Scénario: ME-08 — changer d'établissement
  Étant donné un enseignant dans A, rattaché à A et B
  Quand il touche « B » dans le panneau du compte
  Alors il arrive sur son accueil avec « Vous êtes dans B. »
  Et la ligne de détail du panneau nomme B

Scénario: ME-09 — un seul établissement, rien ne change
  Étant donné un enseignant rattaché au seul établissement A
  Alors son panneau n'a pas de rubrique « Établissement »
  Et son accueil n'a pas de lien « Changer »

Scénario: ME-10 — session vers un établissement quitté
  Étant donné une session dans B
  Quand l'enseignant n'est plus rattaché à B (il l'a quitté sur un autre appareil, ou la direction de B l'a retiré)
  Alors la requête suivante de cette session est dans son établissement principal
  Et aucune page ne montre de donnée de B

Scénario: ME-11 — un établissement courant par appareil
  Étant donné deux sessions du même enseignant
  Quand il passe dans B sur la première
  Alors la seconde reste dans son établissement

Scénario: ME-12 — gestes liés à l'établissement courant
  Étant donné un enseignant dans A, déclaré dans une classe de B
  Quand il ouvre la page de cette classe
  Alors elle s'affiche et nomme B
  Et se déclarer dans une autre classe de B, ou écrire une annonce à une classe de B, est refusé

# Quitter (UDR-0099)

Scénario: ME-13 — quitter un établissement secondaire
  Étant donné un enseignant de A et B, déclaré dans deux classes de B et une de A, avec un devoir actif dans chacune
  Quand il quitte B et confirme
  Alors il n'est plus rattaché à B ni déclaré dans ses classes
  Et ses devoirs actifs de B sont archivés, celui de A reste actif
  Et aucun départ n'est enregistré : il peut rejoindre B de nouveau
  Et le journal d'audit contient « teacher.left » pour B

Scénario: ME-14 — quitter l'établissement principal
  Étant donné un enseignant de A (principal), B puis C
  Quand il quitte A
  Alors B devient son établissement principal

Scénario: ME-15 — jamais le dernier
  Étant donné un enseignant d'un seul établissement
  Alors « Mes établissements » n'a pas de menu « Quitter »
  Et un « DELETE » forgé est refusé et ne change rien

Scénario: ME-16 — lien invalide ouvert connecté
  Quand un enseignant connecté ouvre un lien dont le jeton est inconnu, d'un établissement inactif ou d'un collègue anonymisé
  Alors il voit « Ce lien n'est plus valable » et rien n'est écrit

# Chaque direction ne voit que sa part (UDR-0100)

Scénario: ME-17 — « Enseignants » de la direction
  Étant donné M. Koné déclaré en « 3ème 1 » de A et en « 4ème 2 » de B
  Quand la direction de A ouvre « Enseignants »
  Alors elle voit M. Koné avec « 3ème 1 » seulement
  Et la page ne contient ni le nom de B, ni « 4ème 2 », ni aucune mention d'un autre établissement
  Et la direction de B voit M. Koné avec « 4ème 2 » seulement

Scénario: ME-18 — accueil, niveaux, activité de la direction
  Étant donné M. Koné qui a un devoir actif dans une classe de B
  Quand la direction de A ouvre son accueil, la page d'un niveau, une classe ou l'activité
  Alors aucun devoir, aucune classe et aucun événement de B n'y figure

Scénario: ME-19 — confirmation du retrait
  Quand la direction de A ouvre « Retirer » pour M. Koné
  Alors la modale ne mentionne ni B ni le fait qu'il ait un autre établissement

Scénario: ME-20 — retrait de l'établissement principal
  Étant donné M. Koné, principal A, secondaire B
  Quand la direction de A le retire
  Alors il reste rattaché à B, qui devient principal
  Et à sa requête suivante il est dans B, pas sur l'écran d'attente
  Et ses déclarations et devoirs de B sont intacts
  Et la direction de B voit M. Koné comme avant

Scénario: ME-21 — réintégrer un enseignant parti ailleurs
  Étant donné M. Koné retiré de A, rattaché depuis à B
  Quand la direction de A ouvre « Enseignants retirés »
  Alors M. Koné y figure, sans mention de B
  Quand elle touche « Réintégrer »
  Alors il est rattaché à A en secondaire et le départ est clos

Scénario: ME-22 — réintégrer au plafond
  Étant donné M. Koné retiré de A, rattaché depuis à B, C et D
  Quand la direction de A touche « Réintégrer »
  Alors elle voit « ne peut pas être réintégré pour l'instant : il a atteint le nombre d'établissements autorisé »
  Et rien n'est écrit, la ligne reste

# Équipe

Scénario: ME-23 — pilotage par établissement et par DRENA
  Étant donné M. Koné rattaché à A et B, deux établissements de la même DRENA
  Quand l'équipe ouvre le pilotage filtré sur cette DRENA
  Alors A et B comptent chacun M. Koné
  Et la ligne de la DRENA est la somme de ses établissements

Scénario: ME-24 — national et fiche d'établissement
  Alors le nombre national d'enseignants actifs compte M. Koné une fois
  Et la fiche de B côté équipe montre M. Koné avec le badge « Établissement secondaire »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::School::TeacherSchools::MAX` ; `SessionState#current_school_id` ; `AuditAction` + `teacher.left` ; policies `JoinSchoolWithCodePolicy` et `InviteColleaguePolicy` (amendées), `SwitchCurrentSchoolPolicy`, `LeaveSchoolPolicy` ; use cases `JoinSchoolWithCode` (amendé), `SwitchCurrentSchool`, `LeaveSchool`, `DetachTeacher` et `ReinstateTeacher` (amendés), `ResolveSession` (passe la session) ; DTO `SchoolInviteJoinInput` ; ports `SchoolRepositoryPort` (+ `attach_teacher_within_cap`, `school_ids_for`, `promote_primary`), `SessionRepositoryPort` (+ `set_current_school`), `UserRepositoryPort#actor_for(current_school_id:)` |
| Infrastructure | Migration `sessions.current_school_id` ; `SchoolRepository`, `SessionRepository`, `UserRepository` ; queries `TeacherSchoolsQuery` (nouvelle), `TeacherHomeQuery`, `TeacherFollowUpsQuery`, `CatalogAssignmentTargetsQuery`, `TeacherAudienceQuery`, `ShellUserQuery`, `ProfileQuery`, `ReferralQuery`, `DepartedTeachersQuery`, `DrenaSchoolsQuery`, `TeamDashboardQuery` |
| Delivery | `School::CurrentSchoolsController#update`, `School::TeacherSchoolsController#index/create/destroy`, `Identity::TeacherRegistrationsController#invite` (connecté), `ColleagueInvitation` (principal) ; routes dans `config/routes/school.rb` |
| UI | Panneau du compte, accueil enseignant, sélection des classes, page d'une classe (UDR-0098) ; `school/teacher_schools/index`, `_join_fields`, `identity/teacher_registrations/join` (UDR-0099) ; `school_admin/schools/_link` (UDR-0100) |

## 6. Décisions rattachées

- [ADR-0094](../../decisions/adr/0094-enseignant-multi-etablissements-et-etablissement-courant.md) — établissement courant par session, rattachement par l'enseignant, plafond 3, amende 0030, 0062, 0071, 0083 (Accepté, 2026-10-16).
- [UDR-0098](../../decisions/udr/0098-etablissement-courant-de-l-enseignant.md) — établissement courant de l'enseignant (Accepté, 2026-10-16).
- [UDR-0099](../../decisions/udr/0099-mes-etablissements-de-l-enseignant.md) — « Mes établissements » et lien ouvert connecté (Accepté, 2026-10-16).
- [UDR-0100](../../decisions/udr/0100-enseignant-partage-vu-par-chaque-direction.md) — l'enseignant partagé vu par chaque direction (Accepté, 2026-10-16).

## 7. Mesures

Budgets de l'[ADR-0067](../../decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md) : aucun écran ne gagne de requête par établissement.

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes pour construire l'acteur d'un enseignant | 2 (`users`, `teacher_schools`) | 2 | |
| Requêtes de l'accueil enseignant | à mesurer au Lot A | inchangé, + 1 au plus (établissements du panneau) | |
| Requêtes de « Enseignants » (direction) | 3 | 3 | |
| p95 serveur de l'accueil enseignant, jeu `script/perf/dataset.rb` | à mesurer au Lot A | < 100 ms | |

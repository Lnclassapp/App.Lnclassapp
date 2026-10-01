# PRD — La direction gère son établissement

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

| | |
|---|---|
| **Chantier** | `gestion-etablissement-direction` — cycle feature, programme `refonte-application`, vague V2 |
| **Memo** | [`memo.md`](memo.md) (grill du porteur, 2026-10-01) |
| **Part de** | `espace-direction-simple`, en production ([ADR-0065](../../decisions/adr/0065-espace-direction-simple-en-lecture-seule.md), [UDR-0052](../../decisions/udr/0052-espace-direction-simple.md)) |
| **Décisions** | §6 |

## 1. Contexte

La direction d'un établissement lit aujourd'hui ses enseignants et le travail de ses élèves, sans rien pouvoir faire. Ce chantier lui donne trois gestes sur son **seul** établissement, sans fonction ni second facteur (grill 2) : **partager et changer le lien d'inscription des enseignants**, **ajouter ou retirer une classe d'un niveau**, **retirer un enseignant et le réintégrer**. Un enseignant retiré voit ses devoirs actifs archivés, et peut rejoindre un autre établissement par son code, jamais revenir seul dans celui qui l'a retiré.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Direction** (`school_admin` rattaché à un établissement **actif**) | Lire le lien d'inscription des enseignants, le copier, le partager, le changer ; « + » et « − » sur un niveau ; retirer un enseignant ; voir les enseignants retirés et les réintégrer ; lire ses deux pages actuelles | Valider un enseignant en attente ; créer une classe au nom libre, modifier une classe ; changer un élève de classe ; inviter ou retirer un membre de la direction ; toucher un autre établissement |
| **Direction d'un établissement inactif ou en brouillon** | Lire ses pages actuelles et le lien (en lecture) | Tout geste : « Changer le lien », « + », « − », retirer, réintégrer |
| **Équipe** (`team`) | Inchangée : « + », « − », régénérer le code depuis la fiche | Retirer ou réintégrer un enseignant (grill 9) |
| **Enseignant** rattaché | Inchangé | Accéder à l'espace direction |
| **Enseignant sans établissement** (retiré, ou demande approuvée puis retiré), sans demande en attente | Saisir le code d'un établissement actif depuis l'écran d'attente et le rejoindre | Rejoindre l'établissement qui l'a retiré, tant qu'il n'est pas réintégré |
| **Élève**, **Parent** | — (rien ne change) | Accéder à l'espace direction |

**Règles d'autorisation** : `Policies::School::ManageSchoolStructurePolicy` (équipe sur tout établissement, ou direction de **cet** établissement s'il est actif) pour « + », « − » et le changement de lien ; `Policies::School::ManageSchoolTeachersPolicy` (direction de **cet** établissement actif, jamais l'équipe) pour retirer et réintégrer ; `Policies::School::JoinSchoolWithCodePolicy` (enseignant sans établissement ni demande en attente). `ManageSchoolPolicy` et `ManageClassroomPolicy` ne changent pas. Détail : [ADR-0071](../../decisions/adr/0071-gestes-de-la-direction-sur-son-etablissement.md).

## 3. Parcours utilisateur

### Chemin nominal

1. La direction ouvre **Établissement** (troisième entrée de sa navigation) : nom de l'établissement, carte « Inviter vos enseignants » avec le lien `/e/<code>`, « Copier le lien », « Partager sur WhatsApp ».
2. Elle partage le lien dans le groupe des professeurs. Un enseignant l'ouvre et s'inscrit, établissement déjà rempli (inchangé).
3. Sur la même page, bloc « Classes par niveau » : elle ajoute une « 6ème 5 » par le « + » de la ligne « 6ème ».
4. Un enseignant quitte l'établissement : sur **Enseignants**, menu ⋮ de sa ligne → « Retirer de l'établissement » → confirmation. Ses devoirs actifs sont archivés ; classes, élèves et résultats restent.
5. À sa requête suivante, l'enseignant retiré voit l'écran d'attente « Vous n'êtes rattaché à aucun établissement » et un champ « Code d'établissement ». Il saisit le code de son nouvel établissement et y arrive.
6. Retiré par erreur, un autre enseignant est réintégré par la direction depuis **Enseignants retirés** ; il retrouve l'établissement et recoche ses classes.
7. Le lien a fui : « Changer le lien » → confirmation. L'ancien lien répond « Code d'établissement invalide » ; les enseignants inscrits restent.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Établissement inactif ou en brouillon | Lien affiché en lecture ; aucun bouton « Changer le lien », « + », « − », « Retirer », « Réintégrer » ; requête forgée → 403 |
| Enseignant d'un autre établissement, classe d'un autre établissement | 404 ; rien n'est écrit |
| « − » sur une classe qui a servi, ou qui n'est plus la dernière | Toast « Cette classe ne peut pas être retirée : … » (motifs de l'équipe) ; rien n'est écrit |
| « + » sur un niveau fermé au barème, nom déjà pris en même temps | Toast au motif (textes de l'équipe) |
| Enseignant retiré qui saisit le code de l'établissement qui l'a retiré | « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. » (même message qu'un code inconnu) |
| Code inconnu, établissement inactif ou en brouillon | Même message |
| Plus de 10 essais de code par minute | 429 « Trop de tentatives » |
| Réintégrer un enseignant qui a rejoint un autre établissement entre-temps | Il n'est plus dans la liste ; requête forgée → 404 |
| Retirer un enseignant déjà retiré (deux onglets) | 404 ; toast « Introuvable. » |
| Aucun enseignant retiré | État vide « Aucun enseignant retiré » |
| Équipe sur une page de l'espace direction | 403 (inchangé) |

## 4. Critères d'acceptation

« La direction de A » : un compte `school_admin` rattaché à l'établissement actif A ; B est un autre établissement actif. **Chaque geste a son test de refus inter-établissements** (GD-06, GD-11, GD-16, GD-20) et son **refus sur établissement inactif** (GD-07, GD-12, GD-17). 27 critères.

### 4.1 Accès et navigation — [Lot 0]

```gherkin
Scénario: GD-01 — trois destinations pour la direction
  Étant donné la direction de A connectée
  Quand elle ouvre « Travail des élèves »
  Alors la navigation affiche « Travail des élèves », « Enseignants » et « Établissement », toutes actives

Scénario: GD-02 — la page Établissement est réservée à la direction rattachée
  Étant donné un élève, un enseignant et un membre de l'équipe, chacun connecté
  Quand chacun ouvre « Établissement » de l'espace direction
  Alors chacun reçoit 403
  Et une direction sans établissement est renvoyée vers l'écran d'attente
```

### 4.2 Lien d'inscription des enseignants — [Lot A]

```gherkin
Scénario: GD-03 — la direction lit et partage le lien
  Étant donné la direction de A, dont le code est « K7M-4QZ »
  Quand elle ouvre « Établissement »
  Alors elle voit le lien « /e/k7m4qz », « Copier le lien » et « Partager sur WhatsApp »
  Et le message WhatsApp contient le lien et le nom de A

Scénario: GD-04 — la direction change le lien
  Étant donné la direction de A
  Quand elle choisit « Changer le lien » et confirme
  Alors un nouveau lien s'affiche, sans rechargement de la page
  Et l'ancien lien affiche « Code d'établissement invalide »
  Et les enseignants déjà rattachés à A le restent
  Et le journal enregistre « school.changed » avec « code_regenerated » et l'auteur

Scénario: GD-05 — l'équipe change toujours le code depuis la fiche
  Étant donné un membre de l'équipe sur la fiche de A
  Quand il régénère le code
  Alors le code de A change

Scénario: GD-06 — pas de changement de lien pour un autre établissement
  Étant donné la direction de A
  Quand le cas d'usage de régénération reçoit l'établissement B
  Alors il répond « forbidden »
  Et le code de B n'a pas changé

Scénario: GD-07 — établissement inactif : lien en lecture seule
  Étant donné la direction de l'établissement inactif C
  Quand elle ouvre « Établissement »
  Alors elle voit le lien sans le bouton « Changer le lien »
  Et la régénération forgée répond 403
```

### 4.3 Classes par niveau — [Lot B]

```gherkin
Scénario: GD-08 — la direction ajoute la classe suivante
  Étant donné la direction de A, établissement public qui a « 6ème 1 » à « 6ème 4 » cette année
  Quand elle clique « + » sur la ligne « 6ème »
  Alors « 6ème 5 » est créée dans A avec un code d'adhésion
  Et la ligne affiche 5, sans rechargement de la page
  Et le journal enregistre « school.changed » avec « classroom_added »

Scénario: GD-09 — la direction retire la dernière classe jamais utilisée
  Étant donné « 6ème 5 » sans élève, sans enseignant ni devoir
  Quand la direction clique « − » sur la ligne « 6ème » et confirme
  Alors « 6ème 5 » n'existe plus
  Et la ligne affiche 4

Scénario: GD-10 — une classe qui a servi ne se retire pas
  Étant donné « 6ème 4 », dernière classe du niveau, avec un élève
  Quand la direction clique « − » et confirme
  Alors elle lit le motif de refus de l'équipe
  Et « 6ème 4 » existe toujours

Scénario: GD-11 — ni ajout ni retrait dans un autre établissement
  Étant donné la direction de A
  Quand le cas d'usage d'ajout, puis celui de retrait, reçoit l'établissement B
  Alors chacun répond « forbidden »
  Et les classes de B n'ont pas changé

Scénario: GD-12 — établissement inactif : ni « + » ni « − »
  Étant donné la direction de l'établissement inactif C
  Quand elle ouvre « Établissement »
  Alors aucun bouton « + » ni « − » n'est affiché
  Et l'ajout forgé répond 403

Scénario: GD-13 — l'équipe garde « + » et « − »
  Étant donné un membre de l'équipe sur la fiche de A
  Quand il ajoute puis retire une classe
  Alors les deux gestes réussissent
```

### 4.4 Retirer un enseignant — [Lot C]

```gherkin
Scénario: GD-14 — la direction retire un enseignant, ses devoirs actifs sont archivés
  Étant donné un enseignant de A déclaré dans « 6ème 1 » et « 6ème 2 », auteur de 3 devoirs actifs et d'1 devoir archivé, avec des sessions d'élèves
  Quand la direction de A le retire et confirme
  Alors il n'est plus rattaché à A ni déclaré dans ses classes
  Et ses 3 devoirs actifs sont archivés, par la direction, et l'archivé le reste
  Et les classes, les élèves et les sessions restent
  Et son compte reste actif
  Et la ligne disparaît de « Enseignants » sans rechargement
  Et le journal enregistre « teacher.detached » avec 3 devoirs archivés

Scénario: GD-15 — rien ne bouge dans un autre établissement
  Étant donné le même enseignant, auteur d'un devoir actif dans une classe de B où il a été déclaré auparavant
  Quand la direction de A le retire
  Alors le devoir de la classe de B reste actif

Scénario: GD-16 — pas de retrait dans un autre établissement
  Étant donné la direction de A et un enseignant de B
  Quand elle envoie son retrait
  Alors elle reçoit 404
  Et le cas d'usage de retrait répond « forbidden » s'il reçoit l'établissement B
  Et l'enseignant reste rattaché à B

Scénario: GD-17 — établissement inactif, ou par l'équipe : pas de retrait
  Étant donné la direction de l'établissement inactif C, et un membre de l'équipe
  Quand chacun envoie le retrait d'un enseignant de C
  Alors la direction reçoit 403 et l'équipe reçoit 403
  Et aucun menu « Retirer de l'établissement » n'est affiché à la direction de C

Scénario: GD-18 — un enseignant en attente n'est pas retirable
  Étant donné un enseignant inscrit sans code, en attente de validation pour A
  Quand la direction de A envoie son retrait
  Alors elle reçoit 404
```

### 4.5 Après le retrait : rejoindre ailleurs, réintégrer — [Lot D]

```gherkin
Scénario: GD-19 — la direction réintègre un enseignant retiré
  Étant donné un enseignant retiré de A, sans établissement depuis
  Quand la direction de A ouvre « Enseignants retirés » et clique « Réintégrer »
  Alors il est de nouveau rattaché à A, sans aucune classe déclarée
  Et ses devoirs archivés au retrait restent archivés
  Et il disparaît de « Enseignants retirés »
  Et le journal enregistre « teacher.reinstated »

Scénario: GD-20 — pas de réintégration d'un enseignant d'un autre établissement
  Étant donné la direction de A et un enseignant retiré de B
  Quand elle envoie sa réintégration
  Alors elle reçoit 404
  Et le cas d'usage répond « forbidden » s'il reçoit l'établissement B

Scénario: GD-21 — la liste des enseignants retirés
  Étant donné 2 enseignants retirés de A, dont 1 qui a rejoint B depuis, et 1 enseignant retiré de B
  Quand la direction de A ouvre « Enseignants retirés »
  Alors elle voit 1 enseignant, avec la date de son retrait
  Et sans enseignant retiré, elle lit « Aucun enseignant retiré »

Scénario: GD-22 — l'enseignant retiré voit l'écran d'attente avec le code
  Étant donné un enseignant retiré de A, encore connecté
  Quand il ouvre son accueil
  Alors il est renvoyé vers l'écran d'attente
  Et il lit « Vous n'êtes rattaché à aucun établissement » et le champ « Code d'établissement »

Scénario: GD-23 — il rejoint un autre établissement par son code
  Étant donné un enseignant retiré de A
  Quand il saisit le code de l'établissement actif B
  Alors il est rattaché à B et arrive sur le choix de ses classes
  Et le journal enregistre « school.changed » avec « teacher_joined »

Scénario: GD-24 — il ne revient pas seul dans l'établissement qui l'a retiré
  Étant donné un enseignant retiré de A
  Quand il saisit le code de A, puis un code inconnu, puis celui d'un établissement inactif
  Alors il lit trois fois « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. »
  Et il reste sans établissement

Scénario: GD-25 — trop d'essais de code
  Étant donné un enseignant retiré
  Quand il fait une 11ᵉ tentative dans la minute
  Alors il reçoit 429 « Trop de tentatives »

Scénario: GD-26 — un enseignant en attente ne rejoint pas par code
  Étant donné un enseignant inscrit sans code, dont la demande est en attente
  Quand il envoie un code d'établissement valide
  Alors il reçoit 403
  Et sa demande reste en attente

Scénario: GD-27 — réintégré, il retrouve l'accès par le lien comme les autres
  Étant donné un enseignant retiré de A puis réintégré, puis retiré de nouveau
  Quand il saisit le code de A
  Alors il lit « Code d'établissement invalide »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Policies nouvelles : `School::ManageSchoolStructurePolicy`, `School::ManageSchoolTeachersPolicy`, `School::JoinSchoolWithCodePolicy`. Entité nouvelle : `School::TeacherDeparture`. Port nouveau : `School::TeacherDepartureRepositoryPort`. Méthodes ajoutées : `SchoolRepositoryPort#detach_teacher`, `TeachingRepositoryPort#withdraw_all_in_school`, `AssignmentRepositoryPort#archive_all_by_teacher_in_school`. Use cases nouveaux : `School::DetachTeacher`, `School::ReinstateTeacher`, `School::JoinSchoolWithCode`. Modifiés (policy appelée avec l'établissement) : `Classroom::AddLevelClassroom`, `Classroom::RemoveLevelClassroom`, `School::RegenerateSchoolCode`. `Identity::AuditAction` (+2) |
| Infrastructure | Migration : table `teacher_school_departures`. `Orm::TeacherSchoolDeparture`, `Repositories::School::TeacherDepartureRepository`. Queries : `School::OwnSchoolQuery` (nouvelle), `School::DepartedTeachersQuery` (nouvelle) ; `School::SchoolTeachersQuery` (+ `public_id`) |
| Delivery | Routes de l'espace direction et de l'écran d'attente. `SchoolAdmin::SchoolsController`, `SchoolLinksController`, `LevelClassroomsController`, `DepartedTeachersController`, `TeacherReinstatementsController` ; `SchoolAdmin::TeachersController#destroy` ; `Identity::PendingSchoolJoinsController`. Modifiés : `Teams::LevelClassroomsController`, `Teams::SchoolCodesController` (nouvelle policy) |
| UI | Vues `school_admin/schools/show`, `school_links/update`, `level_classrooms/*`, `departed_teachers/index`, `teacher_reinstatements/create` ; `school_admin/teachers/index` (menu ⋮ et confirmation) ; `identity/pending_accounts/show` (formulaire de code) ; partiel `shared/_level_classrooms` repris par l'équipe ; `NavigationHelper` (3ᵉ destination) |

## 6. Décisions rattachées

- [ADR-0071](../../decisions/adr/0071-gestes-de-la-direction-sur-son-etablissement.md) — Les gestes de la direction sur son établissement (Proposé). Amende ADR-0065, ADR-0057, ADR-0059, ADR-0030.
- [UDR-0056](../../decisions/udr/0056-gestes-de-la-direction.md) — Les gestes de la direction (Proposé). Amende UDR-0052, UDR-0046 (bloc partagé), UDR-0050 (écran d'attente).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Gestes d'un établissement faits par l'équipe à la place de la direction (lien, classes, départ d'un enseignant) | tous | aucun | |
| Requêtes de « Établissement » et de « Enseignants retirés » | — | nombre fixe, indépendant du nombre de classes ou d'enseignants | |

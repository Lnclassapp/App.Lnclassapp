# Memo — Un enseignant dans plusieurs établissements

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — questions au porteur ouvertes (voir « Ce que le grill a révélé ») |
| **Ouvert le** | 2026-10-16 (reporté par le porteur le 2026-09-28, relancé avec les vagues V2 à V6) |
| **Branche** | `docs/cadrage-multi-etablissements-enseignant` (cadrage), puis `feature/multi-etablissements-enseignant` |
| **Programme** | `refonte-application` — vague **V3** (feature ID-27 ; ID-09, SC-23 et la question Q7 de la [feuille de route](../refonte-application/feuille-de-route.md#questions-à-poser-au-porteur)) |

---

## Le problème

En Côte d'Ivoire, beaucoup d'enseignants font des heures dans un second établissement, souvent un privé, en plus de leur poste. Lnclass ne leur donne qu'**un seul établissement** : celui choisi à l'inscription. Pour suivre ses élèves du second établissement, l'enseignant n'a aujourd'hui que deux mauvaises options : un second compte, avec un autre numéro, ou rien.

Le modèle de données l'avait prévu : la table `teacher_schools` est une vraie table n-n avec un drapeau `primary` ([ADR-0030](../../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) : « la V3 ajoutera le sélecteur sans migration »). Mais **aucun chemin n'écrit de ligne secondaire**, et toute l'application lit l'établissement principal comme s'il était le seul (inventaire ci-dessous).

## Pour qui

- **L'enseignant** (Teacher) déjà inscrit, qui enseigne dans un deuxième ou un troisième établissement : il veut y déclarer ses classes, y assigner des exercices et y publier des annonces, sans mélanger ses deux établissements.
- **Chaque direction** (SchoolStaff) : elle voit l'enseignant dans « Enseignants » avec **ses** classes de **son** établissement, peut le retirer de **son** établissement et rien de plus. Elle ne voit rien de l'autre établissement.
- **L'équipe** (Team) : ses comptes par établissement et par DRENA restent justes quand un enseignant en a plusieurs.

## Pourquoi maintenant

- Le porteur a relancé les vagues V2 à V6 ; ce chantier en est la seule ligne « à part » du backlog ([`chantiers/README.md`](../README.md#backlog)).
- La dépendance écrite dans la feuille de route (« V2 pour `multi-etablissements-enseignant` : rattachement par la direction, ID-09 ») **tombe** si le porteur suit la recommandation de la question 1 : l'enseignant rejoint lui-même, par le lien d'invitation que la direction partage déjà ([ADR-0083](../../decisions/adr/0083-inscription-enseignant-en-deux-voies.md)). L'espace direction complet (V2, au backlog) n'est alors pas un préalable.
- La **question Q7** de la feuille de route (« avec le code de cet établissement, ou rattaché par sa direction ? ») est **périmée** : depuis l'ADR-0083 (2026-10-07), l'enseignant ne saisit plus jamais de code d'établissement. Elle est reformulée ici (question 1).

## Inventaire — comment un enseignant est rattaché aujourd'hui

État de `Develop` au 2026-10-16.

### 1. Le rattachement : `teacher_schools`

| Élément | État |
|---|---|
| Table | `teacher_schools(teacher_id, school_id, primary, created_at)` ; index unique `(teacher_id, school_id)` ; index unique partiel `(teacher_id) WHERE primary` (ADR-0030) |
| Chemins d'écriture | **trois, tous `primary: true`** : `Identity::RegisterTeacher` (inscription, deux voies, ADR-0083), `School::JoinSchoolWithCode` (écran d'attente d'un enseignant **sans** établissement, DRENA → établissement depuis l'ADR-0083 ; le nom garde « Code »), `School::ReinstateTeacher` (réintégration par la direction, ADR-0071) |
| Lignes secondaires en base | **Aucun chemin n'en écrit**, et l'ancienne base n'a pas été reprise (ADR-0034) : il ne devrait y en avoir aucune en production. À vérifier par une requête avant le Lot 0 |
| Suppression | `SchoolRepository#detach_teacher` supprime la ligne de l'établissement, **principale ou non** (retrait par la direction, ADR-0071) |
| Trace des retraits | `teacher_school_departures` : un départ ouvert interdit de revenir seul dans l'établissement qui a retiré l'enseignant (ADR-0071) |
| Ancienne application | `schools.first` sans ordre (inventaire [`classroom-school.md`](../refonte-application/inventaire/classroom-school.md)) : **n'existe plus** dans ce dépôt. Son successeur est le drapeau `primary`, unique et ordonné |

### 2. L'enseignement : `teacher_classrooms` et `TeachingRepository`

- `TeachingRepository#declare` / `#withdraw` (idempotents), `#classroom_ids_for(teacher_id:)` (**toutes écoles confondues**), `#withdraw_all_in_school` (retrait par la direction).
- `DeclareTeachingPolicy` exige `classroom.school_id == actor.school_id` : on ne se déclare que dans les classes de l'établissement principal.
- `TeachPolicy` et `ReadClassroomPolicy` autorisent par la **liaison** (`classroom.teacher_ids`), pas par l'établissement : un enseignant de deux établissements serait déjà autorisé sur les classes des deux. C'est la bonne base.

### 3. Le code d'établissement (ADR-0057)

Depuis l'ADR-0083, le code ne sert plus qu'à l'inscription de la **direction** (ADR-0077). L'enseignant arrive par la liste de sa DRENA ou par un lien `/i/<jeton>` (collègue, direction, équipe). Un enseignant **connecté** qui ouvre un lien `/i/<jeton>` est renvoyé vers son accueil (`TeacherRegistrationsController#invite`, memo `inscription-enseignant`, Q12 : « rejoindre un second établissement par un lien sort du chantier »).

### 4. La validation des enseignants en attente (ADR-0063, 0073, 0083)

En pause depuis l'ADR-0073, puis plus aucune nouvelle demande depuis l'ADR-0083 : l'inscription rattache immédiatement, sans preuve. `VouchPolicy` compare `actor.school_id` à l'établissement de la demande ; `JoinRequestsQuery` lit l'établissement principal. **Rien à changer**, à une condition : rejoindre un second établissement ne crée pas non plus de demande.

### 5. Ce qui suppose un seul établissement

| Où | Ce qui casse avec deux établissements |
|---|---|
| `UserRepository#actor_for` → `Actor#school_id` = **l'établissement principal** | Toutes les policies de l'enseignant le comparent : `DeclareTeachingPolicy`, `PublishPolicy` (annonces), `InviteColleaguePolicy`, `VouchPolicy`, `JoinSchoolWithCodePolicy`. Le second établissement est inaccessible |
| `AuthenticatedController` : `school_id.nil?` → écran d'attente | Juste tant que `school_id` reste nil **seulement** sans aucun établissement |
| `DetachTeacher` (direction) supprime la ligne principale | Un enseignant retiré de son établissement principal mais rattaché ailleurs n'a **plus de principal** : il tombe sur l'écran d'attente alors qu'il a un établissement |
| `ReinstateTeacher` refuse (`:not_found`) un enseignant qui a un établissement ; `DepartedTeachersQuery` le cache (`WITHOUT_SCHOOL`) | Un enseignant retiré qui en a un autre ne peut plus être réintégré, et disparaît de « Enseignants retirés » |
| `JoinSchoolWithCodePolicy` : seulement sans établissement | Aucun moyen de rejoindre un second établissement |
| Lectures du principal : `ShellUserQuery` (ligne de détail de l'en-tête), `ProfileQuery`, `TeacherHomeQuery` (nom), `HomeDestinationQuery` | Elles affichent toujours le principal |
| Lien « Inviter un collègue » : `InviteLinkRepository`, `ReferralRepository`, `ReferralQuery` résolvent le jeton personnel vers **l'établissement principal** | Un lien personnel ne peut mener qu'à un établissement |
| Lectures de l'enseignant **sans filtre d'établissement** : `TeacherHomeQuery` (classes), `TeacherFollowUpsQuery`, `CatalogAssignmentTargetsQuery`, `TeacherAudienceQuery` | Elles mélangeraient les classes de deux établissements, dont les noms se répètent (« 6ème 1 » existe partout, ADR-0030) |
| Pilotage de l'équipe | `DrenaSchoolsQuery` et `TeamDashboardQuery` (comptes par DRENA) ne comptent que le principal ; `TeamDashboardQuery` (par établissement) et `SchoolsQuery` comptent toutes les lignes ; `GrowthMetricsQuery` compte les enseignants distincts par principal. **Incohérent** dès qu'une ligne secondaire existe |

### 6. Ce qui est déjà borné à l'établissement (droits de la direction)

- `ManageSchoolTeachersPolicy`, `ManageSchoolStructurePolicy`, `ManageClassroomMembersPolicy`, `ReadOwnSchoolPolicy` comparent l'établissement du **compte de la direction** (`school_staffs`, un seul par compte) à celui du geste.
- `SchoolTeachersQuery` (« Enseignants ») liste les lignes `teacher_schools` de l'établissement, secondaires comprises, et filtre les noms de classes par établissement. `StudentWorkQuery` et `SchoolActivityQuery` ne lisent que les classes de l'établissement.
- La fiche d'un établissement côté équipe (`SchoolDetailQuery`) montre déjà un badge « Établissement secondaire » : préparé, jamais affiché faute de ligne secondaire.

Conclusion de l'inventaire : **aucune table nouvelle n'est nécessaire pour le rattachement**. Ce qui manque, c'est la notion d'**établissement courant**, les gestes « rejoindre », « quitter » et « changer », et la correction de quatre endroits qui supposent un seul établissement (retrait, réintégration, liste des retirés, pilotage).

## Hors périmètre

- **La direction rattache un enseignant par son numéro** (ID-09 et SC-23 au sens de l'ancienne application) : écarté par la recommandation de la question 1. Si le porteur le veut, il reviendra avec l'espace direction complet (V2).
- **Une direction dans plusieurs établissements** : `school_staffs.user_id` reste unique.
- **Plusieurs matières pour un enseignant**, dans un établissement ou d'un établissement à l'autre : `teacher_profiles.material_id` reste unique ici. Le cas est traité par le chantier `enseignant-plusieurs-matieres`, cadré en parallèle (question 9).
- **Choisir soi-même son établissement principal** : le principal est le premier ; il ne change que si l'enseignant le quitte ou en est retiré (question 8).
- **Une vue fusionnée** de toutes les classes de tous les établissements (question 3).
- **Un lien « Inviter un collègue » par établissement** (question 8).
- **La certification des enseignants** et toute validation d'un rattachement : comme l'inscription (ADR-0083), rejoindre est sans preuve.
- **Le multi-classes de l'élève** (`multi-classes-eleve`, Q5) et le **changement d'établissement d'un élève** (`changement-etablissement-eleve`).
- **La recherche de comptes de l'équipe** (`AccountSearchQuery`) : elle continue d'afficher l'établissement principal (dette, journal).

## Ce que le grill a révélé

> Questions posées au porteur le 2026-10-16. **Aucune n'est encore répondue** : la colonne « Réponse » porte la recommandation de l'architecte, qui ne vaut pas décision. Le PRD, l'ADR-0094, les UDR-0098 à 0100 et le plan sont écrits sur ces recommandations ; une réponse différente les amende avant le Lot 0.

| # | Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|---|
| 1 | **Comment un enseignant déjà inscrit rejoint-il un autre établissement ?** (reformule Q7 : le code n'existe plus côté enseignant) | *À trancher.* **Recommandation : par lui-même**, de deux façons : (a) en ouvrant, connecté, le lien d'invitation de cet établissement (`/i/<jeton>` de la direction, de l'équipe ou d'un collègue), qui demande « Rejoindre <établissement> ? » ; (b) par « Ajouter un établissement » dans « Mes établissements », DRENA puis établissement, comme à l'inscription. **Pas de rattachement par la direction au numéro** : il rattache quelqu'un sans son accord et révèle qu'un numéro a un compte | ID-09 et SC-23 deviennent « la direction partage son lien » (déjà livré). Le chantier ne dépend plus de l'espace direction complet. Un seul use case (`JoinSchoolWithCode`, élargi) pour l'écran d'attente, le lien et « Ajouter » |
| 2 | Combien d'établissements au plus par enseignant ? | *À trancher.* **Recommandation : 3** | Constante du domaine ; au-delà, refus avec un message clair. Le plafond protège contre un rattachement en masse sans preuve |
| 3 | Un établissement à la fois (sélecteur), ou toutes les classes ensemble ? | *À trancher.* **Recommandation : un établissement courant**, changé dans le menu du compte, gardé **par appareil** (par session) ; à la connexion, l'établissement principal | Toutes les policies existantes restent justes sans être réécrites : `actor.school_id` devient l'établissement courant. Une colonne `sessions.current_school_id` (ADR-0094). Accueil, catalogue, assignation et annonces ne montrent que l'établissement courant |
| 4 | Que voit une direction d'un enseignant qui a aussi un autre établissement ? | *À trancher.* **Recommandation : rien de l'autre établissement** : ni son nom, ni « aussi ailleurs », ni ses classes, ni ses devoirs | Aucune lecture de la direction ne joint `teacher_schools` d'un autre établissement ; test de refus par écran (UDR-0100) |
| 5 | La direction de l'établissement **principal** retire l'enseignant, qui en a un autre : que devient-il ? | *À trancher.* **Recommandation : il garde ses autres établissements** ; le plus ancien devient principal ; il n'est pas mis en attente | `DetachTeacher` promeut un principal dans sa transaction (ADR-0094) |
| 6 | Un enseignant retiré qui a rejoint un autre établissement entre-temps peut-il être réintégré ? | *À trancher.* **Recommandation : oui**, comme établissement supplémentaire, dans le plafond ; il reste dans « Enseignants retirés » | `ReinstateTeacher` rattache en secondaire s'il a déjà un établissement ; refus « 3 établissements déjà » au plafond. `DepartedTeachersQuery` perd sa condition « sans établissement » |
| 7 | L'enseignant peut-il **quitter** lui-même un établissement ? | *À trancher.* **Recommandation : oui, sauf son dernier**, avec confirmation ; mêmes effets qu'un retrait dans cet établissement (classes retirées, devoirs actifs archivés), **sans** barrière de retour | Nouveau use case `School::LeaveSchool`. Sans lui, un enseignant qui s'est trompé d'établissement dépend de la direction |
| 8 | « Inviter un collègue » : vers quel établissement ? Et l'enseignant choisit-il son principal ? | *À trancher.* **Recommandation : toujours vers l'établissement principal**, nommé sur la page d'invitation ; le principal n'est pas choisi (le premier, puis le plus ancien restant) | Le jeton personnel reste un par enseignant (ADR-0063) ; la page « Inviter un collègue » nomme l'établissement. Pas de « Définir comme principal » |
| 9 | Une seule matière pour tous ses établissements ? | **Traité par `enseignant-plusieurs-matieres`** (chantier cadré en parallèle, demande du porteur : plusieurs disciplines au sein de l'établissement). Ici, la matière de l'enseignant vaut pour tous ses établissements | `teacher_profiles.material_id` inchangé par ce chantier ; si `enseignant-plusieurs-matieres` livre avant, les écrans de ce chantier affichent ce qu'il décide, sans règle propre |
| 10 | Pilotage de l'équipe : un enseignant de deux établissements compte-t-il dans chacun ? | *À trancher.* **Recommandation : oui dans chaque établissement où il est rattaché ; la DRENA reste la somme de ses établissements** (deux fois s'il a deux établissements de la même DRENA) ; **une seule fois au national** | `DrenaSchoolsQuery` et `TeamDashboardQuery` comptent les rattachements ; `GrowthMetricsQuery` inchangé ; la définition « DRENA d'un enseignant » de l'ADR-0062 est amendée (Lot D) |
| 11 | Un enseignant ouvre une classe d'un autre de ses établissements (lien partagé, rappel) : la page s'ouvre-t-elle ? | *À trancher.* **Recommandation : oui, sans changer l'établissement courant** ; la page nomme l'établissement de la classe | Les policies par liaison (`TeachPolicy`, `ReadClassroomPolicy`) ne changent pas ; seuls les gestes liés à l'établissement courant (se déclarer, annonce) refusent |

## Cas limites identifiés

- **Deux appareils** : l'enseignant est dans A sur son téléphone et dans B sur l'ordinateur. Chaque session garde le sien : voulu (question 3).
- **Établissement courant quitté ou retiré** pendant la session : à la requête suivante, l'acteur retombe sur le principal, sans erreur. Une session qui désigne un établissement où l'enseignant n'est plus rattaché ne donne **jamais** cet établissement (vérifié à chaque requête, ADR-0094).
- **Formulaire envoyé après un changement d'établissement** sur un autre onglet (se déclarer dans une classe de A alors que la session est passée à B) : refus `:other_school` existant, message « Cette classe n'est pas dans l'établissement où vous êtes ».
- **Deux « Rejoindre » simultanés** au plafond (deux onglets) : le plafond tient sous verrou de la ligne `users` de l'enseignant (ADR-0094).
- **Rejoindre un établissement qui l'a retiré** : refusé par l'erreur neutre existante (départ ouvert, ADR-0071), par toutes les voies, lien compris.
- **Rejoindre un établissement où il est déjà** (lien ouvert deux fois) : « Vous êtes déjà dans cet établissement », et il y est placé.
- **Lien d'invitation d'un collègue anonymisé, ou d'un établissement inactif**, ouvert connecté : même alerte « Ce lien n'est plus valable » que pour l'inscription (UDR-0079), rien n'est écrit.
- **Classes homonymes** : « 6ème 1 » de A et « 6ème 1 » de B ne se côtoient jamais à l'écran, puisque tout est borné à l'établissement courant ; la page d'une classe ouverte hors établissement courant nomme son établissement.
- **Enseignant anonymisé** (ADR-0036) : ses lignes `teacher_schools` restent comme aujourd'hui ; aucune lecture de la direction ne le montre.
- **Établissement désactivé** alors qu'il est l'établissement courant d'une session : il reste rattaché (comme aujourd'hui pour le principal) ; aucune annonce ni déclaration n'y est possible (policies existantes).

## Questions encore ouvertes

- Les questions 1 à 8, 10 et 11 ci-dessus, **à faire répondre par le porteur avant le Lot 0** (la 9 relève de `enseignant-plusieurs-matieres`).
- Ordre avec `enseignant-plusieurs-matieres` : les deux chantiers touchent les lectures de l'enseignant (accueil, catalogue). Le premier dont le Lot 0 fusionne fixe les contrats ; l'autre s'y rebase.
- Vérifier en production qu'aucune ligne `teacher_schools` n'a `primary = false` (`SELECT COUNT(*) FROM teacher_schools WHERE NOT "primary"`). S'il y en a, le Lot 0 dit lesquelles et pourquoi avant toute écriture.

## Réponses du porteur (2026-10-16)

- Recommandations acceptées.
- Q9 : les matières de l'enseignant sont choisies **par établissement** (voir `enseignant-plusieurs-matieres`).
- Ordre : ce chantier passe avant `enseignant-plusieurs-matieres`, jamais en même temps (9 fichiers communs).
- **Q4 (et Q3)** : chaque établissement a son interface autonome et complète (classes, niveaux, annonces, à faire…). Un seul compte, un seul numéro de téléphone, plusieurs établissements : l'établissement courant cloisonne tout l'espace enseignant.
- **Q8** : deux liens séparés. « Inviter un collègue de mon établissement » : lien rattaché à l'établissement courant. « Inviter un autre collègue » : lien sans établissement (parrainage), le collègue choisit son établissement.

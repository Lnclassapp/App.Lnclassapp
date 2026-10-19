# PRD — Sous-rôles de l'équipe appliqués (admin, contenu, terrain)

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> **Écrit sur les recommandations du memo** : les questions 1 à 10 attendent le porteur. Une réponse différente se reporte ici avant le Lot 0.

## 1. Contexte

Chaque membre de l'équipe a un sous-rôle (`admin`, `content`, `field`) depuis la V1, mais 21 des 27 policies qui laissent passer l'équipe ne le lisent pas, et douze pages livrées depuis n'ont pas de place dans la matrice de l'ADR-0038. Ce chantier applique une matrice unique par capacité (ADR-0100) à toutes les pages de l'équipe, masque dans l'interface ce que chaque sous-rôle ne peut pas faire, et permet à un admin de changer le sous-rôle d'un autre membre. Voir le [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe `admin` | tout l'espace équipe ; changer le sous-rôle d'un **autre** membre ; réinitialiser son second facteur ; Mission Control | changer son propre sous-rôle ; rétrograder le dernier admin |
| Équipe `content` | catalogue (cours, fiches, exercices, imports de contenu), référentiel (niveaux, séries, matières), blog, illustrations d'annonce, publier une annonce, Pilotage agrégé, Croissance, lire tout le catalogue | inviter, changer un sous-rôle, réinitialiser un TOTP, anonymiser, Mission Control ; DRENA, établissements, classes, barème, codes, direction, enseignants en attente ; lire un compte nominatif, émettre un code de PIN, pages de classe et sessions d'élèves ; modérer les annonces |
| Équipe `field` | DRENA, établissements (import compris), codes, barème, classes, direction, enseignants en attente ; « Débloquer un compte », code de récupération du PIN, recherche du Pilotage, pages de classe et sessions d'élèves ; modérer et publier des annonces ; Pilotage agrégé, Croissance, lire tout le catalogue | inviter, changer un sous-rôle, réinitialiser un TOTP, anonymiser, Mission Control ; modifier le catalogue, la taxonomie, le blog, les illustrations ; importer du contenu |
| Enseignant, direction, élève | inchangé | inchangé |

**Règle d'autorisation** : `actor.may?(:capacité)` dans la policy de chaque use case (ADR-0100 §4.2), matrice `Entities::Identity::TeamCapabilities`. Refus de sous-rôle : `:forbidden`, page « Accès interdit » (HTML) ou toast (Turbo Stream).

### Correspondance policy → capacité

| Policy (ou garde) | Avant | Capacité |
|---|---|---|
| `Identity::InviteTeamPolicy` | admin | `manage_team` |
| `Identity::ResetSecondFactorPolicy` | tout `team` | `manage_team` |
| `Identity::ChangeTeamRolePolicy` *(nouvelle)* | — | `manage_team` |
| `Identity::DeleteUserPolicy` | admin | `erase_accounts` |
| `Teams::JobsBaseController` *(nouveau)* | tout `team` | `supervise_jobs` |
| `Catalog::ManageContentPolicy` | tout `team` | `manage_content` |
| `Catalog::ManageTaxonomyPolicy` | tout `team` | `manage_taxonomy` |
| `Communication::ManageArticlesPolicy` | admin, content | `manage_blog` |
| `Communication::ManageIllustrationsPolicy` | tout `team` | `manage_illustrations` |
| `School::ManageSchoolPolicy`, `School::ManageSchoolStructurePolicy`, `Classroom::ManageClassroomPolicy`, `Classroom::ManageClassroomPlanPolicy` | tout `team` | `manage_schools` |
| `Identity::InviteSchoolStaffPolicy`, `School::RemoveSchoolStaffPolicy`, `School::RestoreSchoolStaffPolicy` | admin, field | `manage_schools` |
| `Identity::ReadUserPolicy`, `Identity::IssuePinRecoveryCodePolicy` | tout `team` | `read_people` |
| `Classroom::ReadClassroomPolicy`, `TeachPolicy`, `FollowAssignmentPolicy`, `ManageClassroomMembersPolicy` ; `Assessment::ReadSessionPolicy` | tout `team` | `read_people` |
| `Communication::ReadFilePolicy` (branche équipe), `Message#moderatable_by?` (branche équipe) | tout `team` | `moderate_announcements` |
| `Communication::PublishPolicy` (branche équipe) | tout `team` | `publish_announcements` |
| `School::ReadIndicatorsPolicy`, `Identity::ReadGrowthPolicy` | tout `team` | `read_indicators` |
| `Catalog::ReadPublishedPolicy`, `Assessment::RevealAnswersPolicy` (branches équipe) | tout `team` | `read_catalog` |

## 3. Parcours utilisateur

### Chemin nominal — changer le sous-rôle d'un membre

1. Awa (admin) ouvre « Débloquer un compte » et saisit le numéro de Koffi (équipe, « Contenu »).
2. La fiche du compte affiche « Rôle dans l'équipe : Contenu » et un bouton « Changer le rôle ».
3. La modale propose les trois sous-rôles en cases radio, avec leur aide ; « Contenu » est coché.
4. Awa coche « Terrain » et valide.
5. La modale se ferme, un toast confirme « Rôle de Koffi Yao changé : Terrain. », la fiche affiche « Terrain ».
6. À sa requête suivante, Koffi voit le shell du terrain (« Établissements » apparaît, « Nouveau cours » disparaît).

### Chemin nominal — un membre « Contenu » au quotidien

1. Koffi (contenu) se connecte (PIN puis TOTP) : le shell montre Accueil, Cours, Pilotage ; le menu « Plus » montre Référentiel, Imports, Annonces.
2. Sur l'accueil : « Nouveau cours », « Imports », « Croissance », « Blog » ; ni « Établissements », ni « Débloquer un compte », ni « Inviter un membre ».
3. Le Référentiel montre Niveaux, Séries, Matières, Illustrations ; pas DRENA ni Barème.
4. Le Pilotage montre les indicateurs, sans le bloc de recherche nominative.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Un membre ouvre à la main une page hors de son sous-rôle | 403, page « Accès interdit » avec la phrase de l'équipe (UDR-0116 §3.4) |
| Un geste interdit envoyé depuis une modale (Turbo Stream) | 403, toast « Accès interdit. », la modale reste ouverte |
| Un admin ouvre « Changer le rôle » sur son propre compte | Le bouton n'est pas rendu ; une requête forgée reçoit 403 |
| Un admin rétrograde le dernier admin | Impossible par l'écran (cible = soi) ; si deux admins se rétrogradent l'un l'autre en même temps, le second reçoit 422 « L'équipe doit garder au moins un administrateur. » |
| Cible enseignant, élève, direction ou compte anonymisé | 404 |
| Sous-rôle inconnu dans la requête | 422, erreur sur le champ |
| Même sous-rôle | Succès, toast, rien n'est écrit ni journalisé |
| Liste des imports | Ne montre que les types que le membre peut lancer ; le rapport d'un autre type donne 403 |
| `/teams/jobs` sans `supervise_jobs` | 403 |

## 4. Critères d'acceptation

Chaque refus est un test (policy, use case ou intégration). Les noms entre crochets sont les capacités de l'ADR-0100.

### 4.1 Les treize cases vides de la matrice

```gherkin
Fonctionnalité: chaque sous-rôle n'accède qu'à sa colonne de la matrice (ADR-0100 §4.1)

  Contexte:
    Étant donné Awa, membre de l'équipe « admin », second facteur vérifié
    Et Koffi, membre de l'équipe « content », second facteur vérifié
    Et Fanta, membre de l'équipe « field », second facteur vérifié

  # [manage_team] — cases vides : content, field
  Scénario: le contenu n'invite pas de membre
    Quand Koffi ouvre /teams/invitations/new
    Alors il reçoit 403
    Et aucune invitation n'est créée quand il envoie le formulaire

  Scénario: le terrain ne réinitialise pas le second facteur d'un autre membre
    Quand Fanta demande la réinitialisation du second facteur de Koffi
    Alors elle reçoit 403
    Et le second facteur de Koffi est intact
    Et aucun événement « totp.reset » n'est journalisé

  Scénario: le contenu ne change pas un sous-rôle
    Quand Koffi demande à passer Fanta en « admin »
    Alors il reçoit 403
    Et Fanta reste « field »

  # [erase_accounts] — cases vides : content, field
  Plan du scénario: ni le contenu ni le terrain n'anonymisent un élève
    Quand <membre> ouvre la suppression du compte d'un élève
    Alors il reçoit 403
    Et le compte de l'élève n'est pas anonymisé
    Et la liste des demandes de suppression lui répond 403
    Exemples:
      | membre |
      | Koffi  |
      | Fanta  |

  # [supervise_jobs] — cases vides : content, field
  Plan du scénario: Mission Control est réservé à l'admin
    Quand <membre> ouvre /teams/jobs
    Alors il reçoit 403
    Exemples:
      | membre |
      | Koffi  |
      | Fanta  |

  # [manage_content] — case vide : field
  Scénario: le terrain ne modifie pas le catalogue
    Quand Fanta publie, modifie ou archive un cours, une fiche ou un exercice
    Alors elle reçoit 403
    Et le contenu est inchangé
    Et lancer un import de type « course_tree », « essentials » ou « exercises » lui répond 403

  # [manage_taxonomy] — case vide : field
  Scénario: le terrain ne modifie pas la taxonomie
    Quand Fanta crée, modifie ou supprime un niveau, une série ou une matière
    Alors elle reçoit 403

  # [manage_blog] — case vide : field
  Scénario: le terrain ne gère pas le blog
    Quand Fanta ouvre /teams/blog
    Alors elle reçoit 403

  # [manage_illustrations] — case vide : field
  Scénario: le terrain ne gère pas les illustrations d'annonce
    Quand Fanta ajoute, renomme ou retire une illustration d'annonce
    Alors elle reçoit 403

  # [manage_schools] — case vide : content
  Scénario: le contenu ne gère pas les établissements
    Quand Koffi modifie, désactive ou supprime un établissement, une DRENA
    Ou régénère un code d'établissement
    Ou modifie le barème, génère, ajoute, retire ou archive des classes
    Ou valide ou refuse un enseignant en attente
    Ou invite, retire ou restaure une direction
    Ou lance un import de type « schools » ou « drenas »
    Alors il reçoit 403 à chaque fois
    Et rien n'est modifié

  # [read_people] — case vide : content
  Scénario: le contenu ne lit aucun compte nominatif
    Quand Koffi ouvre « Débloquer un compte » avec le numéro d'un élève
    Alors il reçoit 403
    Et émettre un code de récupération du PIN lui répond 403
    Et la page d'une classe, ses élèves et le suivi d'une assignation lui répondent 403
    Et la session d'exercice d'un élève lui répond 403
    Et le Pilotage lui est servi sans le bloc de recherche
    Et une recherche envoyée à la main au Pilotage ne lui renvoie aucun compte

  # [moderate_announcements] — case vide : content
  Scénario: le contenu ne modère pas les annonces des autres
    Étant donné une annonce publiée par un enseignant
    Quand Koffi la retire
    Alors il reçoit 404
    Et l'annonce reste publiée
```

### 4.2 Les cases pleines (non-régression)

```gherkin
  Plan du scénario: chaque sous-rôle garde sa colonne
    Quand <membre> ouvre <page>
    Alors il reçoit 200
    Exemples:
      | membre | page                         |
      | Awa    | /teams/jobs                  |
      | Awa    | /teams/invitations/new       |
      | Koffi  | /teams/courses/new           |
      | Koffi  | /teams/levels                |
      | Koffi  | /teams/blog                  |
      | Koffi  | /teams/dashboard             |
      | Koffi  | /teams/growth                |
      | Fanta  | /teams/schools               |
      | Fanta  | /teams/classroom-plan        |
      | Fanta  | /teams/accounts              |
      | Fanta  | /teams/dashboard             |
      | Fanta  | /courses                     |
```

Le test d'intégration `sub_role_matrix_test.rb` couvre **toutes** les routes `GET` de l'espace équipe, pas seulement ces exemples (ADR-0100 §7).

### 4.3 Changer un sous-rôle

```gherkin
Fonctionnalité: un admin change le sous-rôle d'un autre membre (ADR-0100 §4.3)

  Scénario: changement réussi et journalisé
    Étant donné Awa « admin » et Koffi « content »
    Quand Awa passe Koffi en « field »
    Alors Koffi est « field »
    Et un événement « team_role.changed » est journalisé avec from « content » et to « field »
    Et à sa requête suivante, Koffi ouvre /teams/schools avec 200 et /teams/courses/new avec 403

  Scénario: personne ne change son propre sous-rôle
    Quand Awa demande à passer elle-même en « content »
    Alors elle reçoit 403
    Et Awa reste « admin »
    Et la fiche de son propre compte n'affiche pas « Changer le rôle »

  Scénario: l'équipe garde au moins un admin
    Étant donné Awa et Bakary, seuls admins
    Quand Awa rétrograde Bakary en « content » et que Bakary rétrograde Awa en « content » au même instant
    Alors l'une des deux demandes réussit
    Et l'autre reçoit 422 « L'équipe doit garder au moins un administrateur. »
    Et il reste exactement un admin

  Plan du scénario: seule l'équipe a un sous-rôle
    Quand Awa demande à changer le sous-rôle de <cible>
    Alors elle reçoit 404
    Exemples:
      | cible                   |
      | un enseignant           |
      | un élève                |
      | une direction           |
      | un compte anonymisé     |

  Scénario: sous-rôle inconnu
    Quand Awa envoie le sous-rôle « superadmin » pour Koffi
    Alors elle reçoit 422 avec l'erreur « Choisissez le rôle de la personne. »
    Et Koffi reste « content »

  Scénario: même sous-rôle
    Quand Awa envoie « content » pour Koffi, déjà « content »
    Alors elle voit le toast de succès
    Et aucun événement « team_role.changed » n'est journalisé
```

### 4.4 Interface

```gherkin
Fonctionnalité: l'interface ne montre que ce que le sous-rôle permet (UDR-0116, UDR-0117)

  Scénario: shell du contenu
    Quand Koffi ouvre son accueil, à 390 px et sur ordinateur
    Alors la navigation montre Accueil, Cours, Pilotage
    Et le menu « Plus » montre Référentiel, Imports, Annonces
    Et « Établissements » n'apparaît nulle part

  Scénario: shell du terrain
    Quand Fanta ouvre son accueil
    Alors la navigation montre Accueil, Cours, Établissements, Pilotage
    Et l'accueil n'a ni « Nouveau cours » ni « Blog » ni « Inviter un membre »
    Et la page Cours n'a ni « Nouveau cours » ni « Importer »

  Scénario: page interdite atteinte par une adresse
    Quand Koffi ouvre /teams/schools
    Alors il voit « Votre rôle dans l'équipe ne donne pas accès à cette page. Un administrateur peut le changer. »
    Et un lien le ramène à l'accueil de l'équipe

  Scénario: imports filtrés
    Quand Koffi ouvre /teams/imports
    Alors il ne voit que les imports de cours, fiches et exercices
    Et le bouton « Importer » ne propose que ces trois types
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Identity::TeamCapabilities` (matrice) ; `Actor#may?` ; `Policies::Identity::ChangeTeamRolePolicy` ; `UseCases::Identity::ChangeTeamRole` ; `Dtos::Identity::TeamRoleChangeInput` ; port `Ports::Identity::UserRepositoryPort#change_team_role` (verrou, comptage des admins) ; réécriture des 27 policies du §2 et de `Message#moderatable_by?` |
| Infrastructure | `Repositories::Identity::UserRepository#change_team_role` (transaction, `FOR UPDATE` sur les admins) ; `Queries::Catalog::ImportReportsQuery` filtrée par types autorisés ; aucune migration |
| Delivery | `Teams::JobsBaseController` ; `config/application.rb` (base de Mission Control) ; `Teams::MemberTeamRolesController` (`edit`, `update`) ; route `teams/members/:user_public_id/team-role` ; booléens de capacité passés aux vues (accueil, catalogue, imports, Pilotage, fiche du compte, référentiel, modération) |
| UI | shell filtré (`NavigationHelper`) ; raccourcis et sections de l'accueil ; tuiles du Référentiel ; boutons du catalogue ; types d'import ; bloc de recherche du Pilotage ; actions de la fiche du compte ; modale « Changer le rôle » ; texte 403 de l'équipe |

## 6. Décisions rattachées

- [ADR-0100](../../decisions/adr/0100-matrice-des-sous-roles-de-l-equipe-par-capacite.md) — capacités et matrice unique ; amende ADR-0038 §4 et ADR-0031 §4 *(Proposé)*
- [UDR-0116](../../decisions/udr/0116-shell-et-accueil-de-l-equipe-selon-le-sous-role.md) — shell, accueil, Référentiel et page 403 selon le sous-rôle *(Proposé)*
- [UDR-0117](../../decisions/udr/0117-gestes-reserves-dans-les-pages-de-l-equipe.md) — gestes masqués dans le catalogue, les imports, le Pilotage, la fiche du compte, la modération *(Proposé)*
- [UDR-0118](../../decisions/udr/0118-changer-le-sous-role-d-un-membre.md) — modale « Changer le rôle » et libellés des sous-rôles *(Proposé)*

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Policies laissant passer l'équipe sans lire le sous-rôle | 21 | 0 (hors `SecondFactorPolicy`) | |
| Cases vides de la matrice avec un test de refus | 0 / 13 | 13 / 13 | |
| Routes `GET` de l'équipe couvertes par le test de matrice | 0 | toutes | |

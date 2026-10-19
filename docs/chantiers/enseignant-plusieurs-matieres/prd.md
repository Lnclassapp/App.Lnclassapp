# PRD — Un enseignant qui enseigne plusieurs matières

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
>
> **Amendé au Lot 0 par les réponses du porteur du 2026-10-16** ([memo](memo.md#réponses-du-porteur-2026-10-16)) : recommandations acceptées, **sauf Q1 et Q7** — les matières sont attachées au **rattachement enseignant-établissement** (`teacher_schools`), pas au compte. Un enseignant de deux établissements peut avoir PC dans l'un et SVT dans l'autre ; le profil gère les matières de l'établissement courant ; tous les écrans montrent les matières de l'établissement courant.

## 1. Contexte

Un enseignant n'a aujourd'hui qu'une matière (`teacher_profiles.material_id`), qui filtre son catalogue, la page de ses classes et son accueil ; un enseignant bivalent ne trouve jamais sa seconde matière. Ce chantier lui donne **1 à 3 matières par établissement** (une liste par rattachement enseignant-établissement, pas par classe), choisies à l'inscription et modifiées par lui seul dans « Mon profil » pour son établissement courant, et réécrit chaque lecture « sa matière » en « ses matières de l'établissement courant ». L'enseignant d'une seule matière ne voit rien changer.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher | Choisir une matière et une seconde facultative à l'inscription ; remplacer la liste de ses matières (1 à 3) **de son établissement courant** dans « Mon profil » ; voir les cours de toutes ses matières de l'établissement courant (catalogue, page de classe, accueil) | Avoir 0 ou plus de 3 matières dans un établissement ; modifier les matières d'un autre ; modifier celles d'un autre de ses établissements sans y passer ; choisir une matière principale |
| SchoolStaff (direction) | Voir toutes les matières de chaque enseignant de son établissement (« Enseignants », « Enseignants retirés ») | Modifier les matières d'un enseignant ; ouvrir `/profile/materials` (refus) |
| Team | Voir les matières (fiche d'établissement, demandes) ; « N enseignants » par matière | Modifier les matières d'un enseignant (hors périmètre) ; ouvrir `/profile/materials` (refus) ; supprimer une matière portée par un enseignant |
| Student | Lire « M. Kouassi · PC, SVT » sur une annonce | Ouvrir `/profile/materials` (refus) |

**Règle d'autorisation** : `Policies::Identity::ManageOwnMaterialsPolicy#call(actor:)` — succès si `actor.teacher?` **et** `actor.school_id` (un établissement courant, vérifié à chaque requête, ADR-0094 §4.2) ; sinon `:forbidden`. Le compte modifié est **toujours** `actor.user_id` et l'établissement **toujours** `actor.school_id` (route sans identifiant, ADR-0055). Aucune autre policy ne change : la matière reste une **lecture**, jamais un droit (ADR-0103 §4).

## 3. Parcours utilisateur

### Chemin nominal

1. À l'inscription, M. Kouassi choisit « Physique-Chimie » puis, dans « Autre matière (facultatif) », « SVT ». Son compte a deux matières, dans cet ordre.
2. Son accueil porte deux badges, PC et SVT ; ses bulles « Cours » mènent au catalogue de ses deux matières à ce niveau.
3. Son catalogue groupe les cours par matière ; sur ordinateur, « Matière » propose « Toutes vos matières », « Physique-Chimie », « SVT ».
4. Sur la page de sa 3ème 2, le bloc « Cours » montre une bande PC et une bande SVT ; il assigne un exercice de SVT.
5. Plus tard, il ouvre « Mon profil », « Modifier » sur « Matières », coche aussi « Mathématiques » et enregistre : toast « Vos matières sont enregistrées. ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Même matière dans les deux listes de l'inscription | une seule matière enregistrée, pas d'erreur |
| Aucune case cochée dans « Mes matières » | 422, « Gardez au moins une matière. », rien n'est écrit |
| 4 cases cochées | 422, « 3 matières au plus. », rien n'est écrit |
| Matière supprimée entre l'ouverture et l'envoi | 422, « Cette matière n'existe plus. Rechargez la page. » |
| Liste identique | succès, aucune écriture, aucun audit |
| Deux onglets enregistrent deux listes | la dernière gagne ; jamais plus de 3 matières |
| Élève, direction ou équipe sur `GET/PATCH /profile/materials` | refus `:forbidden` (rendu habituel), rien n'est écrit |
| `?material=<slug>` hors de ses matières dans le catalogue | aucun cours, état vide avec « Tout voir » |
| Retirer une matière qui a des exercices assignés actifs | les assignations restent actives et visibles sur la page de classe ; elles sortent des « Activités » et du score moyen |
| L'équipe supprime une matière portée par un enseignant | refus (« matière utilisée »), comme aujourd'hui |
| Enseignant de deux établissements, PC dans A et SVT dans B | dans A, rien de SVT : ni catalogue, ni bande, ni badge ; « Mes matières » ne modifie que A |
| Il ajoute un établissement C depuis A | C reçoit la liste de A, qu'il corrige dans son profil une fois passé dans C |
| La direction le retire puis le réintègre | il retrouve la liste qu'il avait dans cet établissement |
| Enseignant sans établissement courant (écran d'attente) | `/profile/materials` refusé (`:forbidden`) |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Matières d'un enseignant

  Contexte:
    Étant donné les matières « Physique-Chimie » (PC), « SVT » (SVT) et « Mathématiques » (Maths)

  Scénario: Migration des enseignants existants
    Étant donné 3 enseignants inscrits avec une matière chacun, dont un rattaché à deux établissements
    Quand la migration du Lot 0 est jouée
    Alors chaque rattachement a exactement une ligne dans ses matières, celle du profil
    Et ses écrans affichent la même chose qu'avant la migration

  Scénario: Inscription avec une seconde matière
    Quand un enseignant s'inscrit avec « Physique-Chimie » et « SVT » en autre matière
    Alors ses matières sont « Physique-Chimie » puis « SVT »

  Scénario: Inscription avec deux fois la même matière
    Quand un enseignant s'inscrit avec « SVT » et « SVT » en autre matière
    Alors il a une seule matière, « SVT »

  Scénario: Ajouter une matière au profil
    Étant donné un enseignant de « Physique-Chimie » et « SVT »
    Quand il enregistre « Physique-Chimie », « SVT » et « Mathématiques » dans « Mes matières »
    Alors ses matières sont « Physique-Chimie », « SVT » puis « Mathématiques »
    Et le journal d'audit contient « profile.materials_changed » avec l'ancienne et la nouvelle liste

  Scénario: Refus — aucune matière
    Étant donné un enseignant de « SVT »
    Quand il enregistre « Mes matières » sans aucune case cochée
    Alors il reçoit « Gardez au moins une matière. »
    Et ses matières restent « SVT »

  Scénario: Refus — plus de trois matières
    Quand un enseignant enregistre quatre matières
    Alors il reçoit « 3 matières au plus. »
    Et ses matières ne changent pas

  Scénario: Refus de policy — un élève
    Étant donné un élève connecté
    Quand il envoie PATCH /profile/materials avec « SVT »
    Alors la réponse est un refus
    Et aucune ligne de matière n'est écrite

  Scénario: Refus de policy — la direction
    Étant donné une direction connectée
    Quand elle ouvre /profile/materials/edit
    Alors la réponse est un refus
    Et aucune modale ne s'affiche

  Scénario: Refus de policy — l'équipe
    Étant donné un membre de l'équipe connecté
    Quand il envoie PATCH /profile/materials
    Alors la réponse est un refus

  Scénario: Matières par établissement, sans fuite
    Étant donné un enseignant de « Physique-Chimie » dans le Lycée A et de « SVT » dans le Lycée B
    Quand il travaille dans le Lycée A
    Alors son accueil, son catalogue, sa page de classe et son profil ne montrent que « Physique-Chimie »
    Et quand il enregistre « Mathématiques » dans « Mes matières », sa liste du Lycée B reste « SVT »

  Scénario: Ajouter un établissement
    Étant donné un enseignant de « Physique-Chimie » et « SVT » dans le Lycée A
    Quand il ajoute le Lycée C depuis le Lycée A
    Alors ses matières dans le Lycée C sont « Physique-Chimie » puis « SVT »

  Scénario: Catalogue d'un enseignant de deux matières
    Étant donné un enseignant de « Physique-Chimie » et « SVT » avec une classe de 3ème
    Quand il ouvre le catalogue
    Alors il voit les cours publiés de 3ème de PC et de SVT, groupés par matière
    Et il ne voit aucun cours de Mathématiques
    Et le filtre « Matière » ne propose que « Toutes vos matières », « Physique-Chimie » et « SVT »

  Scénario: Catalogue d'un enseignant d'une seule matière inchangé
    Étant donné un enseignant de « SVT »
    Quand il ouvre le catalogue
    Alors il n'y a ni filtre « Matière » ni titre de groupe

  Scénario: Page de classe, une bande par matière
    Étant donné un enseignant de « Physique-Chimie » et « SVT » de la 3ème 2
    Quand il ouvre la page de la 3ème 2
    Alors le bloc « Cours » montre une bande « Physique-Chimie » puis une bande « SVT »
    Et la liste « Exercices assignés » montre toujours toutes les assignations de la classe

  Scénario: Deux enseignants dans la même classe
    Étant donné un enseignant de « SVT » et un enseignant de « Mathématiques » de la 3ème 2
    Quand chacun ouvre la page de la 3ème 2
    Alors chacun ne voit dans « Cours » que les cours de sa matière
    Et tous deux voient les exercices assignés par l'autre, avec leur badge de matière

  Scénario: Fiches à revoir sur toutes ses matières
    Étant donné un enseignant de « Physique-Chimie » et « SVT » et un élève de sa classe qui a une fiche de SVT à revoir
    Quand il ouvre la page de la classe
    Alors la fiche de SVT figure dans « Fiches à revoir » avec le badge « SVT »

  Scénario: Score moyen sur toutes ses matières
    Étant donné un élève de sa classe qui a terminé une session de PC à 80 % et une de SVT à 60 %
    Quand l'enseignant de « Physique-Chimie » et « SVT » ouvre son accueil
    Alors le score moyen de la classe est 70 %
    Et l'enseignant de « Physique-Chimie » seul lit 80 % pour la même classe

  Scénario: Retirer une matière garde les assignations
    Étant donné un enseignant qui a assigné un exercice de SVT à sa classe
    Quand il retire « SVT » de ses matières
    Alors l'assignation reste active sur la page de la classe
    Et elle n'apparaît plus dans ses « Activités »

  Scénario: Signature d'une annonce
    Étant donné M. Kouassi, enseignant de « Physique-Chimie » et « SVT »
    Quand un élève de sa classe lit son annonce
    Alors la signature est « M. Kouassi · PC, SVT »

  Scénario: Liste « Enseignants » de la direction
    Étant donné un enseignant de « Physique-Chimie » et « SVT » dans l'établissement
    Quand la direction ouvre « Enseignants »
    Alors sa ligne porte les badges « Physique-Chimie » et « SVT »
    Et la page fait le même nombre de requêtes avec 1 et avec 30 enseignants

  Scénario: Suppression d'une matière portée par un enseignant
    Étant donné un enseignant dont la seconde matière est « SVT »
    Quand l'équipe supprime la matière « SVT »
    Alors la suppression est refusée

  Scénario: Comptes de l'équipe par matière
    Étant donné un enseignant de « Physique-Chimie » et « SVT »
    Quand l'équipe ouvre les matières
    Alors il compte dans « Physique-Chimie » et dans « SVT »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Identity::TeacherMaterials` (MIN 1, MAX 3) ; `Ports::Identity::TeacherMaterialRepositoryPort` (`material_ids_for`, `replace`, `inherit`, par `(teacher_id, school_id)`) ; `RegistrationRepositoryPort#create_teacher` sans `material_id` au Lot Z ; `JoinSchoolWithCode`, `ReinstateTeacher`, `ReviewJoinRequest`, `VouchForTeacher` (`inherit`) ; `Policies::Identity::ManageOwnMaterialsPolicy` ; `UseCases::Identity::UpdateTeacherMaterials` ; `RegisterTeacher` (seconde matière) ; `Dtos::Identity::TeacherMaterialsInput` ; `AuditAction` + `profile.materials_changed` |
| Infrastructure | migration `create_teacher_school_materials` (copie par rattachement et par retrait ouvert) puis migration de retrait de `teacher_profiles.material_id` ; `Orm::TeacherSchoolMaterial` ; `TeacherMaterialRepository`, `RegistrationRepository`, `TaxonomyRepository#delete_material`, `SchoolRepository#delete_if_unreferenced` ; `Queries::Identity::TeacherMaterialsQuery` ; réécriture de `TeacherAudienceQuery`, `CourseCatalogQuery`, `TeacherHomeQuery`, `TeacherFollowUpsQuery`, `ClassroomOverviewQuery`, `ShellUserQuery`, `ProfileQuery`, `InboxQuery`, `SchoolTeachersQuery`, `DepartedTeachersQuery`, `JoinRequestsQuery`, `SchoolDetailQuery`, `MaterialsQuery` |
| Delivery | `GET/PATCH /profile/materials` → `Identity::ProfileMaterialsController` ; `TeacherRegistrationsController` (champ) ; `Catalog::CoursesController` (portée) |
| UI | UDR-0125 (inscription, profil, modale) ; UDR-0126 (catalogue, accueil, en-tête) ; UDR-0127 (page de classe, signature, listes) |

## 6. Décisions rattachées

- [ADR-0103](../../decisions/adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md) — matières par rattachement enseignant-établissement, 1 à 3, migration en deux temps
- [UDR-0125](../../decisions/udr/0125-matieres-de-l-enseignant-a-l-inscription-et-au-profil.md) — inscription et profil
- [UDR-0126](../../decisions/udr/0126-plusieurs-matieres-dans-le-catalogue-et-l-accueil-enseignant.md) — catalogue et accueil
- [UDR-0127](../../decisions/udr/0127-plusieurs-matieres-sur-la-page-de-classe-et-dans-les-listes.md) — page de classe, signature, listes

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes de « Enseignants » (direction) à 1 et 30 enseignants | constant | constant (pas de N+1 par les matières) | |
| Requêtes de l'accueil enseignant | à mesurer au Lot 0 | +0 (les matières se lisent avec le profil) | |
| Lignes `teacher_school_materials` après migration | — | = rattachements + retraits ouverts + demandes en attente (requête du journal) | |

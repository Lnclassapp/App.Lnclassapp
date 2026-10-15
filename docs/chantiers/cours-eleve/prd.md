# PRD — Page Cours de l'élève aux couleurs Wave et Djamo

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

La page « Cours » de l'élève (`/courses`, branche élève du catalogue) prend la langue visuelle du nouvel accueil élève : même en-tête, plus de barre du bas, cours groupés par matière dans l'ordre du programme, sans filtre « Matière ». Le bouton de chaque carte dit où en est l'élève (« Commencer », « Reprendre », « Revoir » avec une coche), ce qui demande de retenir les fiches qu'il a ouvertes. Le titre d'un groupe ouvre la vue de la matière, qui sert aussi aux bulles « Mes matières » de l'accueil.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir les cours publiés de son niveau groupés par matière, chercher, ouvrir la vue d'une matière, reprendre un cours à la dernière fiche ouverte | Voir les cours d'un autre niveau (404, `refuse_out_of_level`) ; voir l'avancement d'un autre élève |
| Teacher, direction, équipe | Rien ne change : filtres Niveau, Série, Matière, cartes actuelles | — |

Règles d'autorisation inchangées : `ReadsOwnLevel` (`StudentAudienceQuery`), `Policies::Catalog::ReadPublishedPolicy`. L'enregistrement d'une lecture se fait seulement pour un `Student`, sur une fiche qu'il a le droit de lire (après la policy).

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre « Cours » depuis le menu de l'avatar (téléphone, tablette) ou le menu de gauche (ordinateur).
2. Il voit le titre « Cours », l'info « Tu vois seulement les cours de ton niveau. », la recherche, puis un groupe par matière dans l'ordre du programme. Chaque titre de groupe porte l'icône, le nom complet et le nombre de cours.
3. Chaque carte montre le nom du cours, sa description sur 2 lignes et un bouton : « Commencer le cours » (rien lu), « Reprendre le cours » (au moins une fiche lue), « Revoir le cours » avec une coche verte (toutes les fiches publiées lues).
4. Il touche « Commencer le cours » : la page du cours s'ouvre. Il ouvre une fiche : elle est retenue.
5. De retour sur « Cours », la carte dit « Reprendre le cours » ; il la touche et arrive sur la dernière fiche ouverte.
6. Il touche le titre du groupe « SVT » : la vue de la matière s'ouvre (icône et nom de la matière à la place de « Cours »), la recherche est limitée à la SVT.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Recherche sans résultat | « Aucun cours trouvé » et « Essaye un autre mot. », bouton « Effacer la recherche ». |
| Pendant une recherche | Les groupes restent ; « Tout voir » apparaît et efface la recherche. |
| Élève sans classe | État actuel « sans classe », avec le nouvel en-tête. |
| Aucun cours publié pour son niveau | État actuel « Aucun cours pour l'instant ». |
| Erreur réseau pendant la recherche | État d'erreur actuel (`search#error`). |
| Plus de 24 cours | « Afficher plus de cours » ; la page suivante ne répète pas le titre du groupe déjà ouvert. |
| La dernière fiche ouverte a été dépubliée ou archivée | « Reprendre » ouvre la première fiche publiée non lue, sinon la page du cours. |
| Une fiche est publiée après que l'élève a tout lu | La carte repasse à « Reprendre le cours ». |
| Vue d'une matière | Pas de lien « Tous les cours » ; on revient par « Cours » dans le menu. |
| Bulle de « Mes matières » sur l'accueil | Ouvre la même vue de la matière (`/courses?material=<slug>`). |
| Enseignant, direction, équipe | Page actuelle inchangée (filtres, badges, ordre). |
| Élève supprimé (anonymisation) | Ses lectures sont effacées avec ses autres données d'apprentissage. |
| App Android | Même page dans la coque ; onglets natifs inchangés. |

## 4. Critères d'acceptation

```gherkin
# CA-1 Groupes dans l'ordre du programme
Étant donné un élève de 6e avec des cours publiés en SVT, Mathématiques et Français
Quand il ouvre « Cours »
Alors il voit les groupes Mathématiques, SVT, Français dans cet ordre
Et chaque titre de groupe donne le nombre de cours de la matière
Et les cartes ne répètent pas la matière

# CA-2 Plus de filtre Matière pour l'élève
Étant donné un élève sur « Cours »
Alors la page n'a pas de liste « Matière » ni de liste « Niveau »
Et « Tout voir » n'apparaît pas tant qu'il ne cherche pas

# CA-3 Le filtre reste pour l'enseignant
Étant donné un enseignant sur « Cours »
Alors il voit les listes Niveau et Matière comme avant

# CA-4 Recherche groupée
Étant donné un élève qui tape « fraction »
Quand la liste se met à jour
Alors les cours trouvés restent sous le titre de leur matière
Et « Tout voir » apparaît

# CA-5 Aucun résultat
Étant donné un élève qui tape « zzz »
Alors la page dit « Essaye un autre mot. »

# CA-6 Commencer
Étant donné un élève qui n'a ouvert aucune fiche du cours « Les fractions »
Alors sa carte dit « Commencer le cours »
Et le bouton ouvre la page du cours

# CA-7 Une fiche ouverte est retenue
Étant donné un élève qui ouvre la fiche « Simplifier une fraction »
Quand il revient sur « Cours »
Alors la carte du cours dit « Reprendre le cours »
Et le bouton ouvre la fiche « Simplifier une fraction »

# CA-8 Revoir
Étant donné un élève qui a ouvert toutes les fiches publiées du cours
Alors la carte dit « Revoir le cours » avec une coche verte
Et le bouton ouvre la page du cours

# CA-9 Nouvelle fiche publiée
Étant donné un cours que l'élève a fini
Quand une nouvelle fiche y est publiée
Alors la carte repasse à « Reprendre le cours »

# CA-10 Fiche dépubliée
Étant donné que la dernière fiche ouverte par l'élève est dépubliée
Quand il touche « Reprendre le cours »
Alors il arrive sur la première fiche publiée qu'il n'a pas lue

# CA-11 Seul l'élève est suivi
Étant donné un enseignant qui ouvre une fiche
Alors aucune lecture n'est enregistrée

# CA-12 Lecture idempotente
Étant donné un élève qui ouvre trois fois la même fiche
Alors une seule lecture existe pour cette fiche, avec la date de la dernière ouverture

# CA-13 Vue d'une matière
Étant donné un élève qui touche le titre du groupe « SVT »
Alors le titre de la page est « SVT » avec son icône
Et seuls les cours de SVT de son niveau sont listés
Et il n'y a pas de lien « Tous les cours »

# CA-14 Bulles de l'accueil
Étant donné un élève qui touche la bulle « SVT » de « Mes matières »
Alors il arrive sur la vue de la matière SVT

# CA-15 Pagination sans titre répété
Étant donné un élève dont le niveau a 30 cours
Quand il touche « Afficher plus de cours »
Alors les cartes suivantes s'ajoutent
Et un titre de groupe n'apparaît qu'une fois

# CA-16 Effacement
Étant donné un élève qui a ouvert des fiches
Quand son compte est anonymisé
Alors ses lectures sont effacées

# CA-17 Même ordre partout
Étant donné les matières Mathématiques, Physique-Chimie, SVT, Français, Histoire-Géographie, EDHC
Alors « Mes matières » sur l'accueil et les groupes de « Cours » suivent le même ordre, lu dans materials.position
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Ports::Assessment::EssentialReadRepositoryPort` (`record(student_id:, essential_id:, at:)`) ; `UseCases::Assessment::RecordEssentialRead` (élève seulement, idempotent) ; `LearningDataEraserPort` : les lectures sont effacées. |
| Infrastructure | Migration `essential_reads` (unique `student_id, essential_id`) ; migration `materials.position` avec remplissage dans l'ordre du programme ; `Orm::EssentialRead` ; `Repositories::Assessment::EssentialReadRepository` (upsert) ; `CourseCatalogQuery` : `Row` gagne `material_slug`, `material_position`, `progress` (`:new`/`:started`/`:done`), `resume_essential_slug`, et `Page` gagne `material_counts`, ordre par `materials.position` pour l'élève ; `StudentHomeQuery` et `DailyExerciseQuery` lisent `materials.position` au lieu de `SUBJECT_ORDER`. |
| Delivery | `Catalog::EssentialsController#show` et `Classroom::ClassroomEssentialsController#show` appellent `RecordEssentialRead` après la policy, pour un élève ; `Catalog::CoursesController#index` : param `after_material` pour la page suivante. Pas de nouvelle route. |
| UI | `catalog/courses/index` (branche élève) : titre ou en-tête de matière, recherche seule, groupes ; `_course_group_title` ; `_course_card` (variante élève : bouton d'avancement, icône au-dessus sur ordinateur) ; grilles 1 / 2 / 3 colonnes. |

## 6. Décisions rattachées

- [ADR-0090](../../decisions/adr/0090-lecture-des-fiches-par-l-eleve-et-rang-des-matieres.md) : table `essential_reads` et rang des matières (`materials.position`).
- [UDR-0085](../../decisions/udr/0085-page-cours-eleve-groupee-par-matiere-avec-bouton-d-avancement.md) : page Cours de l'élève groupée par matière, bouton d'avancement, vue de la matière.
- Dépend de [UDR-0084](../../decisions/udr/0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menu de l'avatar, plus de barre du bas), livrée par le chantier `accueil-eleve`.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de `GET /courses` (élève, 24 cours) | 12 (mesuré au Lot 0 : 30 cours publiés de son niveau sur 6 matières, page 1 ; idem avec `q`) | ≤ avant + 2 (comptes par matière, avancement) | 10 au Lot D, mêmes données, avec ou sans `q` (−2 : plus de référentiel pour la liste « Matière », plus de `COUNT` séparé ; +2 : comptes par matière, avancement). Vue d'une matière : 13 (le référentiel, pour son titre) |
| Part des élèves qui rouvrent un cours par « Reprendre » | inconnue (pas de suivi) | à suivre 4 semaines après la sortie | |

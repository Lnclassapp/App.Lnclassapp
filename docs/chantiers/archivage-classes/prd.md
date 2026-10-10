# PRD — Archiver une classe

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'import donne la 6ème à la Terminale à tous les établissements (ADR-0087). La direction et l'équipe doivent pouvoir mettre de côté les classes qui n'existent pas sur le terrain, même si elles ont déjà des élèves, des enseignants ou des assignations, après une confirmation. L'archivage ne supprime rien : la restauration remet la classe comme avant.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (équipe) | archiver / restaurer une classe, archiver un niveau, dans tout établissement (même inactif) | — |
| SchoolStaff (direction) | idem, dans son seul établissement, tant qu'il est actif | agir sur un autre établissement ou un établissement inactif |
| Teacher | rien ; ne voit plus la classe archivée ni ses échéances, ne peut plus y assigner | archiver, restaurer |
| Student | rien ; ne voit plus la classe archivée ; sans autre classe active, voit l'écran « Choisis ta classe » | rejoindre une classe archivée |
| Parent | hors périmètre (aucun écran concerné) | — |

Règle d'autorisation : la politique « structure d'établissement » existante (équipe partout, direction sur son seul établissement actif), appelée une fois l'établissement lu.

## 3. Parcours utilisateur

### Chemin nominal

1. La direction ouvre la liste des classes de son établissement (ou l'équipe la fiche de l'établissement).
2. Elle ouvre le menu ⋮ de la carte d'une classe et choisit « Archiver ».
3. Une confirmation indique le nom de la classe, le nombre d'élèves et d'enseignants concernés, et que rien n'est supprimé.
4. Elle confirme : la classe passe en « Archivée », reste visible 7 jours en fin de niveau, puis se masque derrière « Afficher les archives ».
5. « Archiver le niveau » (menu ⋮ du niveau) fait de même pour toutes les classes actives du niveau, avec le total de classes et d'élèves.
6. « Restaurer » (menu ⋮ d'une classe archivée) la remet active, avec ses élèves, enseignants et assignations.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Classe déjà archivée (deux onglets) | Message « déjà archivée », aucun effet, liste rafraîchie |
| Classe hors de l'année en cours ou d'un autre établissement | Introuvable, rien n'est écrit |
| Direction d'un autre établissement ou établissement inactif | Refusé (403) |
| Niveau sans classe active | L'action « Archiver le niveau » n'est pas proposée |
| Élève sans autre classe active | À sa prochaine page, écran « Choisis ta classe » |
| Élève dans plusieurs classes dont une archivée | Les autres classes restent intactes ; si c'est sa classe principale, il passe par « Choisis ta classe » |
| Page d'une classe archivée | 404 pour tous ; carte non cliquable |
| Visiteur sur le lien d'une classe archivée | Renvoyé vers l'inscription standard, averti ; l'élève connecté a « Choisir ma classe » |
| Lien d'inscription d'une classe archivée | Refuse l'élève (déjà le cas), le message nomme l'archivage |
| Restauration quand l'établissement est inactif (direction) | Refusée ; l'équipe peut |

## 4. Critères d'acceptation

```gherkin
Scénario : archiver une classe qui a des élèves, un enseignant et des assignations
  Étant donné une classe active de 12 élèves, 1 enseignant et 2 assignations
  Quand la direction de l'établissement confirme l'archivage
  Alors la classe est archivée avec sa date d'archivage
  Et les 12 adhésions, le rattachement de l'enseignant et les 2 assignations sont inchangés
  Et l'archivage est tracé à l'audit

Scénario : la confirmation chiffre l'impact
  Étant donné la même classe
  Quand la direction ouvre « Archiver »
  Alors la confirmation affiche 12 élèves et 1 enseignant

Scénario : archiver un niveau
  Étant donné un niveau de 5 classes actives et 1 déjà archivée
  Quand l'équipe archive le niveau
  Alors les 5 classes actives sont archivées, l'archivée n'est pas touchée
  Et un seul événement d'audit indique 5 classes

Scénario : restaurer
  Étant donné une classe archivée
  Quand la direction la restaure
  Alors elle est active, sans date d'archivage, avec les mêmes élèves, enseignants et assignations

Scénario : droits
  Étant donné la direction d'un autre établissement
  Quand elle tente d'archiver ou de restaurer une classe
  Alors c'est refusé et rien n'est écrit

Scénario : double archivage
  Étant donné une classe déjà archivée
  Quand on l'archive à nouveau
  Alors le résultat est un conflit « déjà archivée » et rien ne change

Scénario : visibilité de 7 jours
  Étant donné une classe archivée il y a 3 jours, et une archivée il y a 8 jours
  Quand la direction ouvre la liste
  Alors la première est visible avec le badge « Archivée » et « Restaurer »
  Et la seconde n'apparaît qu'après « Afficher les archives »

Scénario : l'élève
  Étant donné un élève dont l'unique classe est archivée
  Quand il ouvre son accueil
  Alors il voit « Choisis ta classe » et aucun exercice
  Et son en-tête ne nomme plus la classe archivée

Scénario : l'élève multi-classes (décision du porteur après le challenger, 2026-10-10)
  Étant donné un élève de deux classes dont la classe secondaire est archivée
  Alors il voit sa classe principale normalement
  Étant donné un élève dont la classe principale est archivée et qui a une autre classe active
  Alors il voit « Choisis ta classe » et choisit lui-même sa nouvelle classe principale

Scénario : la page d'une classe archivée (décision du porteur, 2026-10-10)
  Étant donné une classe archivée
  Quand l'enseignant ou l'équipe ouvre son adresse
  Alors la page n'existe pas (404) ; la classe se restaure depuis le menu ⋮ de l'établissement

Scénario : l'enseignant
  Étant donné un enseignant d'une classe archivée et d'une classe active
  Alors seule la classe active est dans sa liste et ses échéances, et il ne peut plus assigner à la classe archivée

Scénario : effectifs de la direction
  Alors les totaux d'élèves de l'établissement ne comptent pas les classes archivées

Scénario : lien d'inscription
  Étant donné le lien d'une classe archivée
  Alors un élève ne peut pas la rejoindre
  Et après restauration le même lien fonctionne
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Cas d'usage `ArchiveClassroom`, `RestoreClassroom`, `ArchiveLevelClassrooms` (contexte classroom, patron de `RemoveLevelClassroom`) ; `archived_at` ajouté à l'entité classe ; port : `archive`, `restore`, `archive_level` |
| Infrastructure | Aucune migration (`status` et `archived_at` existent). Repository : mises à jour atomiques avec verrou ; requête d'impact (élèves, enseignants) ; requêtes de liste : fenêtre de 7 jours + paramètre « archives » ; compteurs hors archivées ; libellé de classe de l'en-tête élève filtré |
| Delivery | Routes `archive` / `restore` sur la classe et `archive` sur le niveau, côté équipe et côté direction ; contrôleurs |
| UI | Menu ⋮ et confirmation sur la carte de classe et l'en-tête du niveau (équipe et direction) ; badge ; bouton « Afficher les archives » ; textes i18n `fr` |

Hors périmètre technique : le « − » du bloc « Classes par niveau » garde son comportement actuel (il compte aussi les classes archivées pour trouver la dernière).

## 6. Décisions rattachées

- ADR-0088 — Archivage d'une classe : sans blocage, réversible, lectures filtrées
- UDR-0083 — Menu ⋮ d'archivage de la classe et du niveau, confirmation et archives masquées après 7 jours
- ADR-0087 — contexte (second cycle pour tous)

## 7. Mesures

Sans objet (aucun chiffre de performance visé ; l'archivage d'un niveau est une seule requête).

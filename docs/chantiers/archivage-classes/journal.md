# Journal — [Titre du chantier]

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Ce qu'on a appris sur la codebase

- La plupart des lectures élève, enseignant et direction filtraient déjà `status = active` ; le seul trou était l'en-tête de l'élève (`shell_user_query`).
- Le lien d'inscription d'une classe archivée donnait un 404 sans message : `JoinAsStudent` refuse maintenant avec le motif d'archivage et le formulaire n'est plus offert.
- Un nouveau test système exige une durée enregistrée dans `script/ci/test_timings.yml` (`script/ci/record_timings`).

## Ce qui a été corrigé en fin de chantier

- Colonne « Classes » de la liste des établissements de l'équipe : actives seulement.
- « − » : la dernière classe d'un niveau est la dernière classe **active** ; `names_in_level` ne renvoie plus que les actives (la numérotation d'une classe nouvelle, elle, regarde toutes les classes via `names_in`).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| — | Les deux dettes de compteur sont soldées dans ce chantier : la colonne « Classes » de la liste de l'équipe et le « − » ne comptent plus les archivées | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |

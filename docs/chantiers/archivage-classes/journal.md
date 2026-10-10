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
| Sous-pages d'une classe archivée (cours, essentiels, élèves, suivi) encore lisibles par ses membres ; seule la page principale renvoie 404 | Constat bas de la revue de sécurité (2026-10-10) : policy appliquée, aucune fuite entre rôles ni établissements | à ouvrir |
| `schools:grant_second_cycle` ne laisse aucune trace d'audit | Constat bas de la revue de sécurité ; tâche unique, lancée sur Develop | à ouvrir si la tâche resert |

## Ce qui a dérapé

- Le plan supposait qu'un élève « multi-classes » verrait son autre classe : l'application n'a qu'une classe principale par élève (ADR-0040). Trouvé par le challenger ; le porteur a choisi « Choisis ta classe » plutôt qu'une promotion automatique.
- L'UDR disait la page d'une classe archivée en 404 alors qu'elle était lisible (tests existants l'exigeaient) : trois tests de lecture d'une classe archivée remplacés par le 404, sur décision du porteur.
- Les tests des trois partiels du Lot 0 ont été écrits après les partiels (passés du premier coup) ; le challenger a couvert le rendu réel.
- Les bases de test des worktrees chargeaient les seeds au `db:prepare` : `db:schema:load` à la place.

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-10 (sur `Develop`) |
| **PR** | lots fusionnés dans `Develop` ; promotion #224 (Staging), #225 (main, 2026-10-10) |
| **ADR produits** | ADR-0088 |
| **UDR produits** | UDR-0083 |

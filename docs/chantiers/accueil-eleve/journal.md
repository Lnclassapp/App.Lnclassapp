# Journal — Accueil élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Un seul chantier pour le dessin, l'exercice du jour, « fait seul » et l'invitation de l'enseignant | Choix du porteur, après avoir d'abord séparé | Non |
| 2026-10-15 | Exercice du jour calculé à la lecture, « fait seul » = session terminée sans assignation | Aucune migration, aucune écriture sur une page de lecture | ADR-0089 |
| 2026-10-15 | Placement de « fait seul », texte de l'invitation et icônes maison | Proposés par défaut, confirmés par le porteur | UDR-0084 §3.7, ADR-0089 §4.3 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `StartExerciseSession` rattache toute session à l'assignation active de l'exercice dans la classe principale (ADR-0048), quelle que soit la page de départ : `classroom_assignment_id IS NULL` veut dire « pas donné au démarrage », pas « parti du catalogue ».
- Aucune colonne n'enregistre l'origine d'une session ; les comptes de l'enseignant et de la direction filtrent tous sur `classroom_assignment_id`.
- `StudentHomeQuery` calcule `recent_sessions` à chaque affichage alors que seul le cadre lazy le lit.
- Les cours n'ont pas de position : l'ordre « du programme » est celui du catalogue (niveau, nom du cours), puis `essentials.position` et `exercises.position`.
- Ni le casque d'aide ni la porte ouverte n'existent dans Heroicons.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |

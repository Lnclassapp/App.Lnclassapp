# Journal — Les 10 premières leçons de Français de 3ème

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

- Le schéma v3 refuse avant l'adaptateur : points hors 0,5-20 ou 1,25, tolérance négative, unité > 10, critères > 8 rendent `schema` (pas `question_structure`) ; une clé inconnue est notée à la clé (`questions[0].criterias`). Une `written`/`notebook` sans explication rend `blank` ET `question_structure` à `explanation`. `script/` n'entre pas dans la couverture SimpleCov du projet : mesurée à part (module `Coverage`, 1 processus).

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

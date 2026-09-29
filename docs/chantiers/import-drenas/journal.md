# Journal — Import des DRENA par fichier

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-29 | Le repository des DRENA (`taken_names`, `insert_many`) remonte du Lot B au Lot 0 | `test/architecture/port_contracts_test.rb` exige qu'un adaptateur implémente toute méthode de son port : déclarer le port sans l'implémenter rendrait le Lot 0 rouge | Non |
| 2026-09-29 | Plafond du fichier de DRENA à 500 lignes, celui des établissements reste à 5 000 | Le porteur s'inquiétait d'une limite trop basse pour ses plus de 3 000 écoles : les 500 lignes ne concernent que les DRENA, et ses 3 851 écoles tiennent dans les 5 000 | Oui (ADR-0055 §4) |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La CI exige 100 % de couverture des lignes **et** des branches (`config/ci.rb`, ADR-0024) : chaque branche d'un adaptateur d'import doit avoir son test.
- `config/database.yml` suffixe le nom de la base par le nom du worktree : chaque worktree de lot a sa propre base.
- Le conteneur de la session avait Ruby 3.3.6, alors que `.ruby-version` exige 3.4.9 : il a fallu l'installer avec `rbenv install`, et démarrer PostgreSQL avec son rôle `dev-rails`.
- `test/infrastructure/queries/classroom/student_classroom_query_test.rb` échoue en local si la base est en collation `C.UTF-8` (tri « Écologie » / « Génétique ») : la CI utilise `en_US.utf8`. Sans lien avec le chantier.
- `bin/rails db:migrate` sous PostgreSQL 16 réécrit toutes les contraintes `ANY (ARRAY[…])` de `db/schema.rb` dans un autre format : il faut garder seulement le vrai changement.
- L'index des UDR (`docs/decisions/udr/README.md`) ne liste que 0001 à 0007, alors que les fichiers vont jusqu'à 0040.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Index des UDR incomplet (0008 à 0040 absentes) | Hors périmètre ; seule la ligne 0041 est ajoutée | à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |

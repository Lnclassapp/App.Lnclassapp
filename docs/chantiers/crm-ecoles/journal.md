# Journal — CRM des écoles

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Lot 0 : routes du suivi sous `namespace :teams` (`teams_school_*`, param `:school_public_id`), relances en `teams_follow_up_*`, port `GenerationRepositoryPort#mark_failed` (et non `fail`, qui masque `Kernel#fail`) | Les noms `school_*` existent déjà pour la fiche ; les UDR citent `teams_school_follow_up_path` et `teams_follow_ups_path` | Non (contrat gelé par le Lot 0) |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : `port_contracts_test` exige un adaptateur par port ; résolu par des adaptateurs squelettes (`NotImplementedError, "Lot X"`) livrés par le Lot 0 et repris par les Lots A, B, C, G.
- Lot 0 : les échecs du port de modèle de langage ne pouvaient pas être des codes de `Shared::Result` (liste fermée) ; décidé : `failure(:unavailable, errors: { reason: … })`, ADR modèles de langage mis à jour.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Préparer un worktree neuf (bases par worktree, assets absents) : `bin/rails db:create db:schema:load` (développement), `RAILS_ENV=test bin/rails db:create db:schema:load`, `yarn install --immutable`, `yarn build`, `yarn build:css`. Sans les assets, tout test qui rend un layout échoue sur « application.css not found ». Après une migration, `db/schema.rb` reformate trois anciennes contraintes `check` (PG16) : les remettre à l'identique avant de committer.
- `bin/system-changed` sur une branche de lot : `BASE=feature/crm-ecoles` (la base par défaut est `origin/Develop`).
- `test/architecture/port_contracts_test.rb` exige un adaptateur par port, `test/db/schema_constraints_test.rb` une liste fermée de cascades : tout nouveau port ou toute clé en cascade passe par ces deux gardes.
- Un frame paresseux dont le contrôleur n'existe pas fait lever `MissingController` à tout test système qui ouvre la page : le Lot 0 pose un squelette pour chaque adresse qu'il charge ou lie.

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

# Journal — MVP Lnclass Teacher & Student — pilote du 27 octobre

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-24 | Lot 0 : `classrooms.join_code` a un défaut en base (6 symboles tirés de `gen_random_uuid`, comme le jeton du lien), en plus de la génération du domaine | Le `insert_all!` des classes générées, le SQL brut des tests de contraintes et les graines n'appellent pas le générateur ; sans défaut, le `NOT NULL` les casse tous | Non (précision de l'ADR code de classe §4.2) |
| 2026-10-24 | Lot 0 : `find_by_join_code` et `regenerate_link_and_code` sont **implémentés** dans le repository, pas seulement posés dans le port | `test/architecture/port_contracts_test.rb` exige que l'adaptateur définisse chaque méthode du port ; le Lot A n'a plus qu'à les brancher | Non |
| 2026-10-24 | Lot 0 : l'enseignant n'a plus d'entrée « Annonces » dans la barre latérale (`DESTINATIONS[:teacher]` : accueil, classes, cours) | CA-K1 : aucune entrée de navigation ne lui propose les annonces ; routes et code gardés | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : l'ADR code de classe dit « 31 symboles, sans i, l, o, 0, 1 » et « 31⁶ ≈ 887 millions », mais la contrainte qu'il prescrit (`^[a-hj-np-z2-9]{6}$`) et `SchoolCode` en admettent 32 (le `l` est dans `j-n`). Le Lot 0 suit la contrainte et `SchoolCode` (32 symboles, 32⁶ ≈ 1,07 milliard) ; le PRD CA-B1 dit « sans i, l, o, 0, 1 » : à trancher par le porteur (retirer `l` impose la contrainte `[a-hj-kmnp-z2-9]`).

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La garde `test/guards/migration_rules_test.rb` compare à `origin/main` : sans cette référence locale (`git fetch origin main`), elle échoue sur d'anciennes migrations. La migration `20261008120000_remove_classroom_join_codes` porte maintenant l'exception `# migration-en-deux-temps:` (la colonne de 5 caractères part, celle de 6 revient dans la même livraison).
- `ActiveRecord insert_all!` ne lit ni les `attribute … default:` ni les callbacks : tout défaut d'une colonne `NOT NULL` ajoutée doit être en base.

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

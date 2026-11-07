# Journal — Cartes d'activation vendues au point relais

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## À trancher

Décisions réversibles prises par l'option prudente au Lot 0 (contrat de session §1).

- **« Caisse » dans le menu « Plus », pas dans la barre principale.** La barre basse de l'équipe a déjà 5 cases (4 destinations + « Plus ») et `NAV_GRIDS` s'arrête à 5 ; l'entrée `billing` est dans `SECONDARY_DESTINATIONS[:team]`, avant « Annonces ». À revoir si le porteur la veut en barre principale (retirer une autre case).
- **`created_by_id` (lots) et `recorded_by_id` (versements) nullables en base.** Aucune fixture de compte d'équipe n'existe (le dépôt n'a aucune fixture d'utilisateur ni d'école) ; les use cases les renseignent toujours. À passer en `NOT NULL` si le porteur préfère la garantie de base.
- **Les fixtures n'ont pas d'élève ni d'école** : les 3 cartes activées de la Boutique Awa n'ont ni `student_id` ni `school_id`, et `billing_relay_point_schools.yml` est vide. Un test qui a besoin d'un élève abonné active une carte remise via `Repositories::Billing::CardRepository#activate` (élève créé par fabrique).
- **Un accès non bloquant pour les non-élèves** : `Access.unrestricted` (statut `:subscribed`, sans date) pour enseignant, direction, équipe et compte inconnu.
- **Lot C : « Semaines précédentes » = les 8 semaines terminées avant la semaine « À payer ce vendredi »** (celle-ci n'est pas répétée dans le `<details>`), soit 9 semaines visibles au total. À revoir si le porteur veut 8 semaines en tout.
- **Lot C : le choix du point relais d'un versement porte l'identifiant interne** (`relay_point_id`), pas le `public_id` : le port gelé `RemittanceRepositoryPort#record` prend un id interne et `RelayPointRepositoryPort` (Lot A) n'est pas encore là pour résoudre un `public_id`. Formulaire réservé à l'équipe ; l'existence du point relais est vérifiée par le dépôt (échec `:invalid`). À passer au `public_id` quand le Lot A est fusionné.
- **Lot C : la caisse liste tous les points relais, actifs ou non** (un point relais désactivé peut encore devoir de l'argent) ; le choix d'un versement les propose tous aussi.
- **Lot C : la date d'un versement est libre** (pas de refus d'une date future ni ancienne) ; seule la valeur par défaut est « maintenant ».

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : `test/architecture/port_contracts_test.rb` (un adaptateur par port) reste rouge sur la branche tant que les Lots A (`RelayPointRepository`) et C (`RemittanceRepository`) n'ont pas livré leurs dépôts ; attendu, les ports sont gelés ici et les adaptateurs ailleurs.
- Lot C : `bin/system-changed` sélectionne `design_system_test.rb` et `role_homes_test.rb` (fichiers communs du Lot 0), non rejouables ici : pas de `node_modules` ni de Chrome dans cet environnement, donc pas de CSS/JS construits. Les tests de contrôleur tournent avec des `app/assets/builds/application.{css,js}` vides (ignorés par git). Aucun test système ne vise les vues du Lot C.
- Lot C : `bin/system-changed` sélectionne `design_system_test.rb` et `role_homes_test.rb` (fichiers communs du Lot 0), non rejouables ici : ni `node_modules` ni Chrome, donc pas de CSS/JS construits ; les tests de contrôleur ont tourné avec des `app/assets/builds/application.{css,js}` vides (ignorés par git). Aucun test système ne vise les vues du Lot C.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

- Les fixtures namespacées `test/fixtures/billing/*.yml` n'ont pas de classe : Rails retombe sur le nom de table, sans horodatage ni `id` automatiques (donnés explicitement) ni chiffrement (le code est chiffré par ERB avec le type de l'attribut ORM).
- `db/schema.rb` est écrit à la main dans l'ordre des colonnes de la migration : le dumper de cet environnement trie les colonnes par ordre alphabétique et réécrit tout le fichier.

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

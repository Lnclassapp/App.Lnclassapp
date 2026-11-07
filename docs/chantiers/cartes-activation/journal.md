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

Lot B (options prudentes) :

- **Texte du bandeau des 3 derniers jours.** L'UDR dit « Plus que N jours gratuits », le PRD exige « Il te reste 1 jour gratuit » au dernier jour. Le PRD (testable) gagne : la phrase reste « Il te reste N jour(s) gratuit(s) », suivie de « Abonne-toi pour 10 000 F » en avertissement (`bg-warning-soft`) et du lien « M'abonner ». À revoir si le porteur préfère « Plus que N jours ».
- **`CheckPractice` reçoit `access:` et `clock:`** (l'ADR ne nomme que `access:`) : le port lit l'accès « à un instant », le domaine n'a pas d'horloge propre.
- **Garde de `StartExerciseSession` après la policy** (comme l'ADR §6) : un acteur non élève ou un exercice non publié garde son refus (403/404) ; la garde ne voit que des élèves.
- **Vérification de fiche d'un élève bloqué qui a un devoir à rendre** : `CheckExerciseOnSheet` refuse d'abord `:assigned_pending` (avant d'appeler `StartExerciseSession`). Pas de blocage vers Mon abonnement dans ce cas précis, le démarrage du devoir passe par « Commencer ».
- **Vérification d'un entraînement de notion en frame Turbo** : une redirection n'a pas le frame, la réponse est un `turbo-frame` (402) avec le lien vers Mon abonnement (`target="_top"`) ; sans frame, redirection 303.
- **Semis `abonnements.rb` non branché** : `db/seeds.rb` (entrée `SEEDS`) et `db/seeds/standard/activite.rb` (`access:`) sont hors du champ du Lot B, à faire par l'orchestrateur.
- **Bandeau et débord de la carte.** Pendant la période gratuite, le bandeau est le premier enfant de `#student_home` (UDR : « juste avant `next_step` ») : c'est lui qui déborde sur le bandeau bleu (`-mt-12`), pas la carte. Le test système `student_home_test` (débord de la carte) abonne donc son élève. À regarder aux captures 390 px ; si le rendu déplaît, sortir le bandeau de la grille est un changement de `show.html.erb` seul.
- **Test `student_homes_controller_test` « no abonnement »** : l'élève y est abonné (`subscribe_student`) ; le bandeau est voulu pendant la période gratuite.

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : `test/architecture/port_contracts_test.rb` (un adaptateur par port) reste rouge sur la branche tant que les Lots A (`RelayPointRepository`) et C (`RemittanceRepository`) n'ont pas livré leurs dépôts ; attendu, les ports sont gelés ici et les adaptateurs ailleurs.

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

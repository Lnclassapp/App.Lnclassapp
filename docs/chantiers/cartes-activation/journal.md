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
- **Lot A, vocabulaire : « Trop de tentatives » et « tes cours » au lieu de « Trop d'essais » et « tes leçons ».** `test/i18n/locale_files_test.rb` (UDR-0007/0130) interdit « essai » et « leçon » dans les locales, hors liste fermée. Le PRD §3 et l'UDR abonnement-eleve §3.3 écrivent les anciens mots : à aligner dans le PRD/UDR à la clôture, ou à ajouter à `ALLOWED` si le porteur tient au texte exact.
- **Lot A, points relais et lots : modales avec formulaire `_top`, pas de Turbo Stream.** Le plan ne liste aucune vue `*.turbo_stream.erb` pour les points relais ; la modale s'ouvre dans le frame `modal`, le formulaire la quitte (`data-turbo-frame="_top"`) et succès = redirection vers la fiche (point relais) ou la planche (lot). Un échec de saisie se re-rend en page pleine (422) avec la modale ouverte. Passer au modèle DRENA (Turbo Stream, liste mise à jour sans recharger) demande trois vues de plus.
- **Lot A, lectures hors port dans `RelayPointRepository`.** Les ports étant gelés, l'adaptateur porte quatre lectures publiques que les ports ne déclarent pas : `batches_of` (lots d'un point relais), `school_choices`, `school_names`, `school_id_of_student` (école de la classe principale active, pour `ActivateCard` et Mon abonnement ; `StudentSchoolQuery` ne rend pas l'identifiant). À promouvoir en port ou en query `Queries::Billing::*` si le porteur veut la forme stricte.
- **Lot A, fiche d'un point relais sans versements ni chiffres de caisse** (UDR caisse-equipe §3.3) : ils dépendent de `RemittanceRepository` et de `CashboxQuery`, lot C ; la fiche montre l'identité, les écoles et les lots. À brancher par C ou par un petit lot de suite.
- **Lot A, écoles à cocher sans filtre par DRENA ni recherche** (UDR §3.2) : liste des écoles actives par nom, « Nom (DRENA) », en cases à cocher. À reprendre avec un filtre quand le nombre d'écoles gêne.
- **Lot A, planche : cartes de `w-60 h-36` (≈ 63 × 38 mm)** car `design_tokens_test` refuse les valeurs arbitraires `[…]` et l'attribut `style` ; 3 × 21 cartes tiennent sur un A4 (marges 8 mm). Vérifier à l'impression réelle.
- **Lot A, `test/system/role_homes_test.rb` (AN-22) rouge, hérité du Lot 0** : le menu « Plus » de l'équipe montre désormais « Caisse » avant « Annonces » ; le test attend `["Référentiel", "Imports", "Annonces"]`. Fichier hors champ du lot A : à corriger par le Lot 0 (ou l'orchestrateur).
- **Lot C : « Semaines précédentes » = les 8 semaines terminées avant la semaine « À payer ce vendredi »** (celle-ci n'est pas répétée dans le `<details>`), soit 9 semaines visibles au total. À revoir si le porteur veut 8 semaines en tout.
- **Lot C : le choix du point relais d'un versement porte l'identifiant interne** (`relay_point_id`), pas le `public_id` : le port gelé `RemittanceRepositoryPort#record` prend un id interne et `RelayPointRepositoryPort` (Lot A) n'est pas encore là pour résoudre un `public_id`. Formulaire réservé à l'équipe ; l'existence du point relais est vérifiée par le dépôt (échec `:invalid`). À passer au `public_id` quand le Lot A est fusionné.
- **Lot C : la caisse liste tous les points relais, actifs ou non** (un point relais désactivé peut encore devoir de l'argent) ; le choix d'un versement les propose tous aussi.
- **Lot C : la date d'un versement est libre** (pas de refus d'une date future ni ancienne) ; seule la valeur par défaut est « maintenant ».

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : `test/architecture/port_contracts_test.rb` (un adaptateur par port) reste rouge sur la branche tant que les Lots A (`RelayPointRepository`) et C (`RemittanceRepository`) n'ont pas livré leurs dépôts ; attendu, les ports sont gelés ici et les adaptateurs ailleurs.
- Lot C : `bin/system-changed` sélectionne `design_system_test.rb` et `role_homes_test.rb` (fichiers communs du Lot 0), non rejouables ici : pas de `node_modules` ni de Chrome dans cet environnement, donc pas de CSS/JS construits. Les tests de contrôleur tournent avec des `app/assets/builds/application.{css,js}` vides (ignorés par git). Aucun test système ne vise les vues du Lot C.

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

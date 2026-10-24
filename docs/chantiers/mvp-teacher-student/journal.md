# Journal — MVP Lnclass Teacher & Student — pilote du 27 octobre

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-24 | Lot 0 : `classrooms.join_code` a un défaut en base (6 symboles tirés de `gen_random_uuid`, comme le jeton du lien), en plus de la génération du domaine | Le `insert_all!` des classes générées, le SQL brut des tests de contraintes et les graines n'appellent pas le générateur ; sans défaut, le `NOT NULL` les casse tous | Non (précision de l'ADR code de classe §4.2) |
| 2026-10-24 | Lot 0 : `find_by_join_code` et `regenerate_link_and_code` sont **implémentés** dans le repository, pas seulement posés dans le port | `test/architecture/port_contracts_test.rb` exige que l'adaptateur définisse chaque méthode du port ; le Lot A n'a plus qu'à les brancher | Non |
| 2026-10-24 | Lot 0 : l'enseignant n'a plus d'entrée « Annonces » dans la barre latérale (`DESTINATIONS[:teacher]` : accueil, classes, cours) | CA-K1 : aucune entrée de navigation ne lui propose les annonces ; routes et code gardés | Non |
| 2026-10-24 | Lot A : le code passe par le DTO (`StudentRegistrationInput#join_code`) et `ClassroomDesignation#coded` / `#coded_or_chosen`, partagés par `RegisterStudent`, `JoinAsStudent` et `ChangeClassroom` ; priorité lien valide > code > cascade, un code inconnu ne retombe pas sur la cascade | Une seule règle de désignation pour les trois cas d'usage ; un code archivé ou d'un établissement inactif répond « inconnu » comme à la vérification (CA-B3) | Non (précision de l'ADR code de classe §4.6) |
| 2026-10-24 | Lot A : `POST /students/classroom` est limité au même compteur `classroom/joins` (10 par minute et par IP) | Sinon un élève connecté devine des codes sans limite par ce POST : l'ADR ne le disait pas, la vérification seule ne suffit pas | Non |
| 2026-10-24 | Lot A : « Changer le lien et le code » est journalisé en `school.changed` (`change: classroom_link_and_code_changed`, classe, acteur, date), sans le jeton ni le code | Réutilise l'action d'audit existante des changements de classe ; aucun secret dans le journal | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : l'ADR code de classe dit « 31 symboles, sans i, l, o, 0, 1 » et « 31⁶ ≈ 887 millions », mais la contrainte qu'il prescrit (`^[a-hj-np-z2-9]{6}$`) et `SchoolCode` en admettent 32 (le `l` est dans `j-n`). Le Lot 0 suit la contrainte et `SchoolCode` (32 symboles, 32⁶ ≈ 1,07 milliard) ; le PRD CA-B1 dit « sans i, l, o, 0, 1 » : à trancher par le porteur (retirer `l` impose la contrainte `[a-hj-kmnp-z2-9]`). **Tranché le 24 octobre** : le porteur retire le `l` ; fait au Lot A (31 symboles, contrainte `[a-hjkmnp-z2-9]`, défaut SQL sur deux octets modulo 31). `SchoolCode` garde ses 32 symboles.

- Lot A : l'ADR et CA-B4 écrivent « Trop d'essais » ; `test/i18n/locale_files_test.rb` interdit « essai » à l'écran (UDR-0007). Le message est « Trop de tentatives. Attends une minute, puis réessaie. » (comme `/c/<jeton>`) ; PRD, ADR et UDR inscription alignés sur « Trop de tentatives » (UDR-0007).
- Lot A : la fiche ne listait ni `ClassroomDesignation`, ni `StudentRegistrationInput`, ni `StudentArrivalChannel`, ni `ClassroomLinksController` ; ils sont inséparables de « RegisterStudent résout par code » (aucun autre lot ne les touche). `StudentRegistrationsController` (Lot B) doit encore accepter `join_code` dans `FIELDS` et partager le compteur à l'envoi.

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

# Journal — Cartes d'activation vendues au point relais

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-07 | Lot A, fiche d'un point relais : chiffres de caisse et versements branchés au Lot D (`CashboxQuery`, `RemittanceRepository#for_relay_point`), bouton « Enregistrer un versement » pré-rempli. | Intégration des lots A, B, C | Non |
| 2026-11-07 | `test/system/role_homes_test.rb` (AN-22) attend désormais `Référentiel, Imports, Caisse, Annonces` dans « Plus » de l'équipe (corrigé au Lot D). | Intégration des lots A, B, C | Non |
| 2026-11-07 | Lot C, versement : le formulaire envoie `relay_point_public_id`, `RecordRemittance` le résout par `RelayPointRepository#find(public_id:)` (inconnu : `:invalid`) ; plus d'identifiant interne à l'écran. | Intégration des lots A, B, C | Non |
| 2026-11-07 | Semis : `standard/abonnements` branché dans `SEEDS` et `access:` ajouté à `StartExerciseSession` dans `db/seeds/standard/activite.rb` (Lot D). | Intégration des lots A, B, C | Non |

## À trancher

Décisions réversibles prises par l'option prudente au Lot 0 (contrat de session §1).

- **« Caisse » dans le menu « Plus », pas dans la barre principale.** La barre basse de l'équipe a déjà 5 cases (4 destinations + « Plus ») et `NAV_GRIDS` s'arrête à 5 ; l'entrée `billing` est dans `SECONDARY_DESTINATIONS[:team]`, avant « Annonces ». À revoir si le porteur la veut en barre principale (retirer une autre case).
- **`created_by_id` (lots) et `recorded_by_id` (versements) nullables en base.** Aucune fixture de compte d'équipe n'existe (le dépôt n'a aucune fixture d'utilisateur ni d'école) ; les use cases les renseignent toujours. À passer en `NOT NULL` si le porteur préfère la garantie de base.
- **Les fixtures n'ont pas d'élève ni d'école** : les 3 cartes activées de la Boutique Awa n'ont ni `student_id` ni `school_id`, et `billing_relay_point_schools.yml` est vide. Un test qui a besoin d'un élève abonné active une carte remise via `Repositories::Billing::CardRepository#activate` (élève créé par fabrique).
- **Un accès non bloquant pour les non-élèves** : `Access.unrestricted` (statut `:subscribed`, sans date) pour enseignant, direction, équipe et compte inconnu.
- **Lot A, vocabulaire : « Trop de tentatives » et « tes cours » au lieu de « Trop d'essais » et « tes leçons ».** `test/i18n/locale_files_test.rb` (UDR-0007/0130) interdit « essai » et « leçon » dans les locales, hors liste fermée. Le PRD §3 et l'UDR abonnement-eleve §3.3 écrivent les anciens mots : à aligner dans le PRD/UDR à la clôture, ou à ajouter à `ALLOWED` si le porteur tient au texte exact.
- **Lot A, points relais et lots : modales avec formulaire `_top`, pas de Turbo Stream.** Le plan ne liste aucune vue `*.turbo_stream.erb` pour les points relais ; la modale s'ouvre dans le frame `modal`, le formulaire la quitte (`data-turbo-frame="_top"`) et succès = redirection vers la fiche (point relais) ou la planche (lot). Un échec de saisie se re-rend en page pleine (422) avec la modale ouverte. Passer au modèle DRENA (Turbo Stream, liste mise à jour sans recharger) demande trois vues de plus.
- **Lot A, lectures hors port dans `RelayPointRepository`.** Les ports étant gelés, l'adaptateur porte quatre lectures publiques que les ports ne déclarent pas : `batches_of` (lots d'un point relais), `school_choices`, `school_names`, `school_id_of_student` (école de la classe principale active, pour `ActivateCard` et Mon abonnement ; `StudentSchoolQuery` ne rend pas l'identifiant). À promouvoir en port ou en query `Queries::Billing::*` si le porteur veut la forme stricte.
- **Lot A, écoles à cocher sans filtre par DRENA ni recherche** (UDR §3.2) : liste des écoles actives par nom, « Nom (DRENA) », en cases à cocher. À reprendre avec un filtre quand le nombre d'écoles gêne.
- **Lot A, planche : cartes de `w-60 h-36` (≈ 63 × 38 mm)** car `design_tokens_test` refuse les valeurs arbitraires `[…]` et l'attribut `style` ; 3 × 21 cartes tiennent sur un A4 (marges 8 mm). Vérifier à l'impression réelle.
- **Lot C : « Semaines précédentes » = les 8 semaines terminées avant la semaine « À payer ce vendredi »** (celle-ci n'est pas répétée dans le `<details>`), soit 9 semaines visibles au total. À revoir si le porteur veut 8 semaines en tout.
- **Lot C : la caisse liste tous les points relais, actifs ou non** (un point relais désactivé peut encore devoir de l'argent) ; le choix d'un versement les propose tous aussi.
- **Lot C : la date d'un versement est libre** (pas de refus d'une date future ni ancienne) ; seule la valeur par défaut est « maintenant ».

Lot B (options prudentes) :

- **Texte du bandeau des 3 derniers jours.** L'UDR dit « Plus que N jours gratuits », le PRD exige « Il te reste 1 jour gratuit » au dernier jour. Le PRD (testable) gagne : la phrase reste « Il te reste N jour(s) gratuit(s) », suivie de « Abonne-toi pour 10 000 F » en avertissement (`bg-warning-soft`) et du lien « M'abonner ». À revoir si le porteur préfère « Plus que N jours ».
- **`CheckPractice` reçoit `access:` et `clock:`** (l'ADR ne nomme que `access:`) : le port lit l'accès « à un instant », le domaine n'a pas d'horloge propre.
- **Garde de `StartExerciseSession` après la policy** (comme l'ADR §6) : un acteur non élève ou un exercice non publié garde son refus (403/404) ; la garde ne voit que des élèves.
- **Vérification de fiche d'un élève bloqué qui a un devoir à rendre** : `CheckExerciseOnSheet` refuse d'abord `:assigned_pending` (avant d'appeler `StartExerciseSession`). Pas de blocage vers Mon abonnement dans ce cas précis, le démarrage du devoir passe par « Commencer ».
- **Vérification d'un entraînement de notion en frame Turbo** : une redirection n'a pas le frame, la réponse est un `turbo-frame` (402) avec le lien vers Mon abonnement (`target="_top"`) ; sans frame, redirection 303.
- **Bandeau et débord de la carte.** Pendant la période gratuite, le bandeau est le premier enfant de `#student_home` (UDR : « juste avant `next_step` ») : c'est lui qui déborde sur le bandeau bleu (`-mt-12`), pas la carte. Le test système `student_home_test` (débord de la carte) abonne donc son élève. À regarder aux captures 390 px ; si le rendu déplaît, sortir le bandeau de la grille est un changement de `show.html.erb` seul.
- **Test `student_homes_controller_test` « no abonnement »** : l'élève y est abonné (`subscribe_student`) ; le bandeau est voulu pendant la période gratuite.

Lot E (corrections issues des revues) :

- **Droit d'imprimer la planche : toute l'équipe, pas seulement les admins** (`ManageBillingPolicy`, comme la création du lot). Décision de droits réversible, option inchangée ; chaque affichage est journalisé (`billing.card_batch_printed`, sans code), ce qui rend l'abus traçable. Restreindre aux admins = une policy de plus.
- **Pas de garde sur la remise d'une copie déjà ouverte.** Un élève bloqué peut finir et rendre une séance ouverte avant le blocage ; seuls le démarrage et la vérification d'une fiche sont gardés.
- **Messages d'activation : code inconnu, utilisé et annulé restent distincts.** L'énumération n'est pas exploitable (31^12 codes, 5 essais par 10 minutes et par élève) et l'élève a besoin de savoir quoi faire (« Rapporte-la au point relais »).
- **Annuler une carte remise ne change pas le « dû » de la caisse.** La consigne du Lot E disait « dû −10 000 » ; l'ADR §4.7 définit `dû = Σ prix des cartes activées − Σ versements` : une carte remise non activée n'y entre pas, l'annuler fait seulement passer « en circulation » de 15 à 14. Le test suit l'ADR. Le PRD (« sort de la circulation et du dû ») est à relire : sa phrase vaut pour la circulation.
- **Date de versement illisible : message ajouté à `billing_cashbox.fr.yml`** (`received_at.invalid`), fichier hors de la liste du lot mais seul endroit du texte de ce DTO.

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

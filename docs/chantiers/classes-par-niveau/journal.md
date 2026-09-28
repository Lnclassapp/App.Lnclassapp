# Journal — Ajuster le nombre de classes par niveau d'un établissement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Numéros ADR-0059 et UDR-0046 : le plus haut de `Develop` (0056, 0043) + 3 | Consigne du coordinateur : quatre chantiers tournent en parallèle et prendraient 0057/0044 | Noté dans l'ADR et l'UDR |
| 2026-09-28 | Une classe jamais utilisée est **supprimée**, pas archivée ; une classe utilisée est refusée | L'ADR-0036 ne protège que les classes qui ont servi ; `DeleteSchool` supprime déjà les classes vierges ; une classe archivée resterait comptée dans la fiche et le tableau | Oui — ADR-0059 |
| 2026-09-28 | « − » porte l'identifiant de la classe nommée par la confirmation, refusée si elle n'est plus la dernière | Un double envoi ou un ajout concurrent ne doit pas retirer une autre classe que celle que l'équipe a lue | Oui — ADR-0059 |
| 2026-09-28 | Contrôle du niveau et de la série extrait de `CreateClassroom` dans `Entities::Classroom::Placement` | « + » applique les mêmes règles qu'« Ajouter une classe » sans les recopier ; les tests de `CreateClassroom` n'ont pas bougé | Oui — ADR-0059 §4 |
| 2026-09-28 | Audit sous `school.changed` (`classroom_added` / `classroom_removed`), pas d'action nouvelle | Le sujet est l'établissement (la classe retirée n'existe plus) ; éviter une collision sur `AuditAction::ALL` avec le chantier « photo de profil » | Oui — ADR-0059 §4 |
| 2026-09-28 | Nom déjà pris deux fois de suite → `:conflict` `base: [:name_taken]` plutôt que `name: [:taken]` | Aucun formulaire ne porte de champ « nom » : le contrôleur n'a qu'une règle (motif de `base`, sinon le code) | Non |
| 2026-09-28 | Nouvelle query `LevelClassroomsQuery` plutôt qu'un ajout à `SchoolDetailQuery` | Le chantier « code d'établissement » modifie `SchoolDetailQuery` ; un fichier à part évite le conflit, et le bloc se re-rend seul dans la réponse Turbo Stream | Non |
| 2026-09-28 | Réponse Turbo Stream : bloc remplacé (morph) **et** `refresh` de la fiche après un succès | Le bloc répond tout de suite ; le titre « Classes (N) » et les cartes suivent par le même `refresh` qu'« Ajouter une classe » (UDR-0031) | UDR-0046 |

## Ce qui a dérapé

- TDD : 68 tests lancés sur les fichiers concernés avant le code : 41 erreurs (constantes, méthodes de port, routes absentes), 0 vert inattendu ; puis vert sans retouche des tests, sauf deux.
- Un test de contrôleur prévoyait `stub_any_instance` pour simuler un nom pris deux fois : la méthode n'existe pas avec minitest 6. Le cas est couvert dans le domaine, et le motif est passé en `base: [:name_taken]` pour que le contrôleur n'ait plus de branche à part.
- Le test existant « SC-05 » comptait `section[aria-labelledby] h3` : le bloc, section nommée elle aussi, le faisait passer de 2 à 3. Sélecteur resserré sur `aria-labelledby^=level_`.
- Première capture au bureau : en grille à deux colonnes, `last:border-b-0` laissait une bordure sous l'avant-dernière ligne seulement. Bordure passée en haut de chaque ligne.
- Le titre de la fiche est « Classes (5) », pas « 5 classes » : première version du test système corrigée avant exécution.

## Ce qu'on a appris sur la codebase

- `ui_modal(trigger:)` accepte un contenu HTML : un `span.sr-only` suffit pour un déclencheur icône seule avec un nom accessible, sans toucher au composant.
- `Orm::Classroom.lock.exists?(id:)` pose bien `FOR UPDATE` : c'est le même verrou que `lock_by_join_code`, ce qui sérialise un retrait et une adhésion.
- Les clés étrangères vers `classrooms` sont toutes `restrict` : même un oubli dans `delete_if_unused` ne supprimerait pas une classe utilisée.

## Vérifications (2026-09-28, local)

- `bin/rubocop` : 826 fichiers, aucune offense.
- `bin/rails test` : 1 897 tests, 0 échec ; couverture 100 % lignes (6 948) et 100 % branches (1 535).
- `COVERAGE=0 bin/rails test:system` : 146 tests, 0 échec (dont 4 nouveaux, au bureau et à 390 px).
- `bin/brakeman -q --no-pager` : aucune alerte.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Le refus conseille « archivez-la plutôt », mais aucun geste n'archive une seule classe | Hors périmètre (ADR-0041 : archivage de l'année, V3) | à ouvrir si le porteur confirme le besoin |
| Pas de saisie d'un nombre cible par niveau | Hors périmètre ; les use cases le permettraient en boucle | — |
| Décisions par défaut du memo à confirmer par le porteur (suppression physique, « − » sur un établissement non actif, audit sous `school.changed`) | ADR-0059 et UDR-0046 restent « Proposé » | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-28 |
| **PR** | *(ouverte par le coordinateur)* |
| **ADR produits** | ADR-0059 (précise ADR-0036 et ADR-0041) |
| **UDR produits** | UDR-0046 |

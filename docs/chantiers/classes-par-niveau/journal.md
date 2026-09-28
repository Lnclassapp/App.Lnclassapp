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

- **Bug bloquant trouvé par le challenger (PR #48)** : après un « − » refusé (422 ou 404), la `<dialog>` perdait son attribut `open` sous le `replace … method: :morph` mais restait `:modal` (couche supérieure) : toute la page devenait inerte jusqu'au rechargement, au bureau comme à 390 px. `modal#submitEnd` ne ferme qu'un envoi réussi, et le morphing retire `open` sans appeler `close()`. Le test système ne le voyait pas : le refus était toujours la dernière action du parcours. Test rouge ajouté (refus puis menu ⋮ et « + », et le 404 d'un second onglet, à 1 280 et 390 px : 4 échecs « une <dialog> reste modale »), puis correctif générique dans `modal_controller` : un `MutationObserver` sur `open` referme vraiment (`close()`) une boîte restée modale sans `open`. Toute modale morphée en profite (refresh, menus de ligne UDR-0042).

- **Test instable** (challenger, 2026-09-28) : à 390 px et sous charge (`PARALLEL_WORKERS=4`), le clic sur le menu ⋮ de l'en-tête dans `assert_page_usable` était intercepté. Deux causes mesurées : un toast d'erreur encore affiché, et, surtout, la barre supérieure collante du shell, sous laquelle Selenium amène le bouton en le faisant défiler juste au bord de l'écran (`Other element would receive the click: …px-gutter…`). Le test ferme désormais les toasts par leur vrai bouton et attend qu'ils aient quitté la page, puis remonte en haut avant de cliquer. Sous la même charge, une réponse Turbo Stream dépassait parfois les 2 s d'attente par défaut : les toasts de ce test sont attendus 10 s.
- **« + » restait offert après « Désactiver » ou un passage en brouillon par « Modifier »** depuis la fiche : les streams `deactivate` et `update` ne remplaçaient que l'en-tête. Ils remplacent aussi `school_level_classrooms` (test système rouge d'abord, 2 échecs).

- **Régression sur `Develop` après la fusion de la PR #48** (commit `697340c6`, conflits résolus sans la PR #49) : la route `school_code` (ADR-0057), les lignes d'index ADR-0057 et UDR-0044, et les tests CE-06 de la fiche ont disparu, si bien que la fiche d'un établissement lève `undefined method 'school_code_path'`. La branche `fix/classes-par-niveau-suivi` les rétablit tels que les avait résolus `b43ebdd9`.

## Ce qu'on a appris sur la codebase

- `ui_modal(trigger:)` accepte un contenu HTML : un `span.sr-only` suffit pour un déclencheur icône seule avec un nom accessible, sans toucher au composant.
- `Orm::Classroom.lock.exists?(id:)` pose bien `FOR UPDATE` : c'est le même verrou que `lock_by_join_code`, ce qui sérialise un retrait et une adhésion.
- Retirer l'attribut `open` d'une `<dialog>` ouverte par `showModal()` ne la retire pas de la couche supérieure dans Chrome : seul `close()` le fait. Tout morphing (Turbo 8) d'une boîte ouverte y est exposé.
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
| La vérification « dernière du niveau » se fait hors verrou : un « + » concurrent entre la vérification et la suppression ferait retirer une classe qui n'est plus la dernière (vide, donc sans perte, mais numérotation trouée). La déplacer sous le `FOR UPDATE` de la classe ne suffirait pas (un verrou de ligne n'empêche pas l'insertion d'une autre classe) : il faudrait verrouiller la ligne de l'établissement dans l'ajout **et** le retrait, donc toucher `SchoolRepositoryPort`, partagé avec les chantiers parallèles | Fenêtre de quelques millisecondes, conséquence bénigne | à ouvrir après les merges parallèles |
| Pas de saisie d'un nombre cible par niveau | Hors périmètre ; les use cases le permettraient en boucle | — |
| Décisions par défaut du memo à confirmer par le porteur (suppression physique, « − » sur un établissement non actif, audit sous `school.changed`) | ADR-0059 et UDR-0046 restent « Proposé » | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-28 |
| **PR** | *(ouverte par le coordinateur)* |
| **ADR produits** | ADR-0059 (précise ADR-0036 et ADR-0041) |
| **UDR produits** | UDR-0046 |

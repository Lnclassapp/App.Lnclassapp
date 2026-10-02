# Journal — La direction gère son établissement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-01 | Numéros ADR-0071 et UDR-0056 | ADR-0069 et 0070 sont pris sur des branches ouvertes (`perf/ci-quota`, `ccr-9b7287af-3kx7cj`) ; ADR-0065 à 0067 et UDR-0052, 0053 d'`espace-direction` sont en collision avec `Develop` | — |
| 2026-10-01 | Deux policies au lieu d'élargir `ManageSchoolPolicy` | Elle ouvre aussi l'import, les DRENA et la validation des comptes en attente (Q1) ; et l'équipe ne retire pas d'enseignant (grill 9) | ADR-0071 §4.1 |
| 2026-10-01 | Table `teacher_school_departures` | Sans trace du retrait, le code reprend l'enseignant aussitôt (grill 5) | ADR-0071 §4.4 |
| 2026-10-01 | Adaptateurs des nouvelles méthodes de port au Lot 0 | Leçon du challenge 1 d'`espace-direction` : `port_contracts_test` casse sinon | — |
| 2026-10-01 | Bloc « Classes par niveau » déplacé en partiel partagé au Lot 0 | La direction et l'équipe ont le même gabarit ; deux vues de l'équipe (`update`, `deactivate`) le rendaient aussi, trouvées par la recherche des appelants | UDR-0056 §3.2 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

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


## Lot 0 — Socle (2026-10-01)

**Statut : fusionné** dans `feature/gestion-etablissement-direction` (commit `4990a645`). Table `teacher_school_departures`, entité, trois policies, port de départ et trois méthodes de port **avec leurs adaptateurs**, `OwnSchoolQuery`, routes de l'UDR-0056 §3.0, troisième destination, page « Établissement » en lecture, bloc « Classes par niveau » déplacé en `shared/_level_classrooms` (les tests de la fiche de l'équipe passent sans modification), fabrique `create_teacher_departure`.

Portes (agent, revérifiées par le porteur du chantier sur 248 tests ciblés et un chargement du schéma dans une base vierge) : rubocop 0 offense ; 2 625 tests unitaires, couverture 100 % ; 291 tests système ; migrate / rollback / migrate. **Deux étapes de `bin/ci` rouges, étrangères au lot** : `bin/brakeman` (`--ensure-latest` refuse la 8.0.6 depuis la sortie de la 8.1.0 ; 0 alerte sans l'option) ; `heavy_screens_budget_test` « pilotage 7 j » (p95 339 ms pour 300 ms, déjà rouge à 324 ms sur le commit de base : lenteur de la machine locale).

Écarts : trois tests existants modifiés au minimum (`school_admin_routes_test` : liste fermée des cinq écritures ; `student_work_test` : trois entrées ; `models_test` : 37 modèles) ; `db/schema.rb` complété à la main (le dump local PG16 réécrivait toutes les contraintes CHECK).

Corrections de documents qui en découlent : GD-02 (une direction sans établissement reçoit 403, comme DS-11) ; déclaration des routes de l'UDR-0056 §3.0 (le `resource :school` imbriqué ne donnait pas les noms du tableau) ; clés `on_delete: :restrict` dans l'exemple de migration de l'ADR-0071 ; `JoinRequestsQuery#status_for` rend un `Status` de tout état (le Lot D ne passe à la policy qu'une demande `pending`) ; dossiers de worktree courts pour la vague 2.

## Vague 2 — Lots A, B, C, D (2026-10-01)

**Statut : fusionnés** dans `feature/gestion-etablissement-direction`. Après fusion, sur la branche du chantier : 2 744 tests, 0 échec, couverture 100 % (lignes 9 441, branches 2 350) ; 66 tests système (direction, identité, établissement, code) ; rubocop 0 offense ; Brakeman 0 alerte (`bundle exec brakeman`, voir plus bas).

- **Lot A** (`c3002605`) — « Changer le lien » : `RegenerateSchoolCode` lit l'établissement puis applique `ManageSchoolStructurePolicy` ; modale sur établissement actif ; `:conflict` (aucun code libre après 5 tirages) → toast et 422, non prévu par l'ADR.
- **Lot B** (`91aa6d07`) — « + » et « − » : même ordre dans `AddLevelClassroom` et `RemoveLevelClassroom` ; la direction d'un établissement inactif ou en brouillon reçoit 403 (policy) avant le conflit `school_inactive` / `school_draft` de l'équipe.
- **Lot C** (`2f7c40a2`, `8820d368`) — retirer : `DetachTeacher` ; un retrait qui ne supprime aucune ligne `teacher_schools` vaut `:not_found` (double onglet, enseignant d'un autre établissement).
- **Lot D** (`6de5d538`) — retirés, réintégrer, rejoindre par code ou par lien (GD-28) ; une demande `approved` n'affiche plus « en cours de validation ».

## Ce qui a dérapé (vague 2)

- **GD-12 à moitié rempli** par le Lot B : le partiel partagé gardait le « − » sur un établissement inactif (l'équipe en a encore le droit). Corrigé par le porteur du chantier, Lot 0 rouvert (`c4e8d640`, option `remove_when_inactive: false`).
- **Une query d'infrastructure injectée dans un use case** par le Lot D (`JoinSchoolWithCode`), faute d'une méthode de port : l'ADR citait `JoinRequestsQuery` comme lecture réutilisée, sans dire qu'un use case ne la lit pas. Corrigé, Lot 0 rouvert (`26ea93d3`, `JoinRequestRepositoryPort#pending_for`). Leçon : dans l'ADR, toute lecture qu'un **use case** fait doit être un port.
- **La commande Brakeman du brief était fausse** (`--no-ensure-latest` n'existe pas) ; `bin/brakeman` ajoute toujours `--ensure-latest`, qui refuse la 8.0.6 en local depuis la sortie de la 8.1.0. La CI GitHub, elle, passe.
- **Une CI « rouge » sur `c4e8d640`** : exécution annulée par la poussée suivante (`tests: cancelled`), pas un échec.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Le sous-titre « N enseignants » n'est pas mis à jour après un retrait en Turbo Stream | L'UDR-0056 §3.3 ne le demande pas ; l'en-tête n'a pas d'identifiant | Prochaine retouche de l'UDR-0052 |
| Les refus émis par `SchoolAdmin::BaseController` (autres rôles) gardent « Accès interdit. » (`errors.codes.*`), les gestes « Vous n'avez pas accès à cette action. » | Deux textes de refus dans le même espace | Idem |
| `Teams::SchoolCodesController` : un `:conflict` (aucun code libre) rend `render nil` | Préexistant, hors périmètre | À ouvrir en bugfix si un jour observé |
| `bin/brakeman` force `--ensure-latest` : rouge en local dès qu'une version sort | Outillage du dépôt | Mettre à jour la gem, ou retirer l'option du binstub |
| Régénérer en masse les liens (équipe) | Demandé, sorti du chantier | `regeneration-codes-en-masse` (backlog) |

## Challenge empirique (phase 5, 2026-10-01)

Rôle distinct des auteurs, application lancée (`bin/rails server`), Playwright + Chromium en 390×844 tactile et en 1280×900, sur `f7755609`. **Les 7 points sont OK** : lien (copier, WhatsApp, changer ; ancien `/e/` en 404 « Code d'établissement invalide ») ; « + » et « − » (refus 422 au motif sur une classe qui a un élève) ; retrait (3 devoirs actifs de A archivés par la direction, le devoir de B reste actif, sessions et classes intactes, enseignant connecté renvoyé vers l'écran d'attente) ; retour (code de A refusé, lien de B pré-rempli puis rejoint, 429 au 11ᵉ essai) ; réintégration ; refus forgés (404 inter-établissements, 403 établissement inactif et équipe, rien d'écrit) ; aucune erreur 500, aucune clé manquante, aucun défilement horizontal de page.

Anomalies :
- **Moyenne, corrigée** : à 390 px, le menu ⋮ de « Enseignants » était hors écran (tableau défilant dans sa carte, bouton à x = 533). Colonne d'actions collée au bord droit (`sticky right-0`), avec un test système qui mesure la position du bouton (rouge à 581 px avant la correction).
- Mineure, sans correction : « Copier le lien », « Partager sur WhatsApp », « Enseignants retirés », « Réintégrer » font 40 px **visibles** (`size: :sm`, prescrit par l'UDR) ; leur cible tactile est de 48 px (`after:-inset-1` du gabarit `sm`).
- Mineure, **à trancher par le porteur** : la modale du « − » et le refus disent « archivez-la plutôt », texte de l'équipe, alors que la direction ne peut pas archiver une classe.
- Mineure, **à trancher par le porteur** : toast de réintégration au masculin (« Il doit redéclarer ses classes ») ; date « 1 octobre » au lieu de « 1er octobre ».
- Non exécuté : limite de débit sur le lien `/e/` lui-même (couverte par les tests existants), deux onglets simultanés (simulé par un second `DELETE`), états `aria-busy`, gestes de l'équipe à l'écran (GD-05, GD-13 couverts par les tests).

## Textes tranchés par le porteur (2026-10-01)

- **« − » refusé** : « archivez-la plutôt » renvoyait à un geste qui n'existe pas (personne n'archive une classe avant `vie-de-la-classe`, ADR-0041) ; les trois refus deviennent « … : elle ne peut plus être retirée. » et la confirmation « Seule une classe qui n'a jamais servi peut être retirée. ». Vaut pour l'équipe et la direction (UDR-0046 amendée).
- **Réintégration** : tournure neutre, « <nom> est de nouveau dans l'établissement et doit redéclarer ses classes. » (UDR-0056 §3.4).
- **Date** : « Retiré le 1er octobre 2026 » le premier du mois (UDR-0056 §3.4).
- **PR #126** passée de brouillon à prête pour relecture, vers `Develop`.

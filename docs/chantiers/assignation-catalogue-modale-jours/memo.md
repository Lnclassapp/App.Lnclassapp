# Memo — Une modale chargée juste après la fermeture d'une autre n'arrive jamais

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-11-12 |
| **Branche** | `fix/assignation-catalogue-modale-jours` |
| **Programme** | — |

---

## Symptôme

Le test système `test/system/classroom/catalog_assignment_test.rb:32` échoue par intermittence avec
`expected to find css "turbo-frame#modal dialog[open]" but there were no matches` (train #545, part `system 4/6` ; en local
2 échecs sur 3 le 2026-11-12). La ligne rapportée est celle du bloc `assert_no_page_reload` : l'échec est en fait dans
`open_in_modal` (`test/support/turbo_assertions.rb:18`), qui ouvre la fenêtre des jours de Tle D 1 juste après « Annuler »
sur la modale des jours de Tle D 2. Le frame `modal` reste vide.

## Reproduction

1. Une modale servie dans le frame `modal` est ouverte (ici, les jours de Tle D 2 depuis la feuille de la notion).
2. On la ferme (« Annuler », Échap ou la croix), puis, **avant que le navigateur ait livré l'événement `close`** (une tâche
   plus tard, 1 à 15 ms selon la charge), on charge une autre page dans le frame `modal`.
3. Rien ne s'ouvre : la requête de la seconde modale est annulée, le frame est vide.

Reproduit en instrumentant le test (journal des événements Turbo et des mutations du frame) : `turbo:before-fetch-request
modal …/session_days/edit`, frame `busy`, puis `dialog close session-days-modal`, puis `src` retiré et frame vidé.

## Comportement attendu

UDR-0006 : un lien `data-turbo-frame="modal"` ouvre sa modale ; la fermeture d'une modale ne fait que libérer le frame.

## Portée

Tous les acteurs, toute modale du frame `modal`. Un humain atteint rarement la fenêtre (une tâche), mais une machine
chargée l'élargit ; aucune donnée écrite (lecture seule côté serveur). Pas de réparation.

## Hors périmètre

- Les autres tests intermittents du train.
- Le compteur d'assertions de `assert_no_page_reload`, qui rapporte la ligne du bloc et non celle de l'échec (journal).

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit (test instrumenté, journal des événements) avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (`src` retiré alors que le frame charge)
- [x] Correctif appliqué dans la couche de la **cause** (`modal_controller.js`), pas dans le test
- [x] Test au vert · test système 20/20
- [x] Cas symétrique : rien ne charge → le frame est toujours libéré (test node « frees the modal frame »)
- [x] Données déjà corrompues : aucune
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(classroom): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés

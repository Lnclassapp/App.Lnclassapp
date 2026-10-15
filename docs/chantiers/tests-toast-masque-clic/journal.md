# Journal — Un toast ne masque plus le clic suivant dans les tests système

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | `dismiss_toasts` passe de `classrooms_by_level_test` à `TurboAssertions`, appelé après le toast qui précède un clic dessous | Le même geste qu'un utilisateur (bouton « Fermer la notification ») ; fermer d'office dans `assert_toast` casserait les tests qui vérifient la survie du toast | Non |

## Ce qui a dérapé

- Rien.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `teams/classroom_archival_test.rb:55` instable (élément du menu ⋮ remplacé entre recherche et clic) | Cause différente | à ouvrir si elle revient |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15 |
| **PR** | [#249](https://github.com/Lnclassapp/App.Lnclassapp/pull/249) |
| **ADR produits** | — |
| **UDR produits** | — |

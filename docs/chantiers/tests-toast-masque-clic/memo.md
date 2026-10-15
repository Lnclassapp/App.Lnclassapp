# Memo — Un toast ne masque plus le clic suivant dans les tests système

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `fix/tests-toast-masque-clic` |
| **Programme** | — |

---

## Le problème

En suite parallèle, deux tests système échouaient au hasard par `ElementClickInterceptedError` : un toast de succès (5 s, en bas à droite) recouvrait le bouton du clic suivant.

- `classroom/catalog_assignment_test.rb:29` : « Assigner » de Tle D 2 sous le toast de Tle D 1 (vu sur #247 et #242) ;
- `teams/blog_management_test.rb:71` : le menu ⋮ de l'article sous le toast « publié » (vu sur #242).

Rejoués seuls, ils passaient : la panne dépend de la charge et du moment du clic.

## Pour qui

L'équipe : la preuve `bin/ci` exigée avant fusion (ADR-0069) ne doit pas rougir au hasard.

## Pourquoi maintenant

Les fusions des pages élève (#240 à #248) l'ont rencontré deux fois en une soirée.

## Hors périmètre

- Aucun changement de l'application : le toast reste où et autant qu'UDR le prévoit.
- `assert_toast` ne ferme pas le toast d'office : des tests vérifient qu'il survit à un rafraîchissement ou le referment eux-mêmes.
- `teams/classroom_archival_test.rb:55` (`StaleElementReferenceError` dans le menu ⋮ du niveau) : autre cause, non traitée ici.

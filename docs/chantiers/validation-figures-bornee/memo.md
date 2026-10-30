# Memo — Validation des figures bornée

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `perf/validation-figures-bornee` |

---

## Le problème

`Entities::Catalog::Figure.errors_for` (`app/domain/entities/catalog/figure.rb`) contrôle la cohérence d'une figure même quand `params_errors` vient de refuser une liste trop longue (`nodes` > 12, `areas` > 40, `labels` > 12, `points` > 12…). Ces contrôles cherchent dans des tableaux à l'intérieur d'une boucle : coût quadratique, cubique pour un arbre en chaîne (`rooted?` remonte de parent en parent avec `seen.include?`). Une leçon de quelques centaines de Ko, sous `ImportKind::MAX_BYTES`, occupe le worker d'import pendant des heures. Constat de la revue de sécurité avant le train vers la production ; dette notée au journal du programme [`contenus-3e-autres-matieres`](../contenus-3e-autres-matieres/journal.md).

## Pour qui

Le worker d'import, donc tous les comptes. Seul un compte Team (`Policies::Catalog::ManageContentPolicy`) peut envoyer la leçon ; les lectures n'appellent que `Figure.from_raw`.

## Pourquoi maintenant

Le code des figures part en production au prochain train `Staging` → `main`.

## Mesure avant

Machine : conteneur de session, Ruby 3.4.9. Méthode : `ruby docs/chantiers/validation-figures-bornee/bench.rb <N> [sorte]` sur `Develop` (`aa72011`), médiane de 3 exécutions, chaque exécution coupée à 60 s. Pire cas par sorte (décrit en tête du bench).

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Durée de `Figure.errors_for` | `diagram` `tree` en chaîne, 5 000 nœuds | > 60 s (coupé) ; 1,7 s à 1 000, 11,5 s à 2 000 | < 50 ms | bench, médiane de 3 |
| Durée de `Figure.errors_for` | `map`, 5 000 aires (moitié inconnue, puis une aire connue répétée) | 50,6 ms | < 50 ms | bench, médiane de 3 |
| Durée de `Figure.errors_for` | `plate`, 5 000 étiquettes et 5 000 surlignages (moitié inconnue, puis une partie connue répétée) | 653,6 ms | < 50 ms | bench, médiane de 3 |
| Durée de `Figure.errors_for` | `geometry`, 5 000 points | 116,7 ms | < 50 ms | bench, médiane de 3 |

## Mesures après

Même machine, même bench, médiane de 3, sur le head de la branche.

| Volume | Avant | Après (coupure + `Set`/`Hash`) | Levier `Set`/`Hash` seul (coupure retirée pour la mesure) |
|---|---|---|---|
| `diagram` `tree`, 5 000 nœuds | > 60 s | 0,03 ms | 35,05 ms (368 ms à 50 000) |
| `map`, 5 000 aires | 50,6 ms | 0,01 ms | 12,07 ms (135 ms à 50 000) |
| `plate`, 5 000 étiquettes | 653,6 ms | 0,02 ms | 25,17 ms (294 ms à 50 000) |
| `geometry`, 5 000 points | 116,7 ms | 0,01 ms | 7,93 ms (101 ms à 50 000) |

Le levier `Set`/`Hash` seul rend le coût linéaire (×10 en volume, ×10 en durée) ; la coupure le rend constant.

## Hors périmètre

- Les bornes elles-mêmes (`FigureKinds`) : inchangées.
- `script/contenus/valider.rb` : il appelle `Figure.errors_for`, la parité suit sans modification.
- Le dessin des figures (`app/javascript/lib/figures/`).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Où couper ? | Dans `required_errors`, une seule fois pour toutes les sortes : une liste au-delà de sa borne saute le contrôle de cohérence de la sorte | La garde propre à `molecule_errors` devient inutile et est retirée |
| Le code d'erreur change-t-il ? | Non : la violation de borne (`params.<liste>`, `figure_invalid`) vient de `params_errors`, inchangée | Les violations secondaires d'une figure déjà refusée pour sa taille disparaissent (ex. `params.labels[12].part`) |
| Une figure valide change-t-elle ? | Non : la sortie de `valider.rb` est identique, octet pour octet, avant et après, sur toutes les leçons rangées | — |

## Cas limites identifiés

- Une liste qui n'est pas un tableau : déjà refusée par `params_errors`, `list_of` la lit vide ; pas de coupure nécessaire.
- Un identifiant non textuel dans un `Set` : il était déjà refusé par `text?` ou `known.include?` ; `Set` (via `eql?`) et `==` ne divergent que sur des valeurs refusées de toute façon.

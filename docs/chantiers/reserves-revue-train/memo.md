# Memo — Réserves basses de la revue du train du 2026-11-15

| | |
|---|---|
| **Type de cycle** | correction |
| **Statut** | en revue |
| **Ouvert le** | 2026-11-15 |
| **Branche** | `fix/reserves-revue-train` |
| **Programme** | — |
| **Issue** | [#643](https://github.com/Lnclassapp/App.Lnclassapp/issues/643) |

---

## Le problème

La revue `security-reviewer` du train #642 n'a rien trouvé de bloquant et consigne deux réserves de robustesse (#643), une par chantier d'origine :

1. [`test-restauration-purge-instable`](../test-restauration-purge-instable/memo.md) (#638) : si l'attente du verrou échoue par `flunk`, le `ensure` libère la restauration mais le fil `purger` n'est jamais joint. Un fil qui écrit en base après la fin de son test fabrique un échec inexplicable dans un autre test.
2. [`couverture-branches-visible`](../couverture-branches-visible/memo.md) (#637) : `bin/ci-quiet` passait les fichiers touchés par `$COVERAGE_TOUCHED`, séparé par des espaces. Pas d'injection de commande (une expansion de paramètre ne subit que le découpage en champs et l'expansion de chemins), mais un chemin avec une espace serait coupé en deux, un `*` ou un `?` développé : l'avertissement de couverture dirait « aucun test ne charge ce fichier » à tort.

## La solution

1. `purger&.join` dans le `ensure` du test, après `commit << true`.
2. Les fichiers touchés passent en arguments positionnels après un `--`, sans shell : `script/ci/unit_coverage <sortie> <touché>… -- <test>…` joue les tests puis appelle `script/ci/coverage_touched <résultat> <sortie> -- <touché>…`. Un test de la ligne de commande avec un chemin contenant une espace échouait avant (le `--` était lu comme un fichier), et passe après.

## Hors périmètre

- Les seuils de couverture.
- La réserve jumelle du point 1 : la requête `pg_stat_activity` attend *une* connexion bloquée de la base courante, pas spécifiquement la purge. Classée sans correctif par l'issue ; les trois assertions finales vérifient toujours la propriété métier.

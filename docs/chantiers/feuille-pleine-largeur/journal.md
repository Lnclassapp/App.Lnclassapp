# Journal — La feuille remplit l'écran du téléphone

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

- Le libellé du bouton a été mal compris deux fois (« Continuer » toujours, puis une question) avant le choix « Commencer l'exercice » : la demande du pilote (« changer continue pas commencer ») se lisait « par » ; une capture de l'écran visé a levé le doute. Montrer l'écran avant de coder un libellé.
- `width: auto` sur le bouton le réduisait à son texte et le centrait (`.ps-page` est en `align-items: center`) : `align-self: stretch`.

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Revues (sécurité, pannes, tests) non lancées | diff sous 150 lignes de code, sans use case, policy, route ni téléversement | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-04 |
| **PR** | [#469](https://github.com/Lnclassapp/App.Lnclassapp/pull/469) vers `Develop` |
| **ADR produits** | — |
| **UDR produits** | UDR-0154 (amende UDR-0149 §3, UDR-0151 §3, UDR-0152 §3) |

# Journal — Fiche : formules dans les listes de l'entraînement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- …

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

**Rapport de cause.**

1. Chaîne : `Catalog::RevisionSheetsController` (fiche) ou `Catalog::PracticeChecksController` (après « Vérifier », frame `practice_<slug>`) → `catalog/revision_sheets/_sheet` (`data-controller="math"`) → `catalog/practice_checks/_question.html.erb` → `select_tag … options_for_select` → `math_controller.js` → `renderMathInElement`.
2. Cause : `app/views/catalog/practice_checks/_question.html.erb`, ligne 41-42 (liste : `[answer.content, at]`) et lignes 74-79 (ordre et relier : `items` = `content` ou `match_content` en libellés d'option). Le LaTeX devient le texte d'une `<option>`, qui n'affiche que du texte ; KaTeX ignore `option`.
3. Trou de test : `practice_helper.rb` n'a que des mots (« juste 0 », « Décomposer », « racine de 9 ») ; aucun test ne croise menu et formule. Test de reproduction : système, le défaut est le rendu dans le navigateur.

Sans les mots du symptôme : la vue confie du LaTeX à un élément qui n'affiche que du texte brut.

- Dans la fiche, ordre et relier n'ont pas de cartes JavaScript (contrairement à la copie) : les menus sont l'interface.

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

# Journal — Une modale chargée juste après la fermeture d'une autre n'arrive jamais

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

- La ligne rapportée par Minitest (43 sur le train) est celle du bloc `assert_no_page_reload`, pas celle de l'échec : le
  premier clic « Assigner » n'était pas en cause. Le message exact (`… dialog[open]` sans `with text`) désignait
  `open_in_modal`. Pistes écartées par le journal d'événements : clic avant Stimulus (Stimulus et Turbo chargés au clic),
  réponse remplacée par un morphing (aucun `turbo:morph` après), double clic (un seul `click`), `travel_to` (sans effet sur
  l'horloge du navigateur ni sur le frame).
- Instrumenter par `execute_script` juste avant le clic décalait le minutage et masquait l'échec ; le script injecté par
  `Page.addScriptToEvaluateOnNewDocument` avant la visite l'a laissé paraître (3 échecs sur 12).

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- **Chaîne d'appels** : « Annuler » (`data-action="modal#close"`) → `ModalController#close` → `dialog.close()` retire `open`
  tout de suite (le test voit la modale fermée) mais le navigateur **met en file** l'événement `close`. Le test (ou
  l'utilisateur) charge alors une autre page dans le frame : Turbo pose `src` et `busy`, la requête part. L'événement `close`
  arrive ensuite → `ModalController#closed` → `frame.removeAttribute("src")` (Turbo annule la requête en cours) et
  `frame.replaceChildren()`.
- **Cause** : `app/javascript/controllers/modal_controller.js`, `closed()` (garde avant `removeAttribute("src")`) supposait
  que le frame contenait encore la modale qui se ferme ; il ne regardait pas si un autre chargement l'occupait déjà.
- **En une phrase** : le nettoyage différé du frame partagé ne distinguait pas son propre contenu d'un chargement plus récent.
- **Correctif** : `closed()` ne touche pas au frame tant qu'il est `busy` ; la réponse attendue remplacera la boîte fermée.
- **Trou de test** : les tests JS du contrôleur ne couvraient que `submitEnd` ; les tests système enchaînent fermeture et
  ouverture sans contrôler l'ordre des tâches, d'où un échec dépendant de la charge. Deux tests node couvrent désormais
  `closed()` (frame libre → libéré ; frame `busy` → laissé).

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

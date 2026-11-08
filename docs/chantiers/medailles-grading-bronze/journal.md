# Journal — medailles-grading-bronze

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-08 | `class_badge_for` rend « Pas encore » sans médaille enregistrée dans la classe, même avec des notes (copies vides seulement) | PRD §3 : aucun exercice médaillé → « Pas encore » ; la revue a montré Bronze pour des copies vides | ADR médailles lues à la clôture (§4) |
| 2026-11-08 | Les écrans élève ne recalculent plus la médaille du score : `medal_tag(level)` reçoit la médaille lue (enregistrée pour un exercice, `Grading.session_medal` pour une session) | Une copie vide disait Bronze à l'historique et « Pas encore » au résultat | ADR médailles lues à la clôture (§4) |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-08 · #526 · Sécurité (ADR-0097 §4.5) : un enseignant peut-il lire une médaille gagnée par son élève dans une autre classe (exercise_badges est une ligne par élève et exercice) ? — appliqué : non, une médaille ne se lit dans une classe que si `exercise_badges.exercise_session_id` est une session d'une de ses assignations (`Queries::Assessment::Medals`, fiche élève, liste de classe, accueil enseignant, compréhension résumé et détail). Coût : la médaille ne monte que vers un palier supérieur ; un élève Bronze dans A puis Or dans B n'a plus de médaille lisible dans A (« Pas encore », note gardée) ; autres : amender ADR-0097 §4.5 pour assumer la lecture toutes classes ; ou calculer la médaille de classe depuis les sessions traitées de l'assignation (`Grading.session_medal` sur leur meilleur score, sans lire exercise_badges) ; recommandé : la troisième, qui ne perd rien et ne lit rien d'ailleurs.
- [ ] 2026-11-08 · #526 · Écran de résultat : quelle médaille montrer, celle de la session ou celle que l'élève détient sur l'exercice ? — appliqué : celle de CETTE session (`Grading.session_medal` : le palier de son score si la copie est traitée, rien pour une copie vide) ; un Or qui refait à 20 % lit Bronze et « Prochaine médaille : Argent », sans fête ; autres : la médaille détenue (Or + « Prochaine : Diamant », l'ancien comportement de la PR) ; les deux (« Cette copie : Bronze · Ta médaille : Or ») ; recommandé : appliqué.
- [ ] 2026-11-08 · #526 · Un exercice fait de questions du cahier (aucun champ, tentative `unanswered`) donne-t-il une médaille ? — appliqué : oui, une question du cahier rend la copie traitée (Bronze au moins), pour ne pas retirer la médaille qu'il donnait avant ; conséquence : une copie vide d'un exercice qui a une question du cahier a aussi Bronze ; autres : le cahier ne compte jamais (un exercice tout cahier ne médaille plus) ; recommandé : appliqué tant que le cahier n'a pas de case « fait ».
- [ ] 2026-11-08 · #526 · Une médaille gagnée en classe A disparaît de A si l'élève monte ensuite en « fait seul » ou dans la classe B (`BadgeRepository` réécrit `exercise_session_id` quand le palier monte) : l'enseignant de A voit « Pas encore » — appliqué : accepter pour l'instant (cas couvert par `test/infrastructure/queries/assessment/medals_test.rb`) ; autres : calculer la médaille de classe depuis les sessions traitées de l'assignation (voir la première entrée) ; recommandé : appliqué tant que la première entrée n'est pas tranchée.


## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

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

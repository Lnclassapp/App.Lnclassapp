# Journal — Parcours d'exercice de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Texte à trous : sans casse ni accents ni espaces en trop, plusieurs réponses justes, faute de frappe fausse | Choix du porteur | ADR-0091 §4.3 |
| 2026-10-15 | Nombre : marge facultative par question, virgule ou point | Choix du porteur | ADR-0091 §4.3 |
| 2026-10-15 | Ordre et relier : tout juste ou faux, pas de points partiels | Choix du porteur ; la note, les badges et les lacunes ne changent pas | ADR-0091 §4.3 |
| 2026-10-15 | La page poste des indices d'affichage, jamais des ids, pour l'ordre et relier | Les ids sont créés dans l'ordre des positions : ils révéleraient la solution | ADR-0091 §4.4 |
| 2026-10-15 | Ordre ou relier faux : « Ton choix » ne dit pas quelle étape ou paire est fausse | Sinon l'élève retrouve la solution en recommençant ; confirmé par le porteur | UDR-0087 §3.5 |
| 2026-10-15 | Nombre illisible : erreur de saisie, la question n'est pas comptée | Confirmé par le porteur | ADR-0091 §4.3 |
| 2026-10-15 | Lot 0 : `AnswerShuffle.for(session_id:, …)` et non `session_public_id:` | L'ancien mélange tirait sa graine de l'id entier de la session (`session_id ^ question_id`) ; garder cette graine est la seule façon qu'une session ouverte se reprenne à l'identique | ADR-0091 §4.4 (écart de signature) |
| 2026-10-15 | Lot 0 : chaque type de question est une classe à méthodes de classe (`structure_errors`, `well_formed?`, `correct?`, `INPUT`, `INVALID`) | `Question` délègue sans instancier ; `INPUT` dit au use case quoi lire (ids, texte, indices) et `INVALID` l'erreur à rendre | ADR-0091 §4.3 |
| 2026-10-15 | Lot 0 : un type n'est proposé au formulaire de l'équipe que si son partial `kinds/_<type>_fields` existe | Les quatre lots livrent chacun leur type sans toucher au formulaire commun | ADR-0091 §4.5 |

## Ce qui a dérapé

- Lot 0 : la construction d'une question importée était copiée dans les trois imports ; elle passe dans `ContentTreeWriterPort::QuestionNode.from_import` pour n'ajouter `tolerance` et `match` qu'une fois.
- Lot 0 : le test de caractérisation de `ContentTreeWriter` compare des lignes entières ; les deux colonnes nouvelles en sont retirées et vérifiées vides à part, plutôt que de réécrire l'instantané de 380 Ko.

## Ce qu'on a appris sur la codebase

- Tout le moteur supposait « cocher parmi des propositions » : CHECK sur `question_type`, `selected_answer_ids` non vide, `correct?` par égalité d'ensembles d'ids.
- Le mélange des propositions est déjà déterministe par session (`SessionPlayQuery`), ce qui permet de reconstituer les ids côté serveur.
- « Quitter la session » n'était qu'un lien : la session reste `started` et se reprend.
- Le shell rend l'en-tête et les barres sur toutes les pages, sauf dans l'app Android : pas de mode concentré avant ce chantier.
- Les trois formats d'import (`exercises`, `essentials`, `course-tree`) partagent la même forme de question.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points partiels (ordre, relier) | Refusés par le porteur pour garder la note intacte | — |
| Tolérance aux fautes de frappe (texte à trous) | Refusée par le porteur | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0091 |
| **UDR produits** | UDR-0087 |

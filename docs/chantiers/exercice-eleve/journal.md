# Journal — Parcours d'exercice de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Texte à trous : sans casse ni accents ni espaces en trop, plusieurs réponses justes, faute de frappe fausse | Choix du porteur | ADR-0091 §4.3 |
| 2026-10-15 | Nombre : marge facultative par question, virgule ou point | Choix du porteur | ADR-0091 §4.3 |
| 2026-10-15 | Ordre et relier : tout juste ou faux, pas de points partiels | Choix du porteur ; la note, les badges et les lacunes ne changent pas | ADR-0091 §4.3 |
| 2026-10-15 | La page poste des indices d'affichage, jamais des ids, pour l'ordre et relier | Les ids sont créés dans l'ordre des positions : ils révéleraient la solution | ADR-0091 §4.4 |

## Ce qui a dérapé

- …

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

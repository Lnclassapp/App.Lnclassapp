# Journal — « Je m’entraîne » dans la fiche de révision

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- « Je m'entraîne » a déjà existé : `contenu-en-blocs` (CA-7, CA-8, Lot C) l'avait livré, avec un générateur « Entraînement illimité », une correction dans le navigateur et les réponses dans la page (`data-answer`). Il a été retiré par `refonte-contenus-maths` (#362, commit `da631f6`), et l'ancien code se lit avec `git show da631f6^:<chemin>`. Les maquettes (Thalès, Lentilles, Texte argumentatif) sont toujours dans `docs/design/fiches-cours/fiches/`.
- Lot 0 (socle) : le dépôt n'a pas de fixtures YAML pour `questions`, `answers` ni `essentials` (les tests posent leurs données par `test/support/factories/`, et `fixtures :all` ne charge que `question_images.yml`). Les fixtures du plan n'ont pas été créées : des lignes `questions` exigeraient des `exercises` et des `courses` de fixtures, et fausseraient les décomptes des tests existants. Les lots A à C posent leur donnée par la fabrique `revision_sheet_document` (un `practice`, un `hint` et un `blank` s'y ajoutent en une clé).
- Lot 0 : `PortContractsTest` reste rouge tant que `ExerciseSessionRepository#record_hint` (Lot A) et `EssentialRepository#practice_for` (Lot C) ne sont pas écrits : les ports sont gelés, les adaptateurs ne sont pas dans le champ du Lot 0.
- Lot 0 : « Trop d'essais d'un coup » (UDR §3.5) est refusé par `LocaleFilesTest` (UDR-0073 : jamais « essai ») ; le libellé posé est « Trop de vérifications d'un coup : attends une minute. ».
- Lot 0 : `NotionPractice#without_correction` vide les réponses des types chiffré, trous, rédigé et cahier ; ordering et matching gardent leurs éléments (nécessaires à l'affichage) dans l'ordre des positions : le Lot C doit les mélanger avant de les rendre.
- Lot C : trois tests (use case, parité CA-5, système « deux cases ») attendent `blank_results` du Lot A : ils se sautent par `skip_until_lot_a_blank_results` (test/support/practice_helper.rb) et se réveillent seuls après la fusion de A. `PortContractsTest` ne reste rouge que sur `record_hint` (Lot A) ; `practice_for` est écrit.
- Lot C : deux clés (`notebook`, `unscored`) ajoutées à `config/locales/catalog/revision_sheets.fr.yml` (fichier du Lot 0) : libellés manquants au gel.

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

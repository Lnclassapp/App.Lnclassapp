# Journal — « Fiche de cours » et « Fiche de révision » à l'écran

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-12 | Le chantier, ouvert pour « Fiche de révision », renomme aussi « Cours » en « Fiche de cours » | Décision du porteur au grill (question 6) | Non : UDR-0130 |
| 2026-10-12 | UDR numérotée 0084 | 0078 à 0083 déjà pris sur d'autres branches | — |
| 2026-10-19 | UDR renumérotée 0130 à la mise à jour sur `Develop` | `Develop` a pris 0084 le 2026-10-15 (accueil élève) et 0129 est pris sur une autre branche | — |
| 2026-10-19 | Catalogue public arrivé par `Develop` : tout se renomme, titres compris (« Les fiches de cours par niveau ») | Décision du porteur à la reprise | Non : amendement de l'UDR-0130 |
| 2026-10-19 | Remédiation arrivée par `Develop` : renommage strict, seuls « Fiche(s) à revoir » gardent « Fiche » seul | Décision du porteur à la reprise | Non : amendement de l'UDR-0130 |
| 2026-10-12 | Correctif du menu ⋮ qui sort de l'écran à 390 px, ajouté au chantier | Vu par le challenger sur les captures, défaut antérieur au chantier ; le porteur demande de le corriger ici | Non : amendement de l'UDR-0042 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Lot 0 rouge refusé par le pre-commit** (2026-10-12) : le hook lance tout test stagé et refuse un rouge. Le plan voulait committer la garde rouge au Lot 0. Elle a été écrite et vue rouge (2 échecs, 62 clés listées), puis mise de côté et committée à l'intégration, une fois A, B et C mergés. Leçon : sur ce dépôt, un « test rouge du chantier » se prouve dans le journal, pas dans un commit. Les fichiers de traduction ne déclenchent aucun test au pre-commit.
- **Tests système rouges hérités de `Develop`** (2026-10-12) : `94fc2d0d` (connexion : numéro en chiffres, aide « code secret à 4 chiffres ») n'a pas aligné ses tests système, que le pre-commit ne joue pas. 6 assertions sur 4 fichiers attendaient encore `01 00 00 00 09` ou l'absence de « 4 chiffres » ; alignées dans ce chantier à la demande du porteur.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Les fichiers de traduction ne déclenchent aucun test au pre-commit. Seuls les tests stagés et les miroirs de `app/*.rb` sont lancés.
- `db/seeds/demo/saint_michel.rb` s'arrête sur `CreateMessage` (mot-clé `illustrations` manquant) après l'import des leçons, donc avant les élèves joués, les lacunes et les annonces. C'est un défaut antérieur au chantier ; les captures ont été faites avec une lacune créée à la main.
- Un menu ⋮ absolu, aligné à droite de son bouton, sortait de l'écran dès que le bouton passait à gauche (390 px). Il est corrigé dans le contrôleur (UDR-0042, amendement du 2026-10-12).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Seed de démonstration cassé (`CreateMessage` sans `illustrations`) | Hors périmètre, défaut des annonces | à ouvrir (`/bugfix`) |
| « fiches de cours de Anglais » (lecteur d'écran de l'accueil enseignant) sans élision | Défaut antérieur (« cours de Anglais »), demande une règle d'élision | à ouvrir |
| « fiche essentielle » dans le contenu des leçons JSON de `docs/contenus/lecons-traitees/` | Données de contenu, hors périmètre (memo) | à reprendre avec `contenu-en-blocs` |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |

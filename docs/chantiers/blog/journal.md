# Journal — Blog de Lnclass

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | Ouvrir le chantier `blog`, hors plan de `refonte-application` : un blog public de Lnclass, écrit par l'équipe, lisible sans compte. Quatre objectifs : se faire connaître, rassurer et convaincre, aider à réussir, annoncer les nouveautés. Hors périmètre : commentaires, abonnement, publication programmée | Demande du porteur (« créer le blog de Lnclass ») ; la rentrée et le démarchage en cours | Non — le rattachement à une vague est tranché au grill |
| 2026-10-02 | Fin des questions : le porteur délègue les choix restants (« arrête de me poser des questions… crée un système de blog et puis c'est tout »). Grill 12 retenu par défaut ; hôte canonique `lnclass.com` par défaut ; le passage de la phase 3 à la phase 4 se fait sans nouvelle validation | Consigne explicite du porteur | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Branche partie d'un `Develop` périmé.** Dans le conteneur, la référence `origin/Develop` avait 181 commits de retard (`c6d7977` au lieu de `8354045`, PR #142) : `git status` disait « à jour ». Repéré par l'exploration de la documentation (UDR-0056 à 0063 et ADR-0069 à 0072 absents de l'arbre), rattrapé par un merge avant toute écriture de fond. Parade : `git fetch origin Develop` avant de brancher.
- **Lot 0 interrompu par un redémarrage du conteneur** après la sous-étape 0.1 : le travail de 0.2 a été sauvé dans un commit de point de sauvegarde (`1e479240`), puis relu et vérifié par mutation (30 mutants tués) à la reprise. Parade : committer et pousser après chaque élément vert.
- **Migration renommée** `20261003120000_create_articles.rb` (le plan disait `20261004090000`) : Rails refuse une migration datée de plus d'un jour dans le futur.
- **Assainisseur de l'ADR-0073 §6 inopérant tel qu'écrit** : le `:prune` de Loofah supprime `<action-text-attachment>` avant le filtre. Corrigé par `ArticlePrune`, qui n'épargne que la pièce jointe d'image d'article ; en mode article, `<img>` sort de la liste blanche (BL-16). Le mode des cours, fiches et imports est inchangé.
- **Tests système non joués en local** au Lot 0 (pas de Chrome dans le conteneur au départ) : la CI les joue.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- **Docs périmées, à ne pas suivre** (relevées par l'exploration du 2026-10-02) : `docs/guide/conventions.md` §7 (cliquet de couverture à 45 % : il désigne l'ancien dépôt, la CI impose ici 100 %, ADR-0024) et §8 (`OpenStruct` : abandonné, le contrat réel est `call` + `Shared::Result`, ADR-0026) ; `docs/blueprints/use_case.md` (même écart) ; `docs/workflows/feature.md` (« les ports `communication` existent déjà » : faux ici) ; `docs/guide/architecture.md` (cite un contrôleur de messages qui n'existe pas) ; `docs/guide/glossaire.md`, entrée SchoolStaff (fonction et second facteur, retirés par l'ADR-0065).
- Le contexte `communication` porte déjà des pages publiques statiques sans table (`/aide`, UDR-0061 ; `/mission` et les trois pages juridiques, UDR-0063). Aucune table `communication` n'existe : les annonces (ADR-0045) ne sont pas codées.

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

# Épuration des en-têtes de contenu et « Tout publier »

| | |
|---|---|
| **Type** | feature (petite), demande directe du porteur |
| **Statut** | livré sur `fix/epuration-entetes-contenus` |
| **Décisions** | [UDR-0042, amendement du 2026-09-30](../../decisions/udr/0042-actions-de-ligne-dans-un-menu.md) · [UDR-0007, amendement du 2026-09-30](../../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · [ADR-0035, amendement du 2026-10-01](../../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md) |

## Le problème

Les en-têtes des pages cours, fiche et exercice, vues par l'équipe, étaient chargés : un bouton par transition, et deux boutons de création sur la fiche. Publier un cours complet demandait aussi un clic par cours, par fiche et par exercice.

## Demande du porteur

**2026-09-30**

- **Cours** : « Archiver » va dans le menu ⋮.
- **Fiche** : seul le statut reste visible. « Archiver », « Nouvel exercice » et « Importer des exercices » vont dans le menu.
- **Exercice** : « Archiver » va dans le menu, et le statut prend sa place.
- **Vocabulaire** : « Fiches essentielles » devient « Essentielles de la leçon », et le nombre d'exercices de chaque fiche n'est plus affiché.

**2026-10-01**

- Un bouton « Tout publier » dans le menu du cours, qui publie toutes ses fiches et leurs exercices.
- Le même bouton sur la fiche.

## Décisions prises (sans grill, à valider à l'usage)

- **Toutes les transitions passent dans le menu** : « Publier » comme « Archiver », sur les trois pages, par cohérence. L'en-tête ne garde que le statut.
- **Seuls les brouillons descendent** : la cascade ne republie rien d'archivé.
- **Exercices incomplets** : un exercice sans question complète reste en brouillon, et le toast le dit.
- **Racine non publiée** : la cascade publie aussi la racine si elle ne l'est pas, y compris un cours archivé.
- **Une seule transaction** : chaque publication est inscrite au journal par son propre use case.
- **Portée du vocabulaire** : « Essentielles de la leçon » s'applique aux deux listes des fiches d'un cours, dans le catalogue et dans la page d'un cours d'une classe. Ailleurs, « Fiche essentielle » reste le nom (UDR-0007).

## Hors périmètre

- Archiver en cascade.
- Un « Tout publier » sur la liste du catalogue.

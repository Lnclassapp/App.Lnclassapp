# Journal — Historique de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | Un compte ajouté à `StudentArchiveQuery` | Non |
| 2026-10-15 | La carte bleue donne le vrai total, la liste reste limitée à 200 | La liste est bornée (`RESULTS_LIMIT`), le total ne doit pas mentir | Non |
| 2026-10-15 | `ResultRow` gagne `material_slug` (Lot 0) | Les illustrations des matières sont choisies par slug (`subject_illustration`, UDR-0069 §3.3), pas par catégorie : la catégorie ne donnerait que trois icônes | Non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- La couleur de la note suivait `Grading::PASS_THRESHOLD` (50 %) ; les écrans élève redessinés passent tous à 70 % (14/20).
- `StudentArchiveQuery` n'exposait aucun total : seulement les 200 derniers résultats.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | UDR-0090 |

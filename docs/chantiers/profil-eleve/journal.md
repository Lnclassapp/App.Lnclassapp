# Journal — Profil de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | `ProfileQuery#school_name` existe déjà ; il est seulement rempli pour l'élève | Non |
| 2026-10-15 | « Se déconnecter » sans confirmation | Même action que le menu du compte, qui n'en demande pas | Non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- `ProfileQuery#school_name` n'était rempli que pour l'enseignant et la direction : un élève l'avait toujours à nil.
- Les quatre fenêtres du profil passent par le cadre `modal` du layout, avec `ui_modal ... open: true`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Profil de l'enseignant au même style | Hors périmètre | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | UDR-0089 |

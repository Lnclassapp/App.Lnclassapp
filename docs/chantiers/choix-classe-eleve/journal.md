# Journal — « Choisis ta classe » aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | Interface seule : routes, paramètres et `ClassPicker` inchangés | Non |
| 2026-10-15 | À coder avant `connexion-inscription-eleve` si possible | L'inscription reprend la même cascade | Non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- La cascade passe par trois routes publiques (`drena_schools`, `school_picker_levels`, `school_picker_classrooms`), en cadres Turbo pilotés par `classroom--class-picker`, avec un repli sans JS par `formaction` GET.
- Le préremplissage vient de `StudentHomeQuery#last_classroom` (DRENA et établissement seulement).

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
| **UDR produits** | UDR-0091 |

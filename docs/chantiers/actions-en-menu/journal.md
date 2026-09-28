# Journal — Actions d'un objet dans un menu ⋮

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Le porteur élargit le périmètre : « Modifier » seul (fiche essentielle, exercice) passe aussi dans le menu ⋮ | Règle unique : toute action de modification/suppression/désactivation d'un objet vit dans son menu, même seule | Non — UDR-0042 |
| 2026-09-28 | `ui_dropdown` gagne `fixed:` (menu en position fixe, `z-50`) | Un menu absolu est rogné par le `overflow-x-auto` des tableaux, et passe sous la barre basse du téléphone (`z-40`) | Non — UDR-0042 §3 |
| 2026-09-28 | Le menu de la page d'un cours utilise `ui_dropdown_item(frame:)` au lieu de liens écrits à la main | Même balisage, et le menu se ferme en ouvrant la modale (il restait ouvert dessous) | Non |
| 2026-09-28 | Clés `edit_label` retirées des lignes et pages converties, clé `actions` ajoutée | Le nom de l'objet est porté par le bouton ⋮ ; l'entrée garde un libellé visible court | Non |

## Ce qui a dérapé

- Le premier test « téléphone » échouait sur la dernière entrée du menu : elle passait sous la barre de navigation basse (`z-40`). Corrigé par le `z-50` des menus fixes ; le test vérifie maintenant chaque entrée par `elementFromPoint`, pas seulement leur présence.

## Ce qu'on a appris sur la codebase

- `overflow-x: auto` sur la carte d'un tableau impose aussi `overflow-y: auto` : tout menu absolu dans une ligne est rogné par le bas de la carte. Le problème existait en germe (aucun menu dans un tableau jusque-là).
- Une `<dialog>` ouverte par `showModal()` rend, à sa fermeture, le focus à l'élément actif au moment de l'ouverture : il faut rendre le focus au bouton ⋮ **avant** `showModal()`, sinon il tombe sur une entrée cachée puis sur `body`.
- Stimulus accepte l'option `:capture` sur une action : `scroll@window->dropdown#place:capture` capte le défilement de n'importe quel conteneur.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Les autres `ui_dropdown` (compte, cours, imports) restent en position absolue | Ils ne sont pas dans un conteneur qui défile ; rien ne les rogne | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-28 |
| **PR** | *(ouverte par le coordinateur)* |
| **ADR produits** | — |
| **UDR produits** | UDR-0042 ; amendements des UDR 0005, 0015, 0021, 0032, 0033, 0034, 0035, 0036 |

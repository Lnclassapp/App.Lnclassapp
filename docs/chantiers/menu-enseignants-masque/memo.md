# Memo — Menu ⋮ des enseignants masqué par la ligne suivante

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `fix/menu-enseignants-masque` |
| **Programme** | — |

---

## Symptôme

Sur l'écran « Enseignants » de la direction (`/school-admin/teachers`), le menu ⋮ d'une ligne autre que la dernière s'ouvre **sous** la cellule d'actions de la ligne suivante. L'entrée « Retirer de l'établissement » est en partie masquée : au bureau, on n'en voit que l'icône et « Retir… » ; au téléphone, « Retirer de l'établis… ». Un clic sur la partie masquée tombe sur la ligne d'en dessous, pas sur l'entrée.

Trouvé le 2026-10-04 par l'agent du chantier `ecrans-direction-lents`, sur les captures du levier 3c (son `journal.md`, « Dette laissée derrière »).

## Reproduction

**Acteur** : un membre de la direction (`school_admin`) d'un établissement actif, donc avec un menu ⋮ par ligne.
**Données** : au moins trois enseignants rattachés à l'établissement, par exemple Yao Brou, Awa Koné et Fanta Touré. La liste est triée par nom : Brou, Koné, Touré.

1. Se connecter comme direction et ouvrir « Enseignants », dans une fenêtre de bureau (1 400 × 1 400).
2. Ouvrir le menu ⋮ de la ligne **du milieu**, « Awa Koné ».
3. Constater : le menu s'ouvre sous le ⋮, par-dessus la ligne « Fanta Touré », et la cellule d'actions de cette ligne le recouvre de « Retir… » jusqu'au bord droit.
4. Viser le centre de « Retirer de l'établissement » : `document.elementFromPoint` y renvoie la cellule d'actions de « Fanta Touré », pas l'entrée. Un clic à cet endroit n'ouvre pas la confirmation de retrait d'Awa Koné.

Au téléphone (390 × 844), le défaut est le même, mais seul le tiers droit de l'entrée est masqué, parce que la cellule collante est plus étroite que le menu : le centre reste cliquable. Le test de reproduction se joue donc au bureau.

## Portée

- **Depuis quand** : depuis le commit `e0dac4ac` du 2026-10-01 (`fix(school): keep the teacher row's ⋮ menu on screen at 390 px`, chantier `gestion-etablissement-direction`). Il a rendu la colonne d'actions collante avec `sticky right-0 bg-white` au lieu de l'utilitaire `sticky-actions` (UDR-0042, amendement du 2026-09-28, introduit par `e272e5a3`). `git log` sur la vue : `28dcc8e6` (la liste, 2026-09-29), `26941a21` (2026-09-29), `2f7c40a2` (le menu « Retirer », 2026-10-01), puis `e0dac4ac`.
- **Où** : sur `Develop` et `Staging`. **Pas en production** : `main` ne contient ni `e0dac4ac` ni le retrait d'un enseignant (`2f7c40a2`).
- **Qui** : la direction d'un établissement actif qui compte au moins deux enseignants, à chaque ouverture du menu d'une ligne autre que la dernière, au bureau comme au téléphone. Les autres rôles ne voient pas cet écran. Les tableaux de l'équipe utilisent déjà `sticky-actions`.
- **Données à réparer** : **aucune**. Le clic égaré tombe sur la cellule d'actions de la ligne suivante : au pire, il ouvre le menu de l'enseignant suivant. Retirer un enseignant passe toujours par une confirmation qui le nomme.
- **Contournement** : cliquer sur la partie visible de l'entrée (l'icône, le début du libellé) ouvre la bonne confirmation.

## Comportement attendu et sa source

UDR-0042, amendement du 2026-09-28 : l'en-tête et chaque cellule de la colonne d'actions portent `sticky-actions`. « Tant que son menu est ouvert (`:has([aria-expanded="true"])`), la cellule passe en `z-index: 50`. » Le menu ouvert est au-dessus de tout le tableau, et chacune de ses entrées reçoit son clic.

## Hors périmètre

- Les autres tableaux : tout autre défaut repéré en passant part dans `journal.md`, comme chantier de suivi. Seule exception : une occurrence identique qui se corrige en une classe (voir `plan.md`).
- La confirmation chargée à la demande (`ecrans-direction-lents`, levier 3b) : ce chantier ne touche que les classes de la colonne d'actions.
- Le placement du menu (`dropdown_controller.js#place`) : il est correct. C'est l'empilement qui ne l'est pas.

## Questions encore ouvertes

- Aucune.

Lot et portes de sortie : [`plan.md`](plan.md). Rapport de root cause : [`journal.md`](journal.md).

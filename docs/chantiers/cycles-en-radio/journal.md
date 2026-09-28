# Journal — Cycles en boutons radio

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | « 1er cycle par défaut » = `first` (« Premier cycle »), appliqué à la création d'un niveau seulement | L'établissement n'a pas d'écran de création (UDR-0036) et a toujours un cycle enregistré | Non — memo, UDR-0032 |
| 2026-09-28 | Le défaut est posé par `Teams::LevelsController#new` (`CYCLES.first`) | Même place que la position proposée ; la vue ne décide rien | Non |
| 2026-09-28 | Nouveau composant `ui_radio_group` plutôt que des radios écrites à la main | Trois écrans en ont déjà chacun leur version ; un quatrième et un cinquième auraient suivi | Non — UDR-0005 |

## Ce qui a dérapé

## Ce qu'on a appris sur la codebase

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Genre (inscriptions), Catégorie de matière, Rôle d'invitation écrivent encore leurs radios à la main | Hors périmètre de la demande ; chacun a un rendu propre (badge, description) à vérifier | — |

## Clôture

# Memo — Interface épurée

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — grill en cours (repris le 2026-10-02, après une pause du porteur le 2026-09-30) |
| **Ouvert le** | 2026-09-30 |
| **Branche** | `feature/interface-epuree` |
| **Programme** | — *(hors plan de `refonte-application` ; précède le chantier `app-android`, ADR-0070)* |

---

## Le problème

Le porteur juge l'application trop chargée : pas assez épurée, pas assez simple à utiliser pour tout le monde. Le constat n'est pas encore mesuré ni localisé écran par écran.

Ce que l'on sait : l'interface compte environ 230 vues, construites écran par écran depuis la V1, chacune avec sa propre décision d'interface (plus de 50 UDR). Un design system fondateur existe (UDR-0005), ainsi qu'un shell par rôle (UDR-0006) et une passe de finitions (UDR-0054). Aucune décision ne fixe de règle de sobriété commune : combien d'actions, de textes ou d'éléments un écran peut montrer.

## Pour qui

- **Élève**, souvent sur un Android d'entrée de gamme. C'est le seul public de ce chantier (grill, Q1).

L'enseignant, la direction et l'équipe sont traités dans un chantier suivant, qui appliquera la règle de sobriété fixée ici.

## Pourquoi maintenant

Les apps Android (ADR-0070, en attente) afficheront les pages du site telles quelles. Ce que ce chantier simplifie, les apps en héritent sans travail de plus ; ce qu'il laisse chargé, elles l'emportent sur le Play Store.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- Toute nouvelle fonctionnalité métier.
- Les écrans de l'enseignant, de la direction et de l'équipe : chantier suivant (grill, Q1).
- Les apps Android (chantier `app-android`) et la PWA (`installation-pwa`).
- Les finitions déjà livrées par `finitions-ux` (retour, auto-focus, infobulles, « Copier », recherche, titres).

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1 — Quels publics ce chantier couvre-t-il ? Tout épurer d'un coup, 4 publics et environ 230 écrans, est le moyen le plus sûr de ne rien finir. | **L'élève seulement.** La maquette V2 de l'accueil élève, validée par le porteur le 2026-10-02, sert d'écran de référence. | Le périmètre se réduit aux écrans de l'élève. Enseignant, direction et équipe passent hors périmètre, dans un chantier suivant qui reprendra la règle. |
| Q2 — Comment sait-on qu'un écran élève est « assez épuré » ? Sans règle mesurable, chaque écran est épuré à l'œil et le chantier ne finit jamais. | **Une règle chiffrée.** Par écran : une seule action principale ; au plus 5 blocs visibles avant de faire défiler ; au plus 3 lignes par liste, puis « Voir plus » ; aucun texte d'aide affiché en permanence ; une seule couleur d'accent, hors signal d'urgence. | La règle devient une décision d'interface commune aux écrans élève, et chaque point devient un critère vérifiable par un test. Un écran est « fini » quand il respecte les cinq points. |
| Q3 — Épurer, c'est retirer. Quand une information ou une action disparaît d'un écran, où va-t-elle ? | **Éviter les répétitions d'information et la surcharge.** Le porteur vise d'abord ce qui est dit deux fois et ce qui encombre, pas un déplacement systématique vers un autre écran. | Sixième point de la règle : une information n'apparaît qu'une fois par écran (pas de matière répétée dans l'icône, le libellé et un badge, pas de statut redit en texte et en couleur sans raison d'accessibilité). Le sort d'une information unique mais secondaire reste à trancher (Q4). |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …

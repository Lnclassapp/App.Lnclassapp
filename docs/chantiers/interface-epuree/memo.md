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

- **Élève**, souvent sur un Android d'entrée de gamme.
- **Enseignant**.
- **Direction d'établissement**.
- **Équipe**.

*Première version : l'ordre de priorité entre ces publics se tranche au grill.*

## Pourquoi maintenant

Les apps Android (ADR-0070, en attente) afficheront les pages du site telles quelles. Ce que ce chantier simplifie, les apps en héritent sans travail de plus ; ce qu'il laisse chargé, elles l'emportent sur le Play Store.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- Toute nouvelle fonctionnalité métier.
- Les apps Android (chantier `app-android`) et la PWA (`installation-pwa`).
- Les finitions déjà livrées par `finitions-ux` (retour, auto-focus, infobulles, « Copier », recherche, titres).

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …

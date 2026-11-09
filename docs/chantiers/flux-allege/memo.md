# Memo — Un flux allégé : petites branches, retouches, messages, mesure mensuelle

| | |
|---|---|
| **Type de cycle** | refactoring *(processus, aucun comportement produit)* |
| **Statut** | livré |
| **Ouvert le** | 2026-11-06 |
| **Branche** | `chore/flux-allege` |
| **Programme** | — |

---

## Le problème

Rapport sur la méthode de travail (2026-11-05), propositions 5, 8, 9 et 10. Mesure d'octobre sur `Develop` ([`docs/mesures/2026-10.md`](../../mesures/2026-10.md)) :

| Mesure | Valeur |
|---|---|
| Fusions de rattrapage (`Develop` fusionné dans une branche) | 119 |
| Branches de plus d'un jour | 20 sur 154 PR |
| Commits par PR (moyenne) | 7,0 (cible 3) |
| Chantiers ouverts depuis le 9/10 | 111 memos, 42 ADR, 75 UDR : 4 par jour, dont des libellés et des espacements |
| `/goal` inatteignable le 5/11 | ≈ 35 blocages du hook de fin en 15 min |

Les règles de sobriété n'avaient pas de mesure rejouée : le memo `sobriete-tokens` la promettait à 30 jours.

## Ce qui change

- **Point 5** : une branche vit moins d'un jour ; une PR par chantier et par jour (`conventions.md` §3, `plan-lots` étape 5, `CLAUDE.md`).
- **Point 8** : cycle « retouche » ([`retouche.md`](../../workflows/retouche.md), skill `/retouche`) ; dossier [`retouches`](../retouches/memo.md) pour celles sans chantier parent ; section `## Retouches` dans le modèle de journal.
- **Point 9** : §4 « Écrire à une session » du [contrat de session](../../workflows/contrat-de-session.md).
- **Point 10** : `script/mesure/sobriete`, [`mesure.md`](../../workflows/mesure.md), mesure de référence d'octobre, tâche programmée le 1er du mois.

## Hors périmètre

- Point 6 (CI rouge seulement pour le produit) : chantier `ci-durees-enregistrees`, session séparée.
- Réglages GitHub du dépôt (mise à jour des branches, fusion automatique) : à faire par le porteur dans les paramètres du dépôt.

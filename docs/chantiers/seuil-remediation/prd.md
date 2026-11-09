# PRD — Une seule échelle : la remédiation suit la médaille

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier.

## 1. Contexte

Décision du porteur (2026-11-09) : Bronze et Argent restent en remédiation, la fiche n'est levée qu'à l'Or. Aujourd'hui elle l'est à 15/20, entre Argent et Or. Le seuil de levée devient celui de l'Or. Voir le [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Lever sa fiche en obtenant l'Or ou le Diamant | Lever sa fiche avec Bronze ou Argent |
| Teacher, SchoolStaff, Team, Parent | Rien de nouveau | — |

Aucune règle d'autorisation touchée.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève a une fiche à revoir ; il fait l'exercice proposé et obtient l'Argent : la fiche reste à revoir, sans échec de plus.
2. Il recommence et obtient l'Or : la fiche est levée.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Sous la réussite (< 10/20), fiche en attente | Un échec de plus (inchangé) |
| Sous la réussite, aucune fiche | Une fiche s'ouvre (inchangé) |
| Fiche déjà levée à 75-77 % avant le changement | Reste levée |
| Aucune fiche en attente, médaille Or | Rien |

## 4. Critères d'acceptation

```gherkin
Étant donné un élève avec une fiche en attente
Quand sa session de remédiation se termine à 77 % (15/20, Argent)
Alors la fiche reste en attente, sans échec de plus

Étant donné un élève avec une fiche en attente
Quand sa session de remédiation se termine à 78 % (16/20, Or)
Alors la fiche est levée (remédiée)

Étant donné un élève avec une fiche en attente
Quand sa session standard se termine à l'Or ou au Diamant
Alors la fiche est levée (auto-corrigée)

Étant donné n'importe quel score de 0 à 100
Alors une fiche en attente ne se lève que si la médaille est Or ou Diamant

Étant donné le code de l'application
Alors le seuil de remédiation n'existe plus : la levée lit le seuil de l'Or sur la note affichée
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Décision de clôture lit le seuil de l'Or ; seuil propre de remédiation supprimé |
| Infrastructure | aucune (pas de migration) |
| Delivery | aucune |
| UI | variable d'aide inutile retirée ; aucun rendu modifié |

## 6. Décisions rattachées

- ADR-0043 — amendement du 2026-11-09 (la lacune se lève à l'Or). Pas de nouvel ADR : ni port, ni table, ni contrat.
- UDR : aucune. Aucune vue ne change à l'écran (les textes disaient déjà « vise l'Or ») ; l'UDR médailles remplaçant notes et moyennes est amendée (point 6).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Sessions qui lèvent, jeu standard (198 notées) | 65 | ≤ 65 | 65 (aucune entre 73 et 77 %) |

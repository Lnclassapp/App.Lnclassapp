# PRD — La fiche s'ouvre sous l'Or

## 1. Contexte

Décision du porteur (2026-11-09) : Bronze et Argent sont en remédiation. Voir le [memo](memo.md).

## 2. Acteurs et permissions

Student : sa fiche s'ouvre ou se maintient sous l'Or. Teacher, SchoolStaff, Team, Parent : rien de nouveau, aucune règle d'autorisation touchée.

## 3. Parcours utilisateur

Nominal : l'élève termine un exercice à l'Argent ; sa fiche passe « à revoir » et l'exercice proposé s'affiche. Il refait l'exercice et obtient l'Or : la fiche est levée.

| Situation | Comportement attendu |
|---|---|
| Argent avec une fiche déjà en attente | Un échec de plus, une seule fiche |
| Or ou Diamant, sans fiche | Rien |
| Copie sans réponse | Rien |
| Exercice de toute la leçon | Rien |

## 4. Critères d'acceptation

```gherkin
Étant donné un élève sans fiche à revoir sur une notion
Quand il termine un exercice à 77 % (15/20, Argent)
Alors la fiche s'ouvre et le résultat dit « Cette notion passe à revoir. »

Étant donné un élève avec une fiche en attente
Quand sa remédiation se termine à l'Argent
Alors la fiche reste en attente avec un échec de plus et le résultat dit « Encore à revoir. »

Étant donné un élève avec une fiche en attente
Quand il termine à 78 % (16/20, Or)
Alors la fiche est levée

Étant donné n'importe quel score de 0 à 100
Alors la fiche s'ouvre exactement quand la médaille est Bronze ou Argent

Étant donné une copie sans aucune réponse
Quand elle est rendue
Alors aucune fiche n'est ouverte ni comptée
```

## 5. Modélisation préliminaire

Domaine : la décision de clôture lit le seuil de l'Or et si la copie est traitée. Infrastructure, delivery : aucune. UI : texte de l'aide en médailles.

## 6. Décisions rattachées

ADR-0043, amendement du 2026-11-09 (2). Pas de nouvel ADR (ni port, ni table, ni contrat). UDR médailles amendée (point 6) ; aucune vue nouvelle.

## 7. Mesures

| Métrique | Avant | Après |
|---|---|---|
| Fiches à revoir, jeu standard | 136 | 264 |

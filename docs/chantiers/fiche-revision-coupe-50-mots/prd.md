# PRD — La fiche de révision coupée à 50 mots

## 1. Objectif

La fiche de révision d'une leçon montre environ 50 mots (fin du bloc qui atteint 50) avant « Voir plus », au lieu de 150.

## 2. Acteurs

Élève, enseignant, équipe : tous lisent la même fiche.

## 3. Périmètre

Le seuil de la coupe. Rien d'autre : voir le memo, « Hors périmètre ».

## 4. Critères d'acceptation

```gherkin
Scénario: CA-1 — la coupe tombe à la fin du bloc qui atteint 50 mots
  Étant donné une leçon dont les blocs comptent 30, 25, 10 et 10 mots
  Quand la fiche est calculée
  Alors les deux premiers blocs sont visibles et les deux suivants sont derrière « Voir plus »

Scénario: CA-2 — une fiche de 50 mots ou moins est entière
  Étant donné une leçon dont le texte compte 50 mots en tout
  Quand l'élève ouvre la leçon
  Alors toute la fiche est visible et il n'y a pas de bouton « Voir plus »

Scénario: CA-3 — sur la page, « Voir plus » déplie la suite
  Étant donné une leçon dont la première notion a un « À retenir » de 60 mots, suivie d'une seconde notion
  Quand l'élève ouvre la leçon
  Alors seul « À retenir » de la première notion est visible
  Et « Voir plus » déplie la méthode, l'exemple, le piège et la seconde notion, sans requête
```

Tests : CA-1 et CA-2 dans `test/domain/entities/catalog/revision_preview_test.rb` ; CA-3 dans `test/integration/catalog/revision_sheet_test.rb` (rendu serveur) et `test/system/catalog/revision_sheet_test.rb` (navigateur, 390 px compris).

## 5. Hors périmètre

Voir le memo.

## 6. Décisions

- Pas d'ADR : ni port, ni table, ni contrat ne bougent ; seule la valeur d'une constante du domaine change.
- UDR-0148, qui amende UDR-0139 §3.2 et UDR-0141.

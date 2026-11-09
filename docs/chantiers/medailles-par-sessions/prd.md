# PRD — Médailles lues par sessions, remédiation à l'Argent

## Critères d'acceptation

```gherkin
Scénario: médaille montée hors du devoir
  Étant donné un élève dont la copie du devoir vaut 72 % (Argent) et qui a ensuite fait le même exercice seul à 100 %
  Quand l'enseignant ouvre la liste, la fiche ou la répartition du devoir
  Alors la classe lit Argent, jamais « Pas encore »

Scénario: copie vide
  Étant donné une copie rendue sans aucune réponse
  Alors aucune médaille n'apparaît dans la classe

Scénario: remédiation à l'Argent
  Étant donné une fiche à revoir en attente
  Quand l'élève rend une copie de remédiation à 68 % (14/20)
  Alors la fiche est levée ; à 67 % elle reste en attente
```

## Décisions techniques

Pas de nouveau port, table ni migration : ADR non requis (lecture en requêtes existantes ; seuil nommé dans le domaine). Aucune vue modifiée : pas d'UDR.

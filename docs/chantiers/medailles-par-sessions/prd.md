# PRD — Médailles de classe lues par sessions

## Critères d'acceptation

```gherkin
Scénario: médaille montée hors du devoir
  Étant donné un élève dont la copie du devoir vaut 72 % (Argent) et qui a ensuite fait le même exercice seul à 100 %
  Quand l'enseignant ouvre la liste, la fiche ou la répartition du devoir
  Alors la classe lit Argent, jamais « Pas encore »

Scénario: copie vide
  Étant donné une copie rendue sans aucune réponse
  Alors aucune médaille n'apparaît dans la classe
```

## Décisions techniques

Pas de nouveau port, table ni migration : ADR non requis (lecture en requêtes existantes). Aucune vue modifiée : pas d'UDR.

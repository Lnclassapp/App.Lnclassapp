# PRD — Médailles : écrans de la direction

```gherkin
Scénario: page d'une classe
  Quand la direction ouvre une classe
  Alors elle voit « devoirs donnés », « N sur M devoirs rendus » et la répartition « 2 Bronze · 1 Argent · 2 Or »
  Et chaque élève porte ses médailles (« Pas encore » sans exercice traité), jamais un score ni une moyenne

Scénario: carte de classe d'un niveau
  Alors la carte dit « N devoirs rendus sur M » et la répartition de médailles de la classe, sans « Moyenne » ni « % »

Scénario: bulles « Niveaux » et alertes
  Alors la pastille de participation est dite en mots (« régulière », « à encourager », « à relancer »), sans pourcentage
  Et l'alerte dit « N classes avec peu d'activité »

Scénario: anciens élèves
  Alors la colonne « Médailles » remplace « Score moyen » ; seules comptent les médailles gagnées dans les classes de l'établissement

Scénario: une médaille gagnée dans une autre classe
  Alors elle n'est lue que dans la classe où la session a été faite (ADR-0097 §4.5) ; un élève parti n'entre pas dans la répartition
```

# PRD — Médailles : écrans de l'élève

## Critères d'acceptation

```gherkin
Scénario: résultat d'une session, côté élève
  Quand l'élève termine un exercice à 30 %
  Alors il voit la médaille Bronze et « Prochaine médaille : Argent »
  Et aucune note sur 20, aucun pourcentage, aucune maîtrise, aucun point

Scénario: le sans-faute
  Quand l'élève obtient 100 %
  Alors il voit Diamant et aucune « prochaine médaille »

Scénario: progrès
  Quand l'élève passe de Bronze à Argent à sa deuxième session
  Alors la phrase dit « Tu passes de Bronze à Argent. Bravo ! »

Scénario: accueil, Mon historique, Ma classe, page d'un exercice
  Alors chaque exercice traité porte la médaille de sa meilleure copie (« Ta médaille : Or » sur la page de l'exercice), jamais une note

Scénario: copie en cours
  Alors ni barème ni points par question ne s'affichent, le compteur « répondues » reste

Scénario: l'enseignant ouvre le résultat d'un élève
  Alors il garde les termes d'avant (changé par medailles-enseignant)
```

## Architecture

Aucun port, aucune table : un use case n'est pas ajouté. `Grading.badge_for` donne au moins Bronze. Les vues lisent la médaille par `medal_tag`. ADR : non. UDR : `XXXX-medailles-ecrans-eleve`.

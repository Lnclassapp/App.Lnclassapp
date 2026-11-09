# Plan d'exécution — Une seule échelle : la remédiation suit la médaille

## Graphe

```
Lot A — seuil de levée à l'Or (un seul lot, un seul commit)
```

## Lot A — Seuil de levée = Or

- **Couche**       : domaine + vues d'aide + docs
- **Fichiers**     : `app/domain/entities/assessment/grading.rb`, `gap_decision.rb`, `app/views/communication/help/show.html.erb`, locales `help` et `session_results`, tests `gap_decision_test`, `grading_test`, `thresholds_on_grade_test`, ADR-0043, UDR médailles, glossaire, journaux
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/gap_decision_test.rb`
- **Done quand**   : une fiche en attente ne se lève qu'à l'Or ; le seuil de remédiation n'existe plus

## Décisions ouvertes

- [ ] Ouvrir aussi la fiche à l'Argent ? — options : non (ouverture à 10/20), oui ; recommandé : non (voir journal)

## Vérification de collision

Un seul lot : aucune collision.

## Portes de sortie

- [ ] Lot A fait
- [ ] Rôle distinct : tests lancés
- [ ] Pureté du domaine, rubocop, tests : au vert
- [ ] ADR-0043 amendée, UDR médailles amendée
- [ ] `journal.md` complété

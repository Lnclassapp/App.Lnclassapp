# Plan d'exécution — La fiche s'ouvre sous l'Or

## Graphe

Lot A — décision de clôture, aide, docs (un seul lot, un seul commit).

## Lot A

- **Couche** : domaine + aide + docs
- **Fichiers** : `gap_decision.rb`, `close_exercise_session.rb`, locale `help`, tests `gap_decision_test`, `close_exercise_session_test`, `session_results_controller_test`, ADR-0043, UDR médailles, glossaire
- **Dépend de** : —
- **Test associé** : `test/domain/entities/assessment/gap_decision_test.rb`
- **Done quand** : tout score sous l'Or ouvre ou maintient la fiche ; l'Or et le Diamant la lèvent ; une copie vide ne fait rien

## Décisions ouvertes

Aucune (décision du porteur écrite).

## Portes de sortie

- [x] Lot A fait · [ ] bin/ci-quiet sur la tête finale · [ ] revues · [ ] captures

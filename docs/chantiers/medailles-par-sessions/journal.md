# Journal — Médailles de classe lues par sessions

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-09 | Médaille de classe = meilleure copie traitée de la classe, ou médaille enregistrée si plus haute | Le palier monte avec la note ; couvre les médailles déjà écrites | Non |

## À trancher

- [ ] 2026-11-09 · medailles-par-sessions · Écran « liste » de classe (`teacher_home_query#medal_holders`) : le scénario médaille montée hors du devoir est testé au niveau des requêtes de médailles, pas de bout en bout — appliqué : tests de requête ; recommandé : suffisant
- [ ] 2026-11-09 · medailles-par-sessions · Copies traitées avant le 2026-11-08 sous 50 % : sans ligne `exercise_badges` (la règle « Bronze dès le traité » est postérieure, aucun rattrapage) ; la classe lit désormais Bronze, l'élève et le tableau d'équipe lisent « Pas encore » — appliqué : écart accepté ; autres : tâche de rattrapage créant le Bronze manquant ; recommandé : le rattrapage, dans un chantier code

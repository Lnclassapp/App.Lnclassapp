# Journal — Médailles : écrans de la direction

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-09 | Répartition de classe = toutes les médailles gagnées par exercice (une par élève et exercice), additionnées par palier | « Par exercice », jamais de moyenne ni de classement | Non (UDR direction) |
| 2026-11-09 | Plus de seuil « 5 élèves » : une répartition n'est pas une moyenne | Le seuil protégeait une moyenne | Non |
| 2026-11-09 | Le taux de rendu se dit en entiers (« 5 devoirs rendus sur 6 ») ; la pastille de participation reste, dite en mots | Les seuils internes 70/40 % restent, jamais affichés | Non |

## À trancher

- [ ] 2026-11-09 · medailles-direction · Bulles « Niveaux » : l'audit propose la médaille dominante du niveau ; appliqué : pastille de participation (mots) conservée, pas de médaille sur la bulle (la répartition est sur la carte de chaque classe) ; autres : médaille dominante du niveau (une requête de plus sur l'accueil mis en cache) ; recommandé : décider après les captures
- [x] 2026-11-09 · medailles-direction · Fiche élève et liste de classe ouvertes par la direction : mêmes vues que l'enseignant (`classroom/classroom_students`, `classroom/classrooms/_roster`) — appliqué : non touchées ici (chantier `medailles-enseignant` en parallèle) ; autres : les convertir ici ; recommandé : attendre la fusion de `medailles-enseignant` — résolu : convertis par `medailles-enseignant` (PR #529, fusionnée)
- [ ] 2026-11-09 · medailles-direction · « Fiches à revoir » (partiel partagé avec l'enseignant) : seuil de remédiation inchangé à 75 % ; le sous-titre dit « viser l'Or » (cohérent avec `medailles-eleve`) — appliqué : texte seul ; autres : aligner le seuil sur l'Argent (code) ; recommandé : l'Argent, dans un chantier code (déjà posé par `medailles-eleve`)
- [ ] 2026-11-09 · medailles-direction · Accueil : l'alerte « classes avec peu d'activité » repose encore sur le seuil interne de 40 % de devoirs rendus — appliqué : seuil inchangé, non affiché ; autres : un seuil en nombre de devoirs ; recommandé : inchangé
- [ ] 2026-11-09 · medailles-direction · Une médaille améliorée hors de la classe (fait seul, autre classe) : `exercise_badges` n'a qu'une ligne par (élève, exercice), sa session est écrasée, donc la médaille quitte les chiffres de la classe d'origine (ADR-0097 §4.5, déjà la règle des vues enseignant) — appliqué : règle de l'ADR gardée ; autres : calculer le palier par (élève, exercice) depuis les sessions terminées des devoirs de la classe ; recommandé : le calcul par sessions, dans un chantier code

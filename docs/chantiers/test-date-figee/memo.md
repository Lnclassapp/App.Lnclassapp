# Memo — Un test de suivi d'exercice rouge depuis le 30 octobre 2026

| | |
|---|---|
| **Type de cycle** | bugfix (tests) |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `fix/test-date-figee` |
| **Programme** | — |

---

## Symptôme

Suite complète sur `Develop` (04f4252b) : 6670 tests, **1 erreur**. `assignment_follow_ups_controller_test.rb:103` (« la ligne méta dit « Maths » ») lève `PG::CheckViolation` sur `classroom_assignments_due_on_within_a_week`. La suite complète de la prochaine PR vers `Staging` serait rouge.

## Cause

Le test crée une assignation **aujourd'hui** avec `due_on: Date.new(2026, 10, 30)`. La contrainte veut une date limite de 1 à 7 jours après l'assignation (heure d'Abidjan). Vert jusqu'au 29 octobre, rouge à partir du 30, pour toujours. Le reste du fichier fige déjà l'heure (`travel_to` dans `setup`) ; ce test ne le faisait pas. Le code est conforme.

## Correctif retenu

Créer l'assignation sous `travel_to(Time.zone.local(2026, 10, 26, 9))`, comme `setup`. L'assertion (« à rendre ven. 30 oct. ») ne change pas. Aucun code applicatif touché.

## Portes de sortie

- [x] Le test rouge avant, vert après ; le fichier entier vert
- [ ] `bin/ci-quiet` vert, ligne de preuve dans la PR

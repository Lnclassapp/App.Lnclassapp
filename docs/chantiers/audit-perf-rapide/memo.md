# Memo — Audit perf rapide

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré (PR vers Develop) |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `fix/audit-perf-rapide` |

Source : [`docs/audits/2026-11-08-optimisations-ux-wording.md`](../../audits/2026-11-08-optimisations-ux-wording.md) (O-X05, O-X01, O-X04, O-C01, O-X14, O-C02). Aucun changement visible pour l'utilisateur.

## Mesure avant / après

| Levier | Contexte / volume | Avant | Après | Comment mesurée |
|---|---|---|---|---|
| O-X05 index `classroom_students(student_id)` | 1 080 000 adhésions, 180 000 classes, PostgreSQL 16 local, `WHERE student_id = …` | parcours de l'index composite entier : coût 27 537, **15,4 ms** | index dédié : coût 8, **0,04 ms** | `bench_student_id_index.rb` (EXPLAIN ANALYZE, 3 passes, transaction annulée) |
| O-X01 pool de connexions | `RAILS_MAX_THREADS=3` (valeur de Railway inconnue du dépôt) | pool 3 pour un worker de jobs qui en veut 5 | pool 5 (3 : 5 ; 5 : 7 ; non posée : 5) | `bin/rails runner 'puts ActiveRecord::Base.connection_pool.db_config.max_connections'` |
| O-C01 liste des cours, vue d'une matière | élève, `/cours?material=<slug>` | 2 lectures de la page du catalogue | **1** | test `the subject view reads the catalog page once…` (échoue sans le correctif : 2 ≠ 1) |
| O-X14 `bg.png` | image Docker | 2 498 217 octets livrés, 0 référence | supprimée | `git grep` de `bg.png`, `bg_lnclass`, `assets/bg`, noms dynamiques : aucun usage hors audit |

## Pool de connexions (justification)

- Web : Puma 3 threads (`RAILS_MAX_THREADS`, défaut 3) → 3 connexions.
- Solid Queue : plugin Puma en mode `fork` (défaut de la gem) → le superviseur, ses workers et son dispatcher sont des **process séparés**, chacun avec son pool. Le worker a 3 threads (`config/queue.yml`) + interrogation + battement de cœur = 5.
- Pool = `max(RAILS_MAX_THREADS, 3) + 2`. Les pools se remplissent à la demande : une réplique (`.railway/railway.ts`) ouvre ≈ 3 + 5 + 2 + 1 = 11 connexions, loin des 100 par défaut de PostgreSQL. Aucune valeur Railway touchée.

## Reporté

| Constat | Pourquoi |
|---|---|
| **O-X04** cache du Pilotage 7/30 jours | Décision du porteur (ADR-0062, amendement du 2026-09-29, second) : 7 et 30 jours restent en direct, la fraîcheur de l'activité récente primant (UDR-0018). Les cacher ajoute un retard visible : à trancher par le porteur (TTL 1–2 min ?). La clé inclut déjà le début de période, stable dans la journée. |
| **O-C02** pagination des leçons sur ordinateur | Demande un choix de conception (réutiliser `courses_page_N` pour `lessons_list` ou monter la taille de page). |
| **O-C01**, part restante | Sans `?material=`, le téléphone liste toutes les matières et l'ordinateur une seule : ce sont deux requêtes différentes, à garder. |
| **O-X02** | Hors mission : une autre session. |

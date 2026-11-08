# Journal — Audit perf rapide

- 2026-11-08 — `EXPLAIN` d'O-X05 : sans `LIMIT`, PostgreSQL parcourt tout l'index composite `(classroom_id, student_id)` (classroom_id en tête, inutilisable pour `student_id` seul) ; avec `LIMIT 1` l'écart est du même ordre.
- Le plugin Puma de Solid Queue forke par défaut : l'audit supposait un pool partagé entre web et jobs, ce qui est faux ; le vrai défaut est un pool trop petit **dans le worker** quand `RAILS_MAX_THREADS=3`.
- `db/schema.rb` : regénéré par PostgreSQL 16 local, il réécrit des contraintes `CHECK` sans rapport ; seules la version et la ligne de l'index sont reportées à la main.
- Levier abandonné : O-X04 (voir « Reporté » du memo).

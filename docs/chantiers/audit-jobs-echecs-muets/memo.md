# Memo — Jobs : échecs muets (audit 2026-11-08)

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `fix/audit-jobs-echecs-muets` |
| **Programme** | — |

## Le problème

Constats B-006, B-007, B-030, B-042, B-043, B-044 de `docs/audits/2026-11-08-bugs-code-mort.md`.

- **B-006** : verrou des imports (`ImportJob`, `GenerateMissingClassroomsJob`) sans `duration:` → expire après 3 min (Solid Queue), deux imports en parallèle. Cause : `limits_concurrency` sans durée. Corrigé : `duration: STALE_AFTER`, comme les jobs de régénération.
- **B-007** : confirmé réel. `LeaveSchool` / `DetachTeacher` n'archivent pas les annonces programmées (seulement assignations et déclarations). Cause : `PublishScheduledMessages` ne relit pas les droits. Corrigé : à la parution, l'acteur est relu (`actor_for`) et `PublishPolicy` rejouée (classes déclarées, établissement, drapeau enseignants) ; sinon l'annonce est archivée, non publiée, non journalisée.
- **B-030** : une exception autre que `Frozen` interrompait la boucle. Corrigé : `rescue` par annonce + `Rails.error.report` (id seul) ; le job journalise le total.
- **B-042** : `:unavailable` ajouté à `FORM_STATUSES` (503) + message `errors.codes.unavailable`.
- **B-043** : les 4 jobs de rapport journalisent `report_id` et `code` d'un `Result` en échec (`ApplicationJob#log_failure`).
- **B-044** : `PurgeArchivedStaff::Purged#failed` porte `Failure(user_id, error)` (classe de l'exception, jamais le message) ; le job la journalise.

## Hors périmètre

- Archivage des programmées au départ de l'enseignant (le contrôle à la parution suffit et couvre aussi la désactivation, l'anonymisation et le drapeau).
- Classe archivée : non revérifiée à la parution (la déclaration d'enseignement est retirée au départ).

## Cas limites

Direction archivée ou école changée : `PublishPolicy` refuse (`school_id` ≠ acteur) → archivée. Équipe : portée nationale/école comme à la création.

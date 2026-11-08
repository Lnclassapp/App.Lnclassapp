# audit-bugs-p2 — B-003, B-004, B-005

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | exécution |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `fix/audit-bugs-p2` |
| **Source** | `docs/audits/2026-11-08-bugs-code-mort.md` |

## Symptômes et causes

- **B-003** : supprimer un établissement ne référencé que par du personnel de direction, des départs d'enseignants ou des annonces donne un 500. Cause : `referenced?` (`school_repository.rb`) oublie ces trois tables, dont la clé étrangère est en `restrict`. Correctif : les ajouter (réponse `conflict` / `referenced`, toast existant).
- **B-004** : après un retrait dans une classe de plus de 30 élèves, le compteur affiche « 30 élèves » au lieu de « 30 sur N ». Cause : le stream lisait `students.size` (plafonné à `PER_PAGE`) et `read_roster` ne relayait ni `page` ni `badge`. Correctif : `students_total`, `page` et `badge` relayés.
- **B-005** : « oeuf » / « œuf » ne trouvent pas « cellule-œuf ». Cause : `translate()` SQL ne connaît pas les ligatures que `transliterate` Ruby déplie. Correctif : `replace` œ→oe, æ→ae avant `translate`.

## Tests (rouges avant, verts après)

`school_repository_test.rb` (B-003), `classroom_students_controller_test.rb` (B-004), `text_search_test.rb` (B-005, requête SQL réelle).

## Hors périmètre

B-006 et les autres constats de l'audit.

# Journal — Audit code mort

## Reporté (clés I18n M-004 non supprimées, avec la raison)

| Clés | Raison |
|---|---|
| `*_student` (`intro_`, `current_pin_hint_`, `changed_`, `preview_`, `unreadable_`, `removed_`, `pin_hint_`, `updated_`, `hint_`) | Lues par `tone_t` (`"#{key}_student"`, `ToneHelper`, `Tone`) pour l'élève |
| `catalog.courses.index.student_progression`, `identity.profiles.information.edit_materials` | Citées par des tests (`courses_controller_test`, `profile_test`) : supprimer affaiblirait ces assertions |
| `components.rich_text_editor.lang.*` | Le hash entier est passé au JS (`.to_json`), qui l'applique à Trix |
| `install_banner.ios_share|ios_add.{student,teacher}_html` | `t(".#{key}.#{role}_html")` |
| `articles.show.status.{draft,archived}_hint` | `t(".status.#{status}_hint")` |
| `classroom_plans.totals.{public,private}_{first,both}` | `t(".#{school_type}_#{cycle}")` |
| `articles.article_row.signed_*` | `t(".signed_#{signature}")` |
| `schools.filters.all_*` | `t(".all_#{name}")` |
| `imports.schema_keywords.maxLength` | `schema_keywords.#{keyword}` |
| `…max_students.not_an_integer` | Code standard de `numericality: { only_integer: true }` |
| `teacher_homes.show.{previous,next}_classrooms` | `t(".#{direction}_classrooms")` |
| `imports.status.details.exercises_archived|exercises_ignored_v1` | Plus émises par le code, mais des rapports d'import déjà enregistrés peuvent les porter : à vérifier en base |
| `shared.subjects.short.*` | Clé par slug de matière |

M-005 : non traité (journaux d'accès requis).

## Note
`images-dans-les-cours/menace.md` cite `ManageContentImagesPolicy` et `UploadQuestionImage` : supprimés ici ; la menace reste l'instantané de la livraison. Le Lot C du plan prévoyait un contrôleur d'envoi d'image de question qui n'existe pas : à confirmer avec le porteur si l'envoi est voulu.

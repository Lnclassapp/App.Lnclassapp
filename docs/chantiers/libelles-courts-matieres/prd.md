# PRD — Les libellés courts des matières

**Décision d'interface** : [UDR-0146](../../decisions/udr/0146-libelles-courts-des-matieres.md).

**Acteur** : l'élève, dans Cours : pastilles sur ordinateur (dès `lg`), titres de groupe sur téléphone. Aucune permission nouvelle.

**Parcours** : l'élève ouvre Cours ; les pastilles « Matières » montrent « Maths », « PC », « HG », « Philo » ; il en choisit une, comme avant.

## Critères d'acceptation

- **CA-L1** — Une pastille dont la matière a une entrée dans `shared.subjects.short` montre ce libellé seul (muet aux lecteurs d'écran) ; le nom entier est lu (sr-only) et porté en `title`. Sans entrée, la pastille montre le nom entier, sans `title`. Sur téléphone, le titre de groupe montre ce libellé ; son `aria-label` garde le nom entier, qui est aussi en `title`. Tests : `test/controllers/catalog/courses_controller_test.rb` (deux CA-L1), `test/system/catalog/student_courses_test.rb`.
- **CA-L2** — Rien d'autre ne change : le h1 et le titre de page de la matière, les autres écrans gardent le nom entier ; aucune donnée n'est modifiée.

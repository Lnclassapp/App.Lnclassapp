# Plan — Médailles : écrans de la direction

## Lot A — Lecture et écrans (un commit)

- `Queries::Assessment::Medals.by_classroom` et `.by_student_in_school` : répartition par palier, une requête chacune.
- `StudentWorkQuery` / `DepartedStudentsQuery` : `medals` remplace `average_percent` ; `average_percent` et son seuil de 5 élèves disparaissent. L'accueil (`DirectionHomeQuery`) ne lit pas les médailles.
- Vues : `classrooms/show`, `levels/_classroom_card`, `classrooms/_levels`, `departed_students/index`, légende de participation, fiches à revoir. Helper `SchoolAdmin::MedalsHelper#medal_counts`.
- I18n : participation en mots (pastille inchangée), alerte « peu d'activité », infobulles en mots.
- Tests : requêtes (présence, autre classe, élève parti), vues sans %, budgets de requêtes.

## Lot B — UDR et journal (même commit)

UDR `XXXX-medailles-ecrans-direction`, journal avec `## À trancher`.

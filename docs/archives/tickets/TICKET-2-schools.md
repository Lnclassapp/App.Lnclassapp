# TICKET-2: L'Organisation Scolaire (DRENAs, Écoles, Classes)

## Question
Comment modéliser l'organisation territoriale et scolaire (DRENAs, Écoles, Classes) selon l'architecture Hexagonale (Entities, Ports, UseCases) pour garantir une gestion propre des entités académiques et de leurs relations ?

## Type
wayfinder:task (HITL)

## Objectifs (Checklist)
- [x] Rédiger l'ADR (`docs/ADR/`) pour valider les Entities et Ports de l'organisation scolaire (Drena, School, Classroom).
- [x] Rédiger l'UDR (`docs/UDR/`) pour valider la direction visuelle de la liste des écoles/classes.
- [x] Créer les tests (TDD) pour les *Use Cases* de récupération et de gestion des écoles (ManageSchool, etc.).
- [x] Implémenter la couche Domaine (`app/domain/entities/identity/`, `app/domain/ports/identity/`, `app/domain/use_cases/identity/`). *Note: les écoles peuvent relever du contexte Identity ou d'un contexte School dédié.*
- [x] Implémenter la couche Infrastructure (`app/infrastructure/repositories/identity/school_repository.rb`, etc.).
- [x] Refactoriser les Contrôleurs (`app/controllers/catalog/schools_controller.rb` et `drenas_controller.rb`) pour utiliser les *Repositories Hexagonaux*.
- [x] Appliquer les tags HITL dans chaque fichier touché.

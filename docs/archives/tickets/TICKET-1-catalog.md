# TICKET-1: Le Catalogue Pédagogique (Niveaux, Matières, Cours)

## Question
Comment modéliser et refactoriser le cœur du catalogue pédagogique (Niveaux, Matières, Cours) selon l'architecture Hexagonale (Entities, Ports, UseCases) et le déployer via des contrôleurs Rails ultra-fins, tout en modernisant l'UI avec la skill `interface-design` ?

## Type
wayfinder:task (HITL)

## Objectifs (Checklist)
- [ ] Rédiger l'ADR (`docs/ADR/`) pour valider les Entities et Ports du catalogue.
- [ ] Rédiger l'UDR (`docs/UDR/`) pour valider la direction visuelle de l'affichage des cours.
- [ ] Invoquer `interface-design` pour figer le système de design (`system.md`).
- [ ] Créer les tests (TDD) pour les *Use Cases* de récupération et création de cours.
- [ ] Implémenter la couche Domaine (`app/domain/entities`, `app/domain/ports`, `app/domain/use_cases`).
- [ ] Implémenter la couche Infrastructure (`app/infrastructure/repositories`).
- [ ] Refactoriser les Contrôleurs (`app/controllers/catalog/`) pour utiliser les *Use Cases*.
- [ ] Appliquer les tags HITL dans chaque fichier touché.

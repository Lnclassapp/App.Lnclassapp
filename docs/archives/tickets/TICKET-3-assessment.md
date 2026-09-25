# 🎫 TICKET-3 : Le Moteur d'Évaluation (Exercices & Sessions)

## 🎯 Objectif
Migrer le cœur du système d'évaluation vers l'architecture hexagonale. Ce ticket englobe la création des exercices, des questions, ainsi que le suivi des sessions des élèves (tentatives, scores, et badges).

## 🗂️ Modèles (Orm) ciblés
- `Orm::Exercise`
- `Orm::Question`
- `Orm::Answer`
- `Orm::ClassroomExercise`
- `Orm::ExerciseSession`
- `Orm::QuestionAttempt`
- `Orm::ExerciseBadge`

## 🏗️ Architecture Hexagonale (Couche Domaine)

### 1. Entités (`Entities::Assessment::...`)
- [ ] `Exercise` (Titre, description, durée, difficulté, etc.)
- [ ] `Question` (Enoncé, type, points)
- [ ] `Answer` (Contenu, est_correcte)
- [ ] `Session` (Scores, tentatives, statut)

### 2. Ports (Interfaces)
- [ ] `Repositories::Assessment::ExerciseRepositoryInterface`
- [ ] `Repositories::Assessment::SessionRepositoryInterface`

### 3. Use Cases
- [ ] `UseCases::Assessment::StartExerciseSession` (Initialiser une session pour un élève)
- [ ] `UseCases::Assessment::SubmitQuestionAttempt` (Soumettre une réponse et calculer les points)
- [ ] `UseCases::Assessment::CompleteExercise` (Terminer l'exercice et attribuer le badge)

## 🔌 Couche Infrastructure
- [ ] Création / Mise à jour des `Orm` sous le namespace `Orm::` avec `self.table_name`.
- [ ] Implémentation du `ExerciseRepository` (Mapping DB ↔️ Entité `Exercise`).
- [ ] Implémentation du `SessionRepository` (Mapping DB ↔️ Entité `Session`).

## 🎨 Couche Présentation & UI/UX
- [ ] Affichage de la liste des exercices disponibles pour une classe.
- [ ] Interface de composition d'un exercice (questions et réponses).
- [ ] Vue élève : Interface de passage d'un exercice (mode focus).
- [ ] Vue Dashboard : Résultats et badges obtenus.

## 🔗 Dépendances
- **TICKET-1** (Niveaux & Matières) : Requis pour classer les exercices.
- **TICKET-2** (Classes) : Requis pour assigner les exercices (`classroom_exercises`) et identifier les élèves.

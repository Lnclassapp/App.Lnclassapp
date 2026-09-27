# ADR-0023 : Modélisation de l'Organisation Scolaire (Hexagonale)

| | |
|---|---|
| **Statut** | Remplacé — *voir l'avertissement ci-dessous* |
| **Date** | — |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | [ADR-0027](./0027-contextes-bornes-et-arborescence.md) |

---

> ⚠️ **Décision remplacée — l'organisation scolaire vit dans le contexte `school`.**
> L'[ADR-0027](./0027-contextes-bornes-et-arborescence.md) remplace cet ADR en entier le 2026-09-25 : six contextes bornés, la DRENA, l'école et la classe ne sont plus dans `identity`, et toute personne est référencée par `users.id`.

> ℹ️ **Renuméroté de ADR-0015 en ADR-0023** lors de la normalisation du corpus : le numéro 0015 était porté simultanément par ce document et par l'[ADR-0015 — Stratégie de tests métier](./0015-strategie-de-tests-metier-isolement-des-policies.md). Les en-têtes HITL du code (`app/domain/entities/identity/`, `app/domain/ports/identity/`, `app/infrastructure/repositories/identity/`, tests associés) référencent encore « ADR-0015 (Organisation Scolaire) » et devront être mis à jour vers ADR-0023.

## 1. Contexte et problématique
L'application doit gérer une hiérarchie administrative stricte : DRENA -> École -> Classe. Actuellement, ces modèles sont fortement couplés à `ActiveRecord` (`Orm::Drena`, `Orm::School`, `Orm::Classroom`). Pour migrer vers l'architecture Hexagonale (TICKET-2), nous devons isoler cette logique dans la couche **Domaine**.

## 2. Décision

Nous allons définir un nouveau *Bounded Context* appelé `Identity` (ou `Schooling` / `Organization` - on choisit `Identity` car il regroupe généralement les entités, écoles, rôles).

1. **Entities (Couche Domaine pure)** :
   - `Entities::Identity::Drena` : Représente la Direction Régionale (nom, slug).
   - `Entities::Identity::School` : Représente l'établissement (nom, sigle, statut, type, drena).
   - `Entities::Identity::Classroom` : Représente une classe physique (nom, code unique, niveau, série, école).
   Elles hériteront de `ActiveModel::Model` pour les validations pures, sans aucune persistance.

2. **Ports (Interfaces d'accès)** :
   - `Ports::Identity::SchoolRepositoryPort` : Définit les contrats (ex: `find_all`, `find_by_drena`, `save`).
   - `Ports::Identity::ClassroomRepositoryPort` : Définit les contrats (ex: `find_by_school`, `save`).

3. **Repositories (Couche Infrastructure)** :
   - `Repositories::Identity::SchoolRepository` (implémente le port School).
   - `Repositories::Identity::ClassroomRepository` (implémente le port Classroom).
   Ils mapperont les objets `Orm::School` vers `Entities::Identity::School`.

4. **Use Cases (Couche Application/Domaine)** :
   - `UseCases::Identity::ManageSchool` (déjà partiellement existant, à refondre/valider).
   - `UseCases::Identity::GetSchools` (pour l'affichage de la liste).

## 3. Conséquences
- **Avantages** : L'affichage et la gestion des écoles et classes ne dépendront plus de l'ORM. Le contrôleur sera ultra-fin et les tests des *Use Cases* seront très rapides.
- **Inconvénients** : Nécessite l'écriture de mapping bidirectionnel (Entity <-> Orm) dans les Repositories.
- **Dette Technique** : L'entité `Classroom` fait référence à `Level` et `Series` qui appartiennent au contexte `Catalog`. Nous utiliserons simplement l'ID de ces éléments (`level_id`) ou nous chargerons des objets légers (DTO) pour éviter de coupler le contexte `Identity` au contexte `Catalog`.

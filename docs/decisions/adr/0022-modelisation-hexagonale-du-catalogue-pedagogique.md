# ADR-0022 : Modélisation Hexagonale du Catalogue Pédagogique
<!-- index
titre: Modélisation hexagonale du catalogue pédagogique
statut: ⚠️ **Remplacé partiellement** par [0026](./0026-contrat-result-entites-et-dto.md) *(§2.A à §2.C)* ; complété par [0035](./0035-cycle-de-vie-et-propriete-du-contenu.md)
problematique: Extraire le catalogue (Niveaux, Séries, Matières, Cours, Essentiels) des modèles ActiveRecord vers des entités, ports et use cases purs. *(Renuméroté depuis ADR-0014.)*
-->

| | |
|---|---|
| **Statut** | Remplacé partiellement — *voir l'avertissement ci-dessous* |
| **Date** | — |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | [ADR-0026](./0026-contrat-result-entites-et-dto.md) *(§2.A à §2.C)* |
| **Complété par** | [ADR-0035](./0035-cycle-de-vie-et-propriete-du-contenu.md) : §2.A (cycle de vie `draft` / `published` / `archived`) |

---

> ⚠️ **Décision partiellement remplacée — entités, ports et use cases suivent l'ADR-0026.**
> Le §2.A à §2.C est remplacé par l'[ADR-0026](./0026-contrat-result-entites-et-dto.md) le 2026-09-25 ; `BrowseCatalog` et `ViewCourse` ne sont pas repris. Le statut du contenu est fixé par l'[ADR-0035](./0035-cycle-de-vie-et-propriete-du-contenu.md). La modélisation du catalogue (niveaux, séries, matières, cours, fiches) reste la référence métier.

> ℹ️ **Renuméroté de ADR-0014 en ADR-0022** lors de la normalisation du corpus : le numéro 0014 était porté simultanément par ce document et par l'[ADR-0014 — Standardisation des namespaces](./0014-standardisation-namespaces-et-validation-frontiere.md). Les en-têtes HITL du code (`app/domain/entities/catalog/`, `app/domain/ports/catalog/`, `app/domain/use_cases/catalog/`, tests associés) référencent encore « ADR-0014 (Architecture Hexagonale Catalogue) » et devront être mis à jour vers ADR-0022.

## 1. Contexte et problématique
Dans le cadre de la migration de l'application Lnclass vers l'architecture hexagonale (Ticket-1), nous devons extraire la logique métier du "Catalogue Pédagogique" des modèles ActiveRecord (ORM) pour la placer dans la couche Domaine.

Le catalogue pédagogique est le socle de l'application. Il contient :
- Les Niveaux (`Level`)
- Les Séries (`Series`) et leur table de jonction (`LevelSeries`)
- Les Matières (`Material`)
- Les Cours (`Course`)
- Les Notions clés (`Essential`)

L'objectif est d'isoler ces entités des contraintes de base de données et de fournir des Ports (Interfaces) pour leur persistance.

## 2. Décision

### A. Les Entités (Entities)
Nous allons créer les objets Ruby purs suivants dans `app/domain/entities/catalog/` :
* `Entities::Catalog::Level` : Représente un niveau scolaire (ex: Terminale). Attributs : `id`, `name`, `public_id`, `slug`.
* `Entities::Catalog::Series` : Représente une série d'études (ex: D, C). Attributs : `id`, `name`, `public_id`, `slug`.
* `Entities::Catalog::Material` : Représente une matière (ex: Mathématiques). Attributs : `id`, `name`, `shortname`, `category`, `public_id`.
* `Entities::Catalog::Course` : Agrégat racine. Représente un cours. Attributs : `id`, `name`, `slug`, `status`, `published_at`, et les références vers `Level`, `Series`, `Material`.
* `Entities::Catalog::Essential` : Composant d'un cours. Attributs : `id`, `name`, `slug`, `course_id`, `validated_at`.

### B. Les Ports (Contrats d'Infrastructure)
Nous allons définir les contrats (Interfaces) suivants dans `app/domain/ports/catalog/` :
* `Ports::Catalog::CourseRepositoryPort` :
  - `#find_by_slug(slug) -> Entities::Catalog::Course`
  - `#find_published(filters) -> Array[Entities::Catalog::Course]`
  - `#save(course_entity) -> Entities::Catalog::Course`
* `Ports::Catalog::TaxonomyRepositoryPort` :
  - Gère les requêtes transversales pour le filtre du catalogue.
  - `#all_levels -> Array[Entities::Catalog::Level]`
  - `#materials_for_level(level_id) -> Array[Entities::Catalog::Material]`
  - `#series_for_level(level_id) -> Array[Entities::Catalog::Series]` (Ceci abstrait la table de jonction `LevelSeries` au sein du Repository).
* `Ports::Catalog::EssentialRepositoryPort` :
  - `#find_by_course(course_id) -> Array[Entities::Catalog::Essential]`
  - `#save(essential_entity) -> Entities::Catalog::Essential`

### C. Les Cas d'Usage (Use Cases)
Nous créons les Use Cases suivants, instanciables par les Contrôleurs :
* `UseCases::Catalog::ViewCourse` : Récupère un cours et ses essentiels associés (Injecte CourseRepository et EssentialRepository).
* `UseCases::Catalog::BrowseCatalog` : Récupère la liste des cours filtrés et les taxonomies disponibles (Injecte CourseRepository et TaxonomyRepository).

## 3. Conséquences
- **Abstraction de `LevelSeries`** : La couche domaine ne connaît pas l'entité de jonction `LevelSeries`. C'est le `TaxonomyRepository` (Infrastructure) qui se chargera d'interroger cette table SQL et de retourner une liste pure d'entités `Series`.
- Les contrôleurs Rails du catalogue (`app/controllers/catalog/courses_controller.rb`) ne feront plus de requêtes `.where` ou `.includes`. Ils appelleront `UseCases::Catalog::BrowseCatalog.new(repo).call(params)`.
- Les validateurs de création de cours, ainsi que la vérification du statut `published_at`, appartiendront à l'entité `Course` et non plus à ActiveRecord.

# ADR-0014 : Standardisation des Namespaces et Validation aux Frontières (DTOs)
<!-- index
titre: Standardisation des namespaces et validation aux frontières (DTOs)
statut: ⚠️ **Remplacé partiellement** par [0027](./0027-contextes-bornes-et-arborescence.md) *(§2.2)* ; amendé par [0026](./0026-contrat-result-entites-et-dto.md) *(§2.1)*
problematique: Valider les inputs HTTP via des objets dédiés avant le passage au Domaine, et clarifier les espaces `presentation/`, `adapters/`, `ports/`.
-->

| | |
|---|---|
| **Statut** | Remplacé partiellement — *voir l'avertissement ci-dessous* |
| **Date** | 2026-08-15 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | [ADR-0027](./0027-contextes-bornes-et-arborescence.md) *(§2.2)* |
| **Amendé par** | [ADR-0026](./0026-contrat-result-entites-et-dto.md) : §2.1 (DTO sans ActiveRecord) |

---

> ⚠️ **Décision partiellement remplacée — les namespaces suivent l'ADR-0027.**
> Le §2.2 est remplacé par l'[ADR-0027](./0027-contextes-bornes-et-arborescence.md) le 2026-09-25 : rangement par couche puis par contexte, sans `presentation/` ni `adapters/`. Le §2.1 est amendé par l'[ADR-0026](./0026-contrat-result-entites-et-dto.md). La validation aux frontières par DTO reste en vigueur.

## 1. Contexte et problématique
Consolidation de l'Architecture Hexagonale suite à la migration vers Rails 8.

Bien que l'architecture globale soit en place (Domaine, Infrastructure, Présentation), des zones de flou persistent aux frontières du système :
1. **Couplage Web-Domaine** : Les contrôleurs manipulent parfois directement des paramètres non typés ou s'appuient sur des entités complexes en entrée, affaiblissant l'isolation du Domaine. (L'ADR-0013 a introduit l'idée des DTOs, ce document vient standardiser leur utilisation systématique).
2. **Manque de granularité dans l'Infrastructure et la Présentation** : L'infrastructure manque d'un espace clair pour isoler les services externes (APIs tierces), et la présentation mélange parfois logique d'affichage complexe et code de contrôleur.

## 2. Décision

### 2.1 Validation stricte via DTOs (Pragmatisme)
* Tous les paramètres entrants (input utilisateur issu de requêtes HTTP) doivent être encapsulés et validés par des objets dédiés avant d'être envoyés aux Use Cases.
* **Compromis assumé** : Bien que l'architecture hexagonale stricte interdise les dépendances de framework dans le Domaine, le projet **tolère l'utilisation de `ActiveModel::Model` au sein de `app/domain/dtos/`**. Ce choix pragmatique permet de bénéficier des validations simples de Rails (ex: `validates`) tout en évitant d'écrire deux objets séparés (Form Object et pur Data Struct) pour chaque requête, afin d'accélérer le développement au quotidien.

### 2.2 Standardisation des Namespaces
* **`app/presentation`** : En plus de `controllers/`, la couche présentation adoptera les sous-dossiers `presenters/` (pour délester les vues et contrôleurs de la logique d'affichage complexe) et `serializers/` (pour formater le rendu JSON).
* **`app/infrastructure/adapters`** : Nouveau répertoire dédié à l'implémentation des appels d'APIs externes (Output Ports non liés à la BDD persistante).
* **`app/domain/ports`** : Explicitation de la séparation logique entre les Input Ports (interfaces d'entrée des Use Cases) et les Output Ports (interfaces requises pour l'infrastructure et les adapters externes).

## 3. Conséquences
* **Conséquences Positives** : Amélioration drastique de la testabilité unitaire (les formulaires valident leurs données séparément), isolation parfaite du Domaine, code plus lisible et Single Responsibility Principle (SRP) mieux respecté.
* **Conséquences Négatives** : Multiplication du nombre de classes et de petits fichiers (Classes DTO/Form). Un léger effort de refactoring initial est nécessaire sur le code existant.

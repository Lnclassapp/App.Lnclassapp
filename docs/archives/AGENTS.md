# Lnclass Hexagonal & Migration Rules

Ce fichier définit les standards comportementaux et les contraintes techniques pour la migration et le recodage du projet Lnclass vers Rails 8.

---

## 📐 1. Standards d'Architecture Hexagonale

### 🟢 A. Couche Domaine (`app/domain/`)
* **Entities (`app/domain/entities/`)** :
  * Ce sont des objets de données pures, agnostiques du framework et de la base de données.
  * Utiliser `ActiveModel::Model` pour bénéficier des validations Rails standards sans persistance.
  * **Règle absolue** : Aucun import de modèle ORM (`Orm::...`), aucun appel de requête SQL, aucune utilisation de `.where`, `.find`, ou `.save`.
* **Ports (`app/domain/ports/`)** :
  * Ce sont les interfaces définissant les contrats de persistance.
  * Les méthodes doivent lever une exception `NotImplementedError` par défaut.
* **Use Cases (`app/domain/use_cases/`)** :
  * Représentent la logique métier d'une action utilisateur unique.
  * Injecter les Repositories nécessaires via le constructeur (`initialize`).
  * N'exposer qu'une seule méthode publique : `#call`.

### 🟡 B. Couche Infrastructure (`app/infrastructure/`)
* **ORM (`app/infrastructure/orm/`)** :
  * Tous les modèles ActiveRecord doivent résider sous ce namespace (ex: `Orm::User`).
  * Toujours déclarer explicitement la table de mappage (ex: `self.table_name = "users"`).
  * Intégrer les concerns de validation partagés (comme `ContactConcern`, `Sluggable`, `PublicIdGenerator`).
  * Utiliser `has_nanoid` et FriendlyId si nécessaire.
* **Repositories (`app/infrastructure/repositories/`)** :
  * Implémentent les interfaces définies par les Ports de la couche Domaine.
  * Reçoivent et retournent uniquement des entités du Domaine (`Entities::...`), cachant les détails de l'ORM ActiveRecord.
  * Mapper explicitement les attributs lors du passage de l'ORM à l'Entité et vice-versa.
  * *Note de migration* : Si une table n'est pas encore créée au cours des étapes intermédiaires, stubber temporairement les requêtes dépendantes dans les Repositories (retourner `[]` ou `nil`) pour maintenir le contrat de Port valide.

### 🔵 C. Couche Présentation (`app/controllers/`, `app/views/`)
* **Contrôleurs Rails** :
  * Agissent uniquement comme *Delivery Mechanism*. Ne contiennent AUCUNE logique métier.
  * Doivent instancier les *Use Cases* de la couche Domaine, leur passer les paramètres, et renvoyer la vue ou la redirection appropriée.
  * Les décisions techniques de cette couche (ex: authentification, flux HTTP) sont documentées par les **ADR**.
* **Vues & Hotwire (`.html.erb`, `.turbo_stream.erb`)** :
  * C'est ici que l'expérience utilisateur prend vie (mise à jour asynchrone du DOM, micro-interactions).
  * Les décisions de design, de comportement et de retour visuel (ex: pourquoi ajouter cet élément en direct sans recharger) sont documentées par les **UDR** (UI/UX Decision Records).
  * Les décisions d'implémentation asynchrone (ex: stratégie WebSockets / `broadcast`) relèvent des **ADR**.

---

## 🗄️ 2. Gestion de la Persistance et Migrations

### 🟢 A. Ordre de Création et Clés Étrangères
* Suivre l'ordre des priorités défini dans le plan de migration pour éviter les conflits de clés étrangères SQL.
* **Priorité 4 : Programme Pédagogique** (`materials`, `courses`, `essentials`, `classroom_courses`, `classroom_essentials`).
* **Priorité 5 : Évaluations & Exercices** (`exercises`, `questions`, `answers`, `classroom_exercises`).
* **Priorité 6 : Résultats & Sessions** (`exercise_sessions`, `question_attempts`, `exercise_badges`).

### 🟡 B. Règle d'Audit et Découplage
* Lors de la création de tables contenant des références à des administrateurs (`team_id`), utiliser `foreign_key: { on_delete: :nullify }` et autoriser les colonnes à être nulles. Ceci empêche la suppression en cascade d'éléments structurels (comme des écoles ou matières) si un profil administrateur est supprimé.

---

## 🛠️ 3. Processus de Validation Systématique
* **Migrations** : Exécuter immédiatement `bin/rails db:migrate` après la création de fichiers de migration.
* **Vérification de Compilation** : Valider que les nouveaux fichiers et les constantes Zeitwerk se chargent correctement en exécutant :
  ```bash
  bin/rails runner "puts MonEspace::MaClasse.name"
  ```

---

## 🧠 4. Obligation de Documentation Human-in-the-Loop (HITL)
* **Standard Obligatoire** : Tout fichier créé, modifié ou refactorisé au sein de l'arborescence `app/` (Ruby, Javascript Stimulus, Templates ERB) DOIT obligatoirement comporter en tout début de fichier un en-tête architectural officiel conforme aux templates définis dans `docs/STANDARD/hitl_docstrings.md`.
* **Éléments Requis dans l'en-tête** :
  * Le nom ou composant ciblé (ex: `# = Entities::User` ou `<%# = View: ... %>`).
  * La couche architecturale exacte (Domaine, Infrastructure, Présentation).
  * L'ADR associé pour les décisions d'architecture (ex: **ADR-0001**).
  * L'UDR (UI/UX Decision Record) associé pour les décisions de design/interface.
  * Le rôle **Human-in-the-Loop (HITL)** expliquant clairement pourquoi ce composant existe et ce qu'il fait dans le système.
  * Les contrats de données, attributs ou dépendances injectées.

* **Règle de consultation UDR/ADR** :
  * Lors de la création ou modification d'une interface (HTML, CSS, JS/Stimulus), l'agent DOIT rechercher et lire les UDR pertinents dans `docs/UDR/`.
  * Lors de la création ou modification de la logique métier (Domaine, Infrastructure), l'agent DOIT rechercher et lire les ADR pertinents dans `docs/ADR/`.
* **Pragma Ruby** : Tout fichier Ruby (`*.rb`) doit débuter par son commentaire d'en-tête suivi ou précédé de `# frozen_string_literal: true`.
* **Validation Avant Livraison** : Aucun code ne doit être soumis sans avoir été au préalable audité techniquement (zéro erreur syntaxique via `ruby -c` et vérification de conformité via l'outil `bin/validate_hitl`).

# Règles d'emplacement des scripts
- Place toujours les scripts utilitaires générés dans le dossier `script` du projet (et non à la racine).

---

## 🧭 5. Wayfinder & Isolation des Tâches (Git)
* **Création de Branche Obligatoire** : Toute résolution d'un ticket issu de la `MIGRATION_MAP.md` DOIT se faire dans une branche Git isolée.
* **Nomenclature** : Le nom de la branche doit correspondre au ticket ciblé. Par exemple : `feature/ticket-1-catalog`.
* **Principe d'Isolation** : Aucune modification de code (autre que la documentation du projet) ne doit être faite directement sur la branche principale `Develop`. Chaque ticket résolu fera l'objet d'un merge request.

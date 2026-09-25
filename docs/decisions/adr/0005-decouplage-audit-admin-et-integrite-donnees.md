# ADR-0005 : Découplage de l'Audit Admin (`Team`) et Règle d'Intégrité des Données Structurelles

| | |
|---|---|
| **Statut** | Accepté — *instauré comme norme absolue de migration* |
| **Date** | 2026-07-02 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Lors des phases initiales de développement d'un LMS, il est courant d'associer un objet métier (une école, une matière, un niveau ou un chapitre) à l'administrateur ou au créateur de contenu qui en a effectué la saisie (`team_id` ou `creator_id`), afin de maintenir une traçabilité d'audit.

Dans Rails, le réflexe habituel lors de la déclaration d'une association `has_many` est d'ajouter l'option `dependent: :destroy`.  
Cependant, dans le contexte de Lnclass, appliquer `dependent: :destroy` sur le modèle administrateur `Team` constitue un danger architectural critique :
* Si un membre de l'équipe quitte le projet, ou si un compte administrateur de test est supprimé, la réaction en chaîne en base de données effacerait en cascade les établissements scolaires (`schools`), les classes (`classrooms`), les élèves inscrits, les cours (`courses`) et tout le catalogue d'exercices créés par cet administrateur.
* Une simple suppression de compte admin pourrait anéantir des années de données de scolarité et de résultats d'examen.

---

## 2. Moteurs de décision
* **Intégrité Absolue du Curriculum et des Écoles :** Garantir qu'aucune ressource pédagogique structurelle ou organisationnelle ne puisse disparaître suite à la suppression d'un compte utilisateur ou admin.
* **Audit et Traçabilité Sans Couplage Destructeur :** Continuer à enregistrer qui a créé ou importé une école ou un cours, mais découpler le cycle de vie de la ressource créée de celui de son créateur.
* **Sécurité des Migrations :** Interdire formellement au niveau du moteur de base de données PostgreSQL les suppressions en cascade sur les entités structurelles.

---

## 3. Décision
Nous instaurons la règle stricte du **Découplage d'Audit Anti-Cascade** :
1. Sur toutes les tables structurelles ou pédagogiques rattachées à une équipe ou un administrateur (`schools`, `levels`, `materials`, `courses`, `essentials`, `exercises`), la clé étrangère SQL pointant vers `teams` ou `users` doit être **nullable** (`null: true`).
2. La contrainte de clé étrangère dans PostgreSQL doit être déclarée avec l'option **`on_delete: :nullify`** (et jamais `on_delete: :cascade`).
3. Dans la couche ORM, l'association doit être marquée **`optional: true`** et ne doit jamais porter d'attribut `dependent: :destroy` ou `dependent: :delete_all`.

---

## 4. Conséquences

### 🟢 Positives
* **Sécurité des Données Blindée :** La suppression d'un profil administrateur met simplement à `NULL` sa référence sur les écoles et cours qu'il a créés, laissant l'écosystème pédagogique et les élèves totalement intacts.
* **Sérénité Opérationnelle :** L'équipe de support peut nettoyer ou réorganiser les profils internes sans crainte d'effet de bord sur la production.

### 🔴 Coûts consentis
* **Orphelins d'Audit :** Certaines écoles ou ressources anciennes afficheront `creator_id: nil` dans la base de données après la suppression de l'auteur d'origine (ce qui est un compromis parfaitement acceptable par rapport à la perte des données).

---

## 5. Notes d'implémentation

Exemple de rédaction conforme d'une migration SQL pour une ressource structurelle :
```ruby
# db/migrate/XXXX_create_schools.rb
class CreateSchools < ActiveRecord::Migration[8.1]
  def change
    create_table :schools do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :unique_code, null: false
      t.references :drena, null: false, foreign_key: true
      
      # RÈGLE D'AUDIT ANTI-CASCADE : Colonne nullable + on_delete: :nullify
      t.references :team, null: true, foreign_key: { on_delete: :nullify }

      t.timestamps
    end
  end
end
```

Configuration dans le modèle de l'Infrastructure ORM :
```ruby
# app/infrastructure/orm/school.rb
module Orm
  class School < ApplicationRecord
    self.table_name = "schools"

    belongs_to :drena, class_name: "Orm::Drena"
    
    # Règle d'or : optional: true et AUCUN dependent: :destroy
    belongs_to :team, class_name: "Orm::Team", optional: true
    
    has_many :classrooms, class_name: "Orm::Classroom", dependent: :restrict_with_error
  end
end
```

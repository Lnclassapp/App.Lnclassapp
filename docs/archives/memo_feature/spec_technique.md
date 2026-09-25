# 🛠 [Feature Name] - Spécifications Techniques

> **Focus :** Architecture Hexagonale, Modélisation de Données, Contrats d'Interface (Ports), Endpoints HTTP, Turbo Streams et Configuration Strada.
> **Date de création :** YYYY-MM-DD
> **Statut :** [Brouillon / En Cours / Validé]

---

## 1. Architecture Hexagonale & Organisation du Code
Cette fonctionnalité respecte strictement l'isolation du domaine métier.

```mermaid
graph TD
    subgraph Présentation (Web/Mobile)
        Controller[Controller Rails]
        Stimulus[Stimulus/Strada Controller]
    end

    subgraph Domaine (Métier Pur)
        UseCase[Use Case]
        Entity[Entity]
        Port[Repository Port]
    end

    subgraph Infrastructure (Persistance/Externe)
        Repo[Repository Adapter]
        ORM[ActiveRecord ORM Model]
        DB[(Base de données)]
    end

    Controller -->|Appelle| UseCase
    UseCase -->|Manipule| Entity
    UseCase -->|Appelle| Port
    Repo -.->|Implémente| Port
    Repo -->|Manipule| ORM
    ORM -->|Persiste| DB
```

### 1.1. Couche Domaine (Pure Ruby)
* **Entités** (`app/domain/entities/`) :
  * `Entities::[EntityName]` : Liste des attributs, validations ActiveModel (optionnel) et méthodes métiers.
* **Ports (Interfaces)** (`app/domain/ports/`) :
  * `Ports::[EntityName]RepositoryPort` : Signature des méthodes d'accès aux données.
* **Use Cases (Cas d'Usage)** (`app/domain/use_cases/`) :
  * `UseCases::[ActionName]` : Une seule méthode publique `#execute(params)`. Pas d'appels directs à ActiveRecord. Injection du repository via le constructeur.

### 1.2. Couche Infrastructure (Adaptateurs)
* **Modèles ORM** (`app/models/` / `app/infrastructure/orm/`) :
  * `::[ModelName]` : Configuration ActiveRecord pure, associations, scopes.
* **Repositories** (`app/infrastructure/repositories/`) :
  * `Repositories::[EntityName]Repository` : Implémente le Port. Mappe les modèles ORM vers les Entités du domaine.

---

## 2. Modélisation des Données & Schéma
Détails des tables de base de données impliquées ou modifiées.

### 2.1. Changements de Schéma (Migration)
```ruby
# db/migrate/YYYYMMDDHHMMSS_create_[table_name].rb
class Create[TableName] < ActiveRecord::Migration[8.0]
  def change
    create_table :[table_name] do |t|
      t.references :other_table, null: false, foreign_key: true
      t.string :field_name, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
    add_index :[table_name], :field_name
  end
end
```

---

## 3. Contrats d'Interface & API (Ports)

### 3.1. `Ports::[EntityName]RepositoryPort`
```ruby
module Ports
  module [EntityName]RepositoryPort
    def find_by_id(id); raise NotImplementedError; end
    def save(entity); raise NotImplementedError; end
    def delete(id); raise NotImplementedError; end
  end
end
```

---

## 4. Points d'Entrée & Couche Présentation (HTTP / Hotwire)

### 4.1. Routes & Endpoints
* **URL :** `POST /exercises/:exercise_id/sessions`
  * **Contrôleur :** `ExerciseSessionsController#create`
  * **Payload attendu :** `{ exercise_id: string }`
  * **Format de réponse :** HTML (Redirection) ou Turbo Stream (Mise à jour partielle).

### 4.2. Turbo Stream Payload (Rendu Temps Réel)
En cas de succès ou d'erreur, description du comportement Turbo Stream.
```html
<!-- app/views/exercise_sessions/update.turbo_stream.erb -->
<turbo-stream action="replace" target="question_frame">
  <template>
    <%= render partial: "exercise_sessions/question_card", locals: { question: @current_question, session: @session } %>
  </template>
</turbo-stream>

<turbo-stream action="append" target="toasts_container">
  <template>
    <%= render partial: "shared/toast", locals: { type: :notice, message: "Réponse enregistrée !" } %>
  </template>
</turbo-stream>
```

---

## 5. Spécificités Hotwire Native & Strada (Hybride)
*Si la feature requiert une interaction native spécifique.*

### 5.1. Détection Mobile
```ruby
# ApplicationController ou concern
def turbo_native_app?
  request.user_agent.to_s.include?("Turbo Native")
end
```

### 5.2. Attributs Strada (Pont JavaScript)
Signature du contrôleur Stimulus reliant la page web à l'application native :
* **Stimulus Controller :** `strada-[component-name]`
* **Attributes / Data Map :**
  ```html
  <div data-controller="strada-[component-name]"
       data-strada-[component-name]-title-value="Titre Natif"
       data-action="click->strada-[component-name]#triggerNativeAction">
  </div>
  ```
* **Comportement Natif Déclenché :**
  * Android : Appel du composant native Kotlin `[ComponentName]Component.kt`.
  * iOS : Appel du composant native Swift `[ComponentName]Component.swift`.

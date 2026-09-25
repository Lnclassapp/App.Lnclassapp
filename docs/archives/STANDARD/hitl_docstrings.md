# 📋 Standard de Documentation "Human-in-the-Loop" (HITL) — Lnclass

Ce document définit la norme officielle pour la documentation des fichiers du répertoire `app/` au sein de l'application **Lnclass** (Entities, Use Cases, Ports, Repositories, ORM Models, Controllers, Helpers, Views ERB et Javascript Stimulus). L'objectif est d'offrir une clarté immédiate aux développeurs humains supervisant le code ou collaborant avec des assistants IA (Human-in-the-Loop).

---

## 🎯 1. Philosophie & Pourquoi ce Standard ?
Dans une architecture hexagonale sous Rails 8, un fichier ne s'auto-explique pas toujours sur **son rôle architectural global**.  
Un simple commentaire comme `# initialise la variable` est du bruit inutile. À l'inverse, un **En-Tête Architectural HITL** doit répondre à 4 questions cruciales dès les premières lignes du fichier :

1. **Dans quelle couche architecturale se situe ce fichier ?** (Domaine / Infra / UI / JS)
2. **Quel est son rôle métier exact ?** (Ce qu'un humain doit comprendre avant de modifier une ligne)
3. **Quelles sont ses dépendances et contrats ?** (Quels Ports sont injectés, quels arguments entrent/sortent, quels controllers Stimulus sont liés)
4. **Quel ADR régit ce composant ?** (Pour ne jamais briser une règle fondamentale)

---

## 📐 2. Templates par Couche Architecturale (Ruby, JS, ERB)

### 🟢 A. Couche Domaine — Entities (`app/domain/entities/`)
```ruby
# frozen_string_literal: true

# = Entities::NomDeLEntite
#
# 🧠 COUCHE DOMAINE — Objet de Données Pures & Règles Métier (Zéro Couplage ORM)
# 📑 ADR ASSOCIÉ : ADR-0001 (Architecture Hexagonale)
#
# 👤 RÔLE HUMAN-IN-THE-LOOP :
# Représente le concept de [...] dans le domaine éducatif. Cet objet est totalement agnostique
# de la base de données PostgreSQL. Il ne doit jamais contenir d'appels à .where, .save ou .find.
#
# 🔌 CONTRAT D'ATTRIBUTS :
# - +id+ (Integer|nil) : Identifiant interne (nil si non persisté).
# - +public_id+ (String) : Identifiant public sécurisé (ex: nanoid 'stdt_xxxx').
```

### 🟢 A2. Couche Domaine — DTO (Data Transfer Objects) (`app/domain/dtos/`)
```ruby
# frozen_string_literal: true

# = Dtos::NomDuDTO
#
# 🧠 COUCHE DOMAINE — Objet de Transport & Validation Primaire
# 📑 ADR ASSOCIÉ : ADR-0013 (Introduction des DTO)
#
# 👤 RÔLE HUMAN-IN-THE-LOOP :
# Valide et sécurise les paramètres bruts web (ActionController::Parameters) avant
# leur injection dans un Use Case. Agit comme un bouclier anti-corruption.
#
# 🔌 CONTRAT D'ATTRIBUTS :
# - +attribut1+ (Type) : Description...
```

### 🟢 B. Couche Domaine — Use Cases (`app/domain/use_cases/`)
```ruby
# frozen_string_literal: true

# = UseCases::NomDuUseCase
#
# 🧠 COUCHE DOMAINE — Orchestrateur d'Action Métier Unique
# 📑 ADR ASSOCIÉ : ADR-0001, ADR-0006 (Séparation CQRS / Écriture)
#
# 👤 RÔLE HUMAN-IN-THE-LOOP :
# Orchestre le processus de [...] lorsqu'un utilisateur déclenche cette action.
# Contient les validations métier croisées et délègue la persistance aux Ports.
#
# 🔌 DÉPENDANCES INJECTÉES (#initialize) :
# - +xx_repo+ : Implémentation d'un Port de Repository (ex: Ports::XxRepositoryPort).
#
# 📥 CONTRAT D'ENTRÉE (#execute) :
# - +input+ (Dtos::NomDuDTO) : Objet validé contenant les paramètres métier.
#
# 📤 CONTRAT DE SORTIE :
# - OpenStruct(success?: Boolean, data/errors: ...)
```

### 🟢 C. Couche Domaine — Ports (`app/domain/ports/`)
```ruby
# frozen_string_literal: true

# = Ports::NomDuPort
#
# 🧠 COUCHE DOMAINE — Interface / Contrat de Persistance (Duck Typing)
# 📑 ADR ASSOCIÉ : ADR-0001 (Ports & Adapters)
#
# 👤 RÔLE HUMAN-IN-THE-LOOP :
# Définit les méthodes d'accès aux données dont le domaine a besoin pour fonctionner.
# Les méthodes doivent lever NotImplementedError par défaut afin de forcer l'adaptateur à respecter le contrat.
```

### 🟡 D. Couche Infrastructure — Repositories (`app/infrastructure/repositories/`)
```ruby
# frozen_string_literal: true

# = Repositories::NomDuRepository
#
# 🔌 COUCHE INFRASTRUCTURE — Adaptateur de Persistance ActiveRecord
# 📑 ADR ASSOCIÉ : ADR-0001, ADR-0005 (Intégrité des données)
#
# 👤 RÔLE HUMAN-IN-THE-LOOP :
# Implémente le contrat Ports::NomDuPort en utilisant l'ORM ActiveRecord (Orm::...).
# Responsable de la traduction bidirectionnelle entre les enregistrements SQL (Records) et les objets du domaine (Entities).
```

### 🟡 E. Couche Infrastructure — ORM Models (`app/infrastructure/orm/`, `app/models/`)
```ruby
# frozen_string_literal: true

# = Orm::NomDuModele
#
# 🔌 COUCHE INFRASTRUCTURE — Modèle de Persistance ActiveRecord
# 📑 ADR ASSOCIÉ : ADR-0001 (Hexagonal), ADR-0005 (Intégrité anti-cascade)
#
# 👤 RÔLE HUMAN-IN-THE-LOOP :
# Représente la table SQL +nom_table+ dans PostgreSQL. Définit les associations, les index
# et les validations de persistance de bas niveau (ex: unicité du contact ou du public_id).
# Règle d'audit : N'exécute aucune logique métier complexe ; celle-ci appartient à +Entities::...+.
```

### 🔵 F. Couche Présentation — Controllers (`app/controllers/`)
```ruby
# frozen_string_literal: true

# = NomController
#
# 🌐 COUCHE PRÉSENTATION — Adaptateur de Livraison Web & Hotwire
# 📑 ADR ASSOCIÉ : ADR-0009 (Stack Frontend Hotwire / Turbo)
#
# 👤 RÔLE HUMAN-IN-THE-LOOP :
# Reçoit les requêtes HTTP de l'utilisateur, vérifie les autorisations de session,
# invoque le Use Case ou la Query correspondante, et rend la réponse au format HTML ou Turbo Stream.
```

### 🔵 G. Couche Présentation — Helpers (`app/helpers/`)
```ruby
# frozen_string_literal: true

# = NomHelper
#
# 🎨 COUCHE PRÉSENTATION — Module d'Assistance pour le Rendu des Vues
# 📑 ADR ASSOCIÉ : ADR-0009 (Stack Frontend Vanilla CSS & Tailwind v4)
#
# 👤 RÔLE HUMAN-IN-THE-LOOP :
# Fournit des méthodes utilitaires pour formater les données, générer des classes Tailwind CSS v4
# dynamiques ou construire des composants réutilisables dans les vues ERB sans polluer les contrôleurs.
```

### 🎨 H. Couche Présentation — Vues ERB (`app/views/**/*.html.erb`)
```erb
<%# = View: nom_de_la_vue.html.erb | turbo_frame_id %>
<%# 🌐 COUCHE PRÉSENTATION — Template Hotwire & Tailwind CSS v4 %>
<%# 👤 RÔLE HITL : Affiche l'interface réactive en s'appuyant sur les Streams Turbo et Stimulus. %>
```

### ⚡ I. Couche Présentation — Javascript Stimulus (`app/javascript/controllers/*_controller.js`)
```javascript
// = Stimulus Controller: nom_controller.js
// ⚡ COUCHE PRÉSENTATION — Logique Réactive Côté Client
// 📑 ADR ASSOCIÉ : ADR-0009 (Hotwire, Stimulus & KaTeX)
//
// 👤 RÔLE HUMAN-IN-THE-LOOP :
// Gère les micro-interactions et le DOM dynamique (ex: affichage KaTeX, modales, menu)
// sans rechargement de page. S'attache aux éléments HTML via data-controller="nom".
```

---

## 💬 3. Commentaires Granulaires Obligatoires (Micro-Documentation)
En complément de l'en-tête général du fichier, le code interne doit suivre une règle de **Micro-Documentation stricte** :
1. **Dans les Vues (ERB/HTML)** : Chaque élément structurel d'un composant doit être commenté.
   * *Exemple pour une Card* : Commentez `<%# Titre %>`, `<%# Sous-titre %>`, `<%# Zone de Contenu %>`, `<%# Bouton d'action %>`, `<%# Dropdown %>`, etc.
2. **Dans le Ruby (Domaine, Infrastructure, Controllers)** :
   * Chaque méthode, requête ou fonction doit être précédée d'un commentaire explicatif qui décrit son objectif, ce qu'elle fait, et pourquoi.
3. **Universel** : Ce standard s'applique à **tous les dossiers** et à toutes les couches de l'application sans exception. Aucun bloc logique ou visuel complexe ne doit rester orphelin d'explications.

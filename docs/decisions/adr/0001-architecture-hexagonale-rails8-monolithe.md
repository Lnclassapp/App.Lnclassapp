# ADR-0001 : Adoption de l'Architecture Hexagonale (DDD) dans un Monolithe Rails 8
<!-- index
titre: Adoption de l'architecture hexagonale (DDD) dans un monolithe Rails 8
statut: Accepté
problematique: Isoler les règles métier (`app/domain/`) d'ActiveRecord et des contrôleurs pour obtenir des tests unitaires en quelques millisecondes et éliminer les « Fat Models ».
-->

| | |
|---|---|
| **Statut** | Accepté — *en production sur l'ensemble du projet Lnclass* |
| **Date** | 2026-06-05 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Lnclass est une plateforme éducative (LMS) et un écosystème pédagogique multi-cibles (Élèves, Enseignants, Établissements, Administrateurs) en pleine croissance en Côte d'Ivoire.
L'application doit gérer des règles métier académiques très riches : gestion du curriculum, inscriptions multiples aux classes, conditions d'accès aux évaluations, calculs de progression et attribution de récompenses.

Dans les applications Ruby on Rails traditionnelles, le pattern MVC conduit presque systématiquement à l'anti-pattern **"Fat Models, Skinny Controllers"** (ou pire, des contrôleurs et services surchargeant ActiveRecord). Lorsque la logique de gestion est intimement couplée à l'ORM ActiveRecord :
* Les tests unitaires deviennent lents car ils nécessitent d'accéder à la base de données relationnelle pour valider la moindre règle de calcul.
* Les changements de schéma ou d'optimisation SQL se propagent et brisent les règles de gestion.
* La complexité augmente de façon exponentielle au fur et à mesure que les fonctionnalités s'accumulent.

---

## 2. Moteurs de décision
* **Maintenabilité et Lisibilité :** Nécessité d'isoler les règles de gestion académiques de la plomberie technique (HTTP, SQL, Turbo, Tailwind).
* **Vitesse de Testabilité :** Volonté de pouvoir exécuter des milliers de tests unitaires sur les règles du domaine en quelques millisecondes sans toucher au disque ou à PostgreSQL.
* **Monolithe Modulaire :** Conserver la simplicité opérationnelle d'un seul dépôt Rails 8, d'un seul serveur de déploiement et d'une seule base de données (au lieu de microservices distribués complexes), tout en imposant des frontières strictes entre les modules.
* **Résilience au Temps :** Rendre l'application immunisée contre les montées de version majeures de Rails ou les changements d'API externes.

---

## 3. Décision
Nous adoptons l'**Architecture Hexagonale (Ports & Adapters / Domain-Driven Design)** au sein même de la structure d'application Rails 8.

L'application est divisée en 3 couches concentriques :
1. **Le Domaine (`app/domain/`)** : Le cœur de l'application en pur Ruby, ne dépendant d'absolument aucun framework. Il contient les entités de données (`Entities`), les contrats d'interface de persistance (`Ports`), les cas d'usage métiers (`UseCases`) et les validateurs/politiques (`Policies`).
2. **L'Infrastructure (`app/infrastructure/`)** : L'implémentation technique des détails du monde extérieur. Contient l'ORM ActiveRecord (`Orm::*` s'exécutant sur PostgreSQL), les implémentations des ports (`Repositories`), et les requêtes de lecture seule à haute performance (`Queries`).
3. **L'Application Web (`app/controllers/`, `app/views/`, `app/presenters/`)** : Le mécanisme de livraison, agissant comme un simple adaptateur Web et Hotwire qui invoque les cas d'usage et formate les réponses.

### La Règle Zéro Couplage
Il est formellement interdit pour n'importe quelle classe sous `app/domain/` d'hériter de `ApplicationRecord` ou de faire appel à l'API `ActiveRecord`. La communication passe exclusivement par injection de dépendances.

---

## 4. Conséquences

### 🟢 Positives
* **Pureté Métier et Vitesse :** Les Use Cases et Entités sont du code Ruby pur. Une suite de tests de domaine s'exécute quasi-instantanément sans base de données.
* **Onboarding Simplifié :** Un nouveau développeur comprend immédiatement où va le code : la logique d'une action va dans un Use Case, la requête SQL dans un Repository ou une Query, le rendu visuel dans une Vue.
* **Évolutivité de la Persistance :** Nous avons pu restructurer complètement la base de données relationnelle des élèves et enseignants (passage au multi-classes et multi-écoles) sans casser la logique du domaine qui consomme toujours les entités stables.

### 🔴 Coûts consentis
* **Boilerplate Initial Plus Élevé :** Créer une fonctionnalité demande d'écrire au moins 3 fichiers (Entity, Port/Use Case, Repository) là où un projet Rails basique ferait un simple appel `Model.create` dans le contrôleur.
* **Courbe d'Apprentissage :** Nécessite une rigueur architecturale de la part de l'équipe pour ne pas céder à la tentation des raccourcis ActiveRecord.

---

## 5. Notes d'implémentation

La configuration Zeitwerk du projet a été configurée dans `config/application.rb` pour charger nativement cette structure :
```ruby
# config/application.rb
config.eager_load_paths << Rails.root.join("app", "domain")
config.eager_load_paths << Rails.root.join("app", "infrastructure")
```

Illustration du découplage entre un Use Case qui orchestre la logique (sans connaître la BD) et son contrôleur Rails :

```ruby
# 1. LE USE CASE PUR RUBY (app/domain/use_cases/authenticate_user.rb)
module UseCases
  class AuthenticateUser
    def initialize(user_repo:)
      @user_repo = user_repo
    end

    def execute(contact:, password:)
      return OpenStruct.new(success?: false, errors: ["Contact et mot de passe requis"]) if contact.blank? || password.blank?

      user = @user_repo.find_by_contact(contact)
      if user && @user_repo.valid_password?(user, password)
        OpenStruct.new(success?: true, user: user)
      else
        OpenStruct.new(success?: false, errors: ["Contact ou mot de passe invalide"])
      end
    end
  end
end
```

# Blueprint: Port

Un Port est le **contrat** que le domaine impose au monde extérieur. Le Use Case dépend du Port ; l'Infrastructure l'implémente. C'est ce qui permet de tester le domaine sans base de données.

**Quand l'utiliser** : dès qu'un Use Case a besoin de lire ou d'écrire quelque chose qu'il ne détient pas (persistance, API tierce).

## Structure

```ruby
# app/domain/ports/catalog/course_repository_port.rb
# frozen_string_literal: true

# 🧠 DOMAINE · Ports::Catalog::CourseRepositoryPort
# Rôle : contrat de persistance des cours attendu par le domaine
# ADR  : 0001, 0014

module Ports
  module Catalog
    module CourseRepositoryPort
      def find_all(filters = {})
        raise NotImplementedError, "#{self.class} doit implémenter #find_all"
      end

      def find_by_slug(slug)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_slug"
      end

      def save(course_entity)
        raise NotImplementedError, "#{self.class} doit implémenter #save"
      end

      def delete(id)
        raise NotImplementedError, "#{self.class} doit implémenter #delete"
      end
    end
  end
end
```

Côté infrastructure, l'adaptateur **inclut** le port :

```ruby
# app/infrastructure/repositories/catalog/course_repository.rb
module Repositories
  module Catalog
    class CourseRepository
      include Ports::Catalog::CourseRepositoryPort
      # ...
    end
  end
end
```

## Règles

- Emplacement `app/domain/ports/<contexte>/`, suffixe **`Port`** : `Ports::Identity::SchoolRepositoryPort`.
- C'est un **`module`**, pas une `class`. Il est destiné à être `include`. (Les fichiers historiques de la racine qui déclarent une `class` sont du legacy.)
- Chaque méthode lève `NotImplementedError` avec un message nommant la méthode manquante.
- Signatures exprimées en vocabulaire du domaine : le port reçoit et retourne des **Entities**, jamais des `Orm::`, jamais des hashes de colonnes SQL.
- Un port par agrégat. `SchoolRepositoryPort` ne déclare pas les méthodes des classes.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| `class CourseRepositoryPort` | `module CourseRepositoryPort` — l'implémentation l'`include` |
| Le port déclare `save_course`, le repository implémente `save` (ou l'inverse) | Vérifier avec `grep "def save" app/infrastructure/repositories/<...>` avant d'écrire le Use Case : le contrat est **cassé aujourd'hui** sur `Repositories::Catalog::CourseRepository`, qui inclut un port déclarant `save`/`delete` mais expose `save_course`/`delete_course` |
| `raise NotImplementedError` nu | Ajouter le message : les tests de port assertent une levée par méthode |
| Faire dépendre le port d'un `Orm::` pour typer un argument | Nommer l'argument `course_entity`, sans type |
| Créer un port « fourre-tout » multi-agrégats | Un port par agrégat, dans son contexte |

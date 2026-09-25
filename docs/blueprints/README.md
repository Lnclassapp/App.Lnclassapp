# Blueprints

Patrons de code de Lnclass. Un blueprint dit **où** va un fichier, **à quoi il ressemble** et **ce qu'il n'a pas le droit de faire**. Avant d'écrire un fichier dans `app/` ou `test/`, ouvrir le blueprint de sa couche.

Les contrats de nommage, de branches et d'en-tête sont figés dans [`docs/guide/conventions.md`](../guide/conventions.md). En cas de contradiction, **conventions.md gagne**.

## Index

| Couche | Emplacement | Namespace | Blueprint |
|---|---|---|---|
| Entité | `app/domain/entities/<contexte>/` | `Entities::Catalog::Course` | [entity.md](entity.md) |
| DTO | `app/domain/dtos/` | `Dtos::CourseDto` | [dto.md](dto.md) |
| Port | `app/domain/ports/<contexte>/` | `Ports::Catalog::CourseRepositoryPort` | [port.md](port.md) |
| Use case | `app/domain/use_cases/<contexte>/` | `UseCases::Catalog::CreateCourse` | [use_case.md](use_case.md) |
| Policy | `app/domain/policies/<contexte>/` | `Policies::Classroom::TeachPolicy` | [policy.md](policy.md) |
| Repository | `app/infrastructure/repositories/<contexte>/` | `Repositories::Identity::SchoolRepository` | [repository.md](repository.md) |
| Query (lecture) | `app/infrastructure/queries/` | `Queries::ClassroomReportQuery` | [query.md](query.md) |
| Modèle ActiveRecord | `app/infrastructure/orm/` | `Orm::Course` | [orm_model.md](orm_model.md) |
| Contrôleur | `app/controllers/<contexte>/` | `Catalog::CoursesController` | [controller.md](controller.md) |
| Presenter | *(pas encore instancié)* | `…Presenter` | [presenter.md](presenter.md) |
| Objet de retour | `app/domain/shared/` | `Shared::Result` | [result.md](result.md) |
| Tests | `test/<couche>/…` | — | [test.md](test.md) |

## Les 3 règles transverses

### 1. Tout est namespacé par contexte borné

Contextes : `assessment`, `catalog`, `classroom`, `communication`, `identity`, `school`.

```ruby
app/domain/entities/catalog/course.rb   → Entities::Catalog::Course      ✅
app/domain/entities/course.rb           → Entities::Course               ❌ legacy à migrer
```

Un fichier posé à la racine de `entities/`, `repositories/` ou `ports/` est du **legacy**, pas un modèle à copier. ~13 entités et 5 repositories existent aujourd'hui aux deux endroits (voir `conventions.md` §8).

Le namespace ORM s'écrit **`Orm::`**, jamais `ORM::`.

### 2. En-tête HITL de 3 lignes

Tout fichier de `app/` porte exactement cet en-tête (bloquant en pre-commit) :

```ruby
# 🧠 DOMAINE · UseCases::Catalog::CreateCourse
# Rôle : crée un cours et le rattache à sa matière
# ADR  : 0001, 0014
```

| Emoji | Couche |
|---|---|
| 🧠 | `app/domain/**` |
| 🔌 | `app/infrastructure/**` |
| 🌐 | `app/controllers/**`, vues `.erb` |
| ⚡ | `app/javascript/**` |

Beaucoup de fichiers existants portent encore l'en-tête verbeux de la v1 (`# = Nom` / `🟢 COUCHE DOMAINE` / `📑 ADR ASSOCIÉ` / `👤 RÔLE HUMAN-IN-THE-LOOP`). **Ne pas le reproduire** dans du code neuf.

### 3. Zéro ActiveRecord dans le domaine

`app/domain/` ne référence ni `ActiveRecord`, ni `ApplicationRecord`, ni `Orm::`, ni `ActionController::Parameters`. Pas de `.find`, `.where`, `.save`, `.transaction`. Bloquant en pre-commit et en CI.

Tolérances explicitement accordées (ADR-0014) : `ActiveModel::Model`, `ActiveModel::Attributes` et `ActiveModel::Validations` dans les entités et les DTO.

Le domaine parle à la base **uniquement** à travers un Port, injecté par le constructeur.

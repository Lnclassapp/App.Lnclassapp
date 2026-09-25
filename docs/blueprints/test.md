# Blueprint: Tests

Minitest, `bin/rails test`. Un test se range **par couche testée**, pas par fonctionnalité. Le découpage ci-dessous est celui du dépôt.

| Couche | Répertoire | Base de données | Ce qu'on y teste | Volume actuel |
|---|---|---|---|---|
| Domaine | `test/domain/` | **non** | règles métier, validations d'entités, orchestration des use cases, policies, contrats de ports, DTO | 39 fichiers |
| Infrastructure | `test/infrastructure/` | oui | mapping `record ↔ entity`, filtres, persistance | 8 fichiers |
| ORM | `test/models/` | oui | associations, génération de `public_id`, instanciation | 3 fichiers |
| Delivery | `test/controllers/` | oui | statuts HTTP, redirections, gardes d'authentification | 8 fichiers |
| Parcours | `test/integration/` | oui | enchaînement de requêtes sur un parcours | 2 fichiers |
| Système | `test/system/` | — | **n'existe pas** (voir ci-dessous) | 0 |

---

## 1. Domaine — sans base de données

C'est le pattern le mieux établi du projet. Le port est remplacé par un **fake écrit à l'intérieur du fichier de test** (ADR-0015). Pas de gem de mock, pas de fixture, pas de SQL.

### Use case

```ruby
# test/domain/use_cases/catalog/create_course_test.rb
# frozen_string_literal: true
require "test_helper"

module UseCases
  module Catalog
    class CreateCourseTest < ActiveSupport::TestCase
      # Le fake inclut le port : si le contrat change, le test casse
      class MockCourseRepo
        include Ports::Catalog::CourseRepositoryPort

        attr_reader :last_saved

        def save(course_entity)
          @last_saved = course_entity
          true
        end
      end

      test "retourne une erreur si les attributs sont invalides" do
        repo = MockCourseRepo.new
        response = UseCases::Catalog::CreateCourse.new(course_repository: repo).call(attributes: {})

        assert_not response.success?
        assert_not_empty response.errors
        assert_nil repo.last_saved
      end

      test "sauvegarde le cours quand il est valide" do
        repo = MockCourseRepo.new
        level    = Entities::Catalog::Level.new(id: "1", name: "Tle", slug: "tle")
        material = Entities::Catalog::Material.new(id: "1", name: "Maths")

        response = UseCases::Catalog::CreateCourse.new(course_repository: repo).call(
          attributes: { name: "Nouveau Cours", slug: "nouveau-cours", level: level, material: material }
        )

        assert response.success?
        assert_empty response.errors
        assert_equal "Nouveau Cours", repo.last_saved.name
      end
    end
  end
end
```

**Comment on remplace un port** — deux variantes, toutes deux présentes dans le dépôt :

1. `include Ports::…Port` dans le fake (`MockCourseRepo`). **Préférée** : toute méthode oubliée lève `NotImplementedError` au lieu de renvoyer `nil`.
2. Fake nu, sans port (`FakeClassroomRepository` dans `test/domain/policies/`). Acceptable pour une dépendance à une seule méthode.

Le fake est déclaré **dans la classe de test**, jamais dans un fichier partagé.

### Entité

On teste les invariants et les messages, au mot près :

```ruby
# test/domain/entities/catalog/course_test.rb
test "exige un niveau" do
  course = Entities::Catalog::Course.new(name: "Test", slug: "test", level: nil, material: @material)

  assert_not course.valid?
  assert_includes course.errors[:level], "doit être fourni(e)"
end
```

### Port

Un test par port, qui vérifie que chaque méthode lève tant qu'elle n'est pas implémentée :

```ruby
# test/domain/ports/catalog/course_repository_port_test.rb
class DummyRepo
  include Ports::Catalog::CourseRepositoryPort
end

test "lève NotImplementedError pour toutes les méthodes de l'interface" do
  port = DummyRepo.new

  assert_raises(NotImplementedError) { port.find_all }
  assert_raises(NotImplementedError) { port.find_by_slug("slug") }
  assert_raises(NotImplementedError) { port.save(Entities::Catalog::Course.new) }
  assert_raises(NotImplementedError) { port.delete("1") }
end
```

### Policy et DTO

Policy → voir [policy.md](policy.md). DTO → un test de validité par champ obligatoire (`test/domain/dtos/`).

---

## 2. Infrastructure — le mapping, et rien d'autre

Ce qu'on vérifie : un record entre, une **entité** sort ; une entité entre, une ligne est écrite et l'entité récupère son `id` / `slug` / `public_id`.

```ruby
# test/infrastructure/repositories/identity/school_repository_test.rb
module Repositories
  module Identity
    class SchoolRepositoryTest < ActiveSupport::TestCase
      setup do
        @repo  = Repositories::Identity::SchoolRepository.new
        @drena = Orm::Drena.create!(name: "DRENA Test")
      end

      test "find_all retourne des entités du domaine" do
        Orm::School.create!(name: "École A", drena: @drena, schoolstatus: "active", schooltype: "public")

        schools = @repo.find_all
        assert_instance_of Entities::Identity::School, schools.first
      end

      test "save persiste et renseigne l'id dans l'entité" do
        school = Entities::Identity::School.new(
          name: "Nouvelle École", schoolstatus: "active", schooltype: "public",
          drena: Entities::Identity::Drena.new(id: @drena.id)
        )

        assert @repo.save(school)
        assert_not_nil school.id
      end
    end
  end
end
```

Ce qu'on **ne** teste **pas** ici : les règles métier (déjà couvertes sans base), et le rendu.

---

## 3. Delivery — contrôleurs et parcours

`ActionDispatch::IntegrationTest`. On teste le statut, la redirection et la garde d'authentification. Pas le contenu HTML.

Le helper d'authentification est défini une fois dans `test/test_helper.rb` :

```ruby
def sign_in_as(user, password: "password")
  post session_path, params: { contact: user.contact, password: password }
end
```

Il poste sur `session_path` avec le **contact téléphonique** (ADR-0002, pas d'email), et prend le mot de passe en mot-clé — à passer explicitement dès que ce n'est pas `"password"`.

```ruby
# test/controllers/courses_controller_test.rb
class CoursesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = Orm::User.create!(
      firstname: "Test", lastname: "User",
      fullname: "Test User #{SecureRandom.hex(3)}",
      contact: "07#{rand(10_000_000..99_999_999)}",
      role: :student, password: "password123"
    )
    @level    = Orm::Level.create!(name: "Tle D #{SecureRandom.hex(2)}")
    @material = Orm::Material.create!(name: "SVT #{SecureRandom.hex(2)}", shortname: "SVT", category: :science)
    @course   = Orm::Course.create!(
      name: "Génétique #{SecureRandom.hex(2)}", level: @level, material: @material,
      status: "publié", slug: "genetique-#{SecureRandom.hex(3)}"
    )
  end

  test "redirige un visiteur non authentifié" do
    get courses_path
    assert_response :redirect
    assert_redirected_to root_path
  end

  test "affiche l'index une fois authentifié" do
    sign_in_as(@user, password: "password123")
    get courses_path
    assert_response :success
  end
end
```

Le suffixe `SecureRandom.hex` n'est pas décoratif : `contact` et `name` portent des contraintes d'unicité, et il n'y a **pas de fixtures** pour éviter les collisions.

---

## 4. Ce qui manque (à dire franchement)

- **Pas de fixtures métier.** `test/fixtures/` ne contient que `action_text/rich_texts.yml` et un `files/.keep`. `test_helper.rb` charge les fixtures de façon conditionnelle (`fixtures :all if … fixture_paths.any?`), donc en pratique aucune donnée n'est préchargée : **chaque test construit ses données dans `setup` avec `Orm::…create!`**. Conséquence : des `setup` longs et dupliqués d'un fichier à l'autre. Tant qu'il n'y a pas de décision contraire, dupliquer plutôt qu'inventer un jeu de fixtures partiel.
- **Pas de tests système.** `test/system/` n'existe pas, aucun `ApplicationSystemTestCase` n'est défini, alors que `capybara` et `selenium-webdriver` sont déjà dans le `Gemfile` (groupe de test) et que `conventions.md` §7 affirme que « les parcours critiques passent en test système » **bloque en CI**. Cette ligne est aujourd'hui fausse : rien ne bloque. Le plus proche est `test/integration/` (2 fichiers, requêtes HTTP sans navigateur).
- **Pas de couverture mesurée.** `conventions.md` §7 la dit « mesurée mais non bloquante » ; aucun outil de couverture n'est installé.

Ne pas écrire dans un plan de lot qu'un test système couvre un parcours tant que `test/system/` n'existe pas.

---

## Règles

- Le fichier de test miroite le chemin du fichier testé : `app/domain/use_cases/catalog/create_course.rb` → `test/domain/use_cases/catalog/create_course_test.rb`.
- Même namespace de module que la classe testée, pour que les constantes se résolvent sans préfixe.
- Noms de tests **en français**, descriptifs du comportement : `test "exige un niveau"`, pas `test "validation"`.
- Un test de domaine qui touche la base est un bug de conception : injecter un fake.
- Chaque lot déclare son `Test associé` dans `plan.md` (`conventions.md` §6). Un lot sans test associé ne se ferme pas.
- `bin/rails test` avant de pousser ; les tests concernés bloquent en pre-commit et en CI.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| Créer un `Orm::…` dans un test de `test/domain/` | Fake en mémoire injecté par le constructeur |
| Fake nu qui renvoie `nil` sur une méthode oubliée | `include Ports::…Port` dans le fake |
| Mettre les fakes dans un helper partagé | Les déclarer dans la classe de test (ADR-0015) |
| Ajouter des fixtures pour un seul test | Construire les données dans `setup` — il n'y a pas de socle de fixtures |
| `Orm::User.create!(contact: "0700000000")` en dur | Randomiser : `"07#{rand(10_000_000..99_999_999)}"` (unicité) |
| `sign_in_as(@user)` alors que le mot de passe est `"password123"` | `sign_in_as(@user, password: "password123")` |
| Tester les 50 permutations d'une règle d'accès depuis le use case | Test unitaire de la [Policy](policy.md) |
| Asserter du HTML dans un test de contrôleur | Statut, redirection, garde ; le reste relève d'un test système — qui n'existe pas encore |

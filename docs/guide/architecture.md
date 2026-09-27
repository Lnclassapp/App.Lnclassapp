# L'architecture de Lnclass

> Ce fichier explique l'hexagonale **sur ce code-ci**. Tous les chemins cités existent : ouvre-les en lisant.
> Les contrats de nommage sont gelés dans [`conventions.md`](conventions.md). Ici on explique le *pourquoi* et le *comment tracer*.

---

## 1. Les quatre couches et le sens des dépendances

```
                    ┌─────────────────────────────────────────────┐
   HTTP / Turbo ───►│  DELIVERY   app/controllers/ · app/views/   │
                    │             app/javascript/ · app/helpers/  │
                    └──────────────────┬──────────────────────────┘
                                       │ dépend de
                    ┌──────────────────▼──────────────────────────┐
                    │  DOMAINE    app/domain/                     │
                    │   entities/ · use_cases/ · ports/           │
                    │   dtos/ · policies/ · strategies/           │
                    │   ← Ruby pur. Ne dépend de RIEN.            │
                    └──────────────────▲──────────────────────────┘
                                       │ implémente les ports
                    ┌──────────────────┴──────────────────────────┐
   PostgreSQL ◄─────│  INFRASTRUCTURE  app/infrastructure/        │
                    │   repositories/ · orm/ · queries/           │
                    └─────────────────────────────────────────────┘
```

**Une seule règle de dépendance : tout pointe vers le domaine, le domaine ne pointe vers personne.**

L'infrastructure dépend du domaine (elle `include` ses ports). La delivery dépend du domaine (elle instancie ses use cases) et de l'infrastructure (elle injecte les repositories). Le domaine, lui, ne connaît ni ActiveRecord, ni `request`, ni `params`, ni `session`.

Ce n'est pas une consigne morale : `app/domain/` ne peut pas référencer `ActiveRecord`, `ApplicationRecord` ni `Orm::` — le pre-commit et la CI refusent le commit. Voir [`conventions.md` §7](conventions.md#7-ce-qui-bloque).

### Ce qu'il y a réellement dans chaque dossier

| Dossier | Fichiers | Rôle |
|---|---|---|
| `app/domain/entities/` | 37 | Objets métier purs (`include ActiveModel::Model`), porteurs des règles |
| `app/domain/use_cases/` | 47 | Orchestration d'une action métier, une classe = une action |
| `app/domain/ports/` | 31 | Interfaces (`module` + `raise NotImplementedError`) que l'infra doit remplir |
| `app/domain/dtos/` | 12 | Bouclier anti-corruption : valide les params bruts avant la frontière (ADR-0013) |
| `app/domain/policies/` | 1 | `Policies::ClassroomAccessPolicy` — autorisation métier hors contrôleur |
| `app/domain/strategies/` | 3 | Import polymorphe de données catalogue (ADR-0012) |
| `app/infrastructure/repositories/` | 26 | Adaptateurs : implémentent un port, traduisent Record ⇄ Entité |
| `app/infrastructure/orm/` | 27 | Modèles ActiveRecord anémiques : tables, associations, scopes, validations SQL |
| `app/infrastructure/queries/` | 17 | Lecture pure, court-circuite le domaine (CQRS léger, ADR-0006) |
| `app/controllers/` | 52 | Traduit HTTP → use case ou query, décide du rendu. Zéro métier. |

⚠️ `app/presenters/` et `app/domain/validators/` sont documentés dans des docs historiques mais **n'existent pas**. Ne les crée pas « pour être conforme ».

---

## 2. Un parcours tracé de bout en bout

Cas réel : **un élève démarre une session d'exercice, répond à une question, obtient un badge.**

### 2.1 La requête arrive

`config/routes.rb` (l. 42-47) :

```ruby
resources :exercises, shallow: true, controller: "/assessment/exercises" do
  resources :exercise_sessions, only: [ :create ], controller: "/assessment/exercise_sessions"
end
```

`POST /exercises/:exercise_id/exercise_sessions` → `Assessment::ExerciseSessionsController#create`.

### 2.2 Le contrôleur — `app/controllers/assessment/exercise_sessions_controller.rb`

```ruby
def create
  use_case = UseCases::Assessment::StartExerciseSession.new(
    execution_repo: Repositories::Assessment::ExerciseExecutionRepository.new
  )
  result = use_case.execute(student_id: current_student.id, exercise_id: @exercise.id)

  if result.success?
    redirect_to exercise_session_path(result.session.id)
  else
    redirect_to exercise_path(@exercise), alert: result.errors.join(", ")
  end
end
```

Trois choses, et **seulement** ces trois choses :
1. il **injecte** l'implémentation concrète du port dans le use case (c'est ici, et nulle part ailleurs, que le choix de l'adaptateur se fait) ;
2. il traduit la requête HTTP en arguments de méthode ;
3. il décide du rendu (`redirect_to`, `render`, `turbo_stream`).

Il ne calcule rien. Aucun `if` métier, aucun `Orm::` , aucun `.where`.

### 2.3 Le use case — `app/domain/use_cases/assessment/start_exercise_session.rb`

```ruby
def execute(student_id:, exercise_id:)
  @execution_repo.mark_previous_sessions_abandoned(student_id, exercise_id)

  session_entity = Entities::Assessment::ExerciseSession.new(
    student_id: student_id, exercise_id: exercise_id
  )
  session_entity.start!

  saved_session = @execution_repo.save_session(session_entity)
  saved_session ? OpenStruct.new(success?: true, session: saved_session)
                : OpenStruct.new(success?: false, errors: [ "Impossible de démarrer la session" ])
end
```

Le use case **orchestre** : il séquence des appels au port et à l'entité. Il ne connaît que `@execution_repo`, injecté au constructeur — c'est-à-dire, de son point de vue, un objet qui répond au contrat du port. Il pourrait tout aussi bien recevoir un double de test en mémoire ; c'est précisément le but.

### 2.4 Le port — `app/domain/ports/assessment/exercise_execution_repository_port.rb`

```ruby
module Ports
  module Assessment
    module ExerciseExecutionRepositoryPort
      def save_session(session_entity) = raise NotImplementedError
      def mark_previous_sessions_abandoned(student_id, exercise_id) = raise NotImplementedError
      def get_correct_answers_for_questions(question_ids) = raise NotImplementedError
      # …
    end
  end
end
```

Le port est **la frontière**. C'est un module Ruby dont chaque méthode lève `NotImplementedError`. Il est écrit en premier (le Lot 0 d'un chantier gèle les ports, cf. [`../workflows/README.md`](../workflows/README.md#phase-3--planifier)) et les lots verticaux l'implémentent sans le redéfinir.

### 2.5 Le repository — `app/infrastructure/repositories/assessment/exercise_execution_repository.rb`

```ruby
module Repositories
  module Assessment
    class ExerciseExecutionRepository
      include Ports::Assessment::ExerciseExecutionRepositoryPort

      def save_session(session_entity)
        record = session_entity.id ? Orm::ExerciseSession.find(session_entity.id) : Orm::ExerciseSession.new
        record.assign_attributes(
          student_id: session_entity.student_id,
          exercise_id: session_entity.exercise_id,
          status: session_entity.status,
          percentage: session_entity.percentage,
          # …
        )
        Orm::ExerciseSession.transaction do
          if record.save
            session_entity.id = record.id
            # … persistance des tentatives associées …
            map_session_to_entity(record)   # ← on ressort une ENTITÉ, jamais le record
          else
            record.errors.each { |e| session_entity.errors.add(e.attribute, e.message) }
            raise ActiveRecord::Rollback
          end
        end || false
      end
```

Le repository fait **trois** choses : il `include` le port, il parle à l'ORM, et il **remappe le record en entité** (`map_session_to_entity`, l. 131). Ce mapping n'est pas une formalité : c'est lui qui empêche un `Orm::ExerciseSession` de fuir dans le domaine.

### 2.6 L'ORM — `app/infrastructure/orm/exercise_session.rb`

`Orm::` = la table SQL et rien d'autre : `self.table_name`, `belongs_to`/`has_many`, `scope`, validations de persistance. Zéro règle métier (ADR-0005, ADR-0021).

### 2.7 Le retour, et où vit vraiment la règle métier

> ⚠️ **Le barème et le moteur ci-dessous sont ceux de l'ancien dépôt.** Depuis le 2026-09-25, le projet cible suit l'[ADR-0033](../decisions/adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) et l'[ADR-0054](../decisions/adr/0054-moteur-d-evaluation-soumission-et-cloture.md) :
> - quatre badges, Bronze ≥ 50 %, Argent ≥ 70 %, Or ≥ 80 %, Diamant = 100 % (sans faute), avec des seuils nommés (`PASS_THRESHOLD`, `MASTERY_THRESHOLD`, `GOLD_THRESHOLD`, `PERFECT_THRESHOLD`) dans `Entities::Assessment::Grading` ; « or à 100 % » n'est pas une règle ;
> - la soumission corrige par identifiants et crée une tentative unique et immuable ; **seul** `Assessment::CloseExerciseSession` pose le score, décide du badge et de la lacune ;
> - les use cases renvoient un `Shared::Result`, jamais un `OpenStruct` ([ADR-0026](../decisions/adr/0026-contrat-result-entites-et-dto.md)).
>
> La leçon de cette section reste valable : la règle vit dans le domaine, pas dans le contrôleur.

Dans l'ancien dépôt, la règle « 100 % → or, ≥ 80 % → argent, ≥ 50 % → bronze » n'est ni dans le contrôleur, ni dans le repository, ni dans l'ORM. Elle est dans l'entité — `app/domain/entities/assessment/exercise_badge.rb` :

```ruby
def self.determine_level(percentage)
  return nil unless percentage.is_a?(Numeric)
  if    percentage >= 100 then LEVELS[:gold]
  elsif percentage >= 80  then LEVELS[:silver]
  elsif percentage >= 50  then LEVELS[:bronze]
  end
end
```

De même le calcul de score et l'état de la session vivent dans `app/domain/entities/assessment/exercise_session.rb` (`start!`, `submit_attempt!`, `calculate_score`, `success?` = `percentage >= 50`).

`app/domain/use_cases/assessment/submit_question_attempt.rb` montre l'orchestration complète, et c'est le meilleur exemple du dépôt :

```ruby
session = @execution_repo.find_session_by_slug(session_id) || @execution_repo.find_session_by_id(session_id)
return OpenStruct.new(success?: false, errors: [ "Session introuvable" ]) unless session
return OpenStruct.new(success?: false, errors: [ "Session terminée" ]) if session.completed?

correct_answers_map = @execution_repo.get_correct_answers_for_questions([ question_id ])
expected_value      = (correct_answers_map[question_id.to_i] || []).map(&:id).map(&:to_s)

attempt         = session.submit_attempt!(question_id, provided_answer, expected_value, total_questions)
updated_session = @execution_repo.save_session(session)

if updated_session.completed?
  existing_badge  = @execution_repo.find_badge(updated_session.student_id, updated_session.exercise_id)
  new_badge_level = Entities::Assessment::ExerciseBadge.upgrade_if_better(updated_session.percentage.to_i, existing_badge)
  @execution_repo.save_badge(...) if new_badge_level
end
```

Lis-le comme une phrase : *charger, refuser si terminée, demander la bonne réponse, laisser l'entité corriger, persister, et si c'est fini attribuer le badge*. Aucune ligne de SQL. C'est ça, la réussite de l'hexagonale.

### 2.8 Le trajet en une ligne

```
POST /exercises/:id/exercise_sessions
  → Assessment::ExerciseSessionsController#create      app/controllers/assessment/
  → UseCases::Assessment::StartExerciseSession         app/domain/use_cases/assessment/
  → Entities::Assessment::ExerciseSession#start!       app/domain/entities/assessment/
  → Ports::Assessment::ExerciseExecutionRepositoryPort app/domain/ports/assessment/
  → Repositories::Assessment::ExerciseExecutionRepository  app/infrastructure/repositories/assessment/
  → Orm::ExerciseSession                               app/infrastructure/orm/
  ← map_session_to_entity → Entities::Assessment::ExerciseSession
  ← OpenStruct(success?:, session:)
  ← redirect_to exercise_session_path
```

---

## 3. Pourquoi cette architecture ici

### Ce qu'elle protège

| Elle protège | Concrètement sur Lnclass |
|---|---|
| **Les règles d'évaluation** | Le barème des badges, le calcul de progression, la détection des lacunes se testent sans base de données. `test/domain/` tourne en millisecondes. |
| **La durée de vie du métier** | Rails 8 remplacera Rails 7, Propshaft a remplacé Sprockets, Redux a été supprimé (ADR-0013). `app/domain/` n'a bougé à aucun de ces changements. |
| **Le travail des agents** | ~97 % du code est écrit par des agents. Une frontière explicite (le port) est un contrat qu'un agent peut respecter sans lire tout le dépôt. Un `before_save` implicite dans un modèle, non. |
| **Le parallélisme** | Le graphe de lots ne fonctionne que parce que les couches sont des fichiers disjoints. Sans hexagonale, deux lots se battent pour le même modèle ActiveRecord. |

### Ce qu'elle coûte — dis-le franchement

- **Du mapping.** Chaque repository écrit deux fois les attributs : `assign_attributes` à l'aller, `map_*_to_entity` au retour. `app/infrastructure/repositories/catalog/course_repository.rb` fait 9,9 Ko, dont une bonne moitié est du mapping.
- **De l'indirection.** Pour suivre une donnée il faut ouvrir 5 fichiers. Le §2.8 ci-dessus existe pour ça.
- **De la duplication apparente.** `Entities::Catalog::Course`, `Dtos::CourseDto` et `Orm::Course` portent des attributs qui se ressemblent. Ils ne servent pas la même chose : validation métier, validation de frontière, schéma SQL.
- **Un risque de dérive silencieuse.** Un port peut déclarer `save` pendant que le repository implémente `save_course` : rien ne casse à la compilation. Voir §7.

Le contrepoids : on **n'applique pas** ce coût à la lecture. C'est l'objet de la section suivante.

---

## 4. Lecture vs écriture : le CQRS léger

ADR-0006 et ADR-0012 tranchent : **le cycle de lecture ne traverse pas le domaine.**

Hydrater 500 élèves, 10 000 sessions et 100 000 tentatives en entités Ruby pour afficher un tableau de bord fait exploser la RAM et sature le GC. Donc les 17 fichiers de `app/infrastructure/queries/` attaquent l'ORM directement et renvoient ce que la vue consomme.

`app/infrastructure/queries/student_feed_query.rb` :

```ruby
module Queries
  class StudentFeedQuery
    def get_classroom_materials(classroom_id)
      Orm::Material.joins(courses: :classroom_courses)
                   .where(classroom_courses: { classroom_id: classroom_id })
                   .distinct.order(:name)
    end
```

Pas d'entité, pas de port, pas de use case. Assumé.

### Quand Query, quand Use Case

| Question à te poser | Réponse | Ce que tu écris |
|---|---|---|
| Est-ce que ça **change** un état persistant ? | oui | Use Case + Port + Repository |
| Est-ce qu'une **règle métier** décide du résultat (barème, autorisation, transition d'état) ? | oui | Use Case (même en lecture : la règle appartient au domaine) |
| Est-ce que je remplis un **écran de liste, de feed, de dashboard ou de rapport** ? | oui | Query, appelée directement par le contrôleur |
| Est-ce que j'ai besoin d'agrégats SQL (`COUNT`, `AVG`, `GROUP BY`) ? | oui | Query, **obligatoirement** — jamais de `group_by` Ruby sur un gros volume |
| Est-ce que je fais un simple `find` avant d'écrire ? | oui | Repository, via le port, dans le use case |

Un cas mixte existe et il est légitime : `app/controllers/students/feed_controller.rb` appelle `UseCases::Identity::GetStudentFeed` **en lui injectant la Query** :

```ruby
use_case = UseCases::Identity::GetStudentFeed.new(
  student_repo: Repositories::Identity::StudentRepository.new,
  feed_query:   Queries::StudentFeedQuery.new
)
```

Le use case existe parce qu'il y a une règle (« pas de profil élève → redirige vers la complétion de profil »), pas parce qu'il faut un use case.

**L'interdit :** une Query ne doit jamais écrire. Si tu vois un `.save`, un `.update` ou un `.destroy` dans `app/infrastructure/queries/`, c'est un bug d'architecture.

---

## 5. Les six contextes bornés

Chaque couche est namespacée par contexte. Les six, et rien d'autre. Le découpage fait autorité depuis l'[ADR-0027](../decisions/adr/0027-contextes-bornes-et-arborescence.md) (2026-09-25), qui fixe aussi la table → contexte :

| Contexte | Ce qu'il possède | Points d'entrée dans l'ancien dépôt |
|---|---|---|
| **assessment** | Exercices, questions, propositions, sessions, tentatives, badges, lacunes | `app/controllers/assessment/`, `app/domain/use_cases/assessment/` (14 use cases) |
| **catalog** | Niveaux, séries, `level_series`, matières, cours, fiches essentielles, rapports d'import | `app/controllers/catalog/`, `app/domain/use_cases/catalog/` |
| **classroom** | Classes, adhésions, enseignement (`teacher_classrooms`), assignations polymorphes | `app/controllers/classroom/`, `app/domain/use_cases/classroom/` |
| **communication** | Annonces diffusées par audience, rejets | `app/controllers/messages_controller.rb`, `app/domain/use_cases/communication/` |
| **identity** | Comptes, profils, authentification, sessions, invitations, journal d'audit | `app/controllers/identity/`, `app/domain/use_cases/identity/` |
| **school** | **DRENA**, établissements, personnel de direction, rattachement des enseignants (`teacher_schools`) | `app/domain/use_cases/school/`, `app/domain/dtos/school/` |

Dans l'ancien dépôt, la DRENA vivait dans `catalog`, les sujets d'examen dans `assessment` et les élèves de démo dans `classroom` : la DRENA passe dans `school`, les deux autres sont retirés du plan.

Le contexte est aussi le **scope de commit** (`feat(assessment): …`) et l'unité de découpage d'un chantier.

Deux nuances à connaître avant de te fier au namespace :

- **`school` n'a pas de dossier de ports ni de repositories à lui.** Ses ports vivent dans `app/domain/ports/school_*.rb` (racine) et ses repositories dans `app/infrastructure/repositories/school_*.rb`. Ses contrôleurs sont répartis entre `app/controllers/catalog/schools_controller.rb`, `app/controllers/schoolstaff/` et `app/controllers/school_admins/`.
- **Les 17 Queries de l'ancien dépôt ne sont pas namespacées par contexte** : elles sont toutes à plat dans `Queries::`. Le projet cible les range dans `Queries::<Contexte>::…Query` ; une query peut toujours joindre des tables de plusieurs contextes ([ADR-0027](../decisions/adr/0027-contextes-bornes-et-arborescence.md)).

Un fichier à la racine de `entities/`, `ports/` ou `repositories/` est du **legacy à migrer** (≈13 entités et 5 repositories sont dupliqués racine + contexte, cf. [`conventions.md` §8](conventions.md#8-écarts-connus-entre-la-doc-et-le-code)). Ne prends jamais un fichier racine comme modèle.

---

## 6. Les erreurs classiques

### ❌ Logique métier dans le contrôleur

```ruby
# ❌ dans un contrôleur
if session.question_attempts.count >= exercise.questions.count
  session.update(status: "completed", percentage: (correct / total.to_f * 100).round)
  ExerciseBadge.create(level: percentage >= 80 ? "silver" : "bronze")
end
```

Trois règles métier (fin de session, calcul du pourcentage, barème du badge) enterrées dans une couche qu'on ne teste qu'avec une requête HTTP. Le jour où l'API mobile fait la même chose, la règle est réécrite — différemment.

```ruby
# ✅
result = UseCases::Assessment::SubmitQuestionAttempt.new(
  execution_repo: Repositories::Assessment::ExerciseExecutionRepository.new
).execute(session_id:, question_id:, provided_answer:, total_questions:)
```

**Le test :** si tu ne peux pas décrire ce que fait ton action sans dire « et ensuite on met à jour la colonne… », la règle est au mauvais endroit. Si la même règle doit valoir pour le web, l'API et un job, elle est dans le domaine.

### ❌ ActiveRecord dans le domaine

```ruby
# ❌ dans app/domain/use_cases/…
def execute(classroom_id:)
  students = Orm::Student.where(classroom_id: classroom_id)   # bloqué au pre-commit
```

Le domaine ne connaît que des ports. S'il te manque une donnée, **ajoute une méthode au port** et implémente-la dans le repository. N'ajoute jamais un `require` ou un `Orm::` dans `app/domain/`.

Cas limite fréquent : « j'ai juste besoin d'un `count` ». Deux issues légitimes — une méthode de port (`#count_students_in(classroom_id)`) si le use case en a besoin pour décider, ou une **Query** si c'est pour afficher. Jamais `Orm::` dans le domaine.

### ❌ Repository qui retourne un objet ORM

```ruby
# ❌
def find_session_by_id(id)
  Orm::ExerciseSession.find_by(id: id)     # un record fuit dans le domaine
end
```

Ça « marche » — jusqu'à ce qu'un use case appelle `.update`, `.reload` ou `.classroom.students` sur le retour. À partir de là le domaine dépend d'ActiveRecord sans qu'aucun garde-fou ne le voie, parce que le mot `Orm::` n'apparaît pas dans `app/domain/`.

```ruby
# ✅
def find_session_by_id(id)
  record = Orm::ExerciseSession.find_by(id: id)
  map_session_to_entity(record) if record
end
```

**Un repository retourne toujours : une entité, un tableau d'entités, `nil`, ou un booléen.** Jamais un `ActiveRecord::Relation`, jamais un record.

### ❌ Les trois autres, plus rares mais coûteuses

| Erreur | Pourquoi c'est grave | Le réflexe |
|---|---|---|
| Passer `params` (ou `params.to_h`) directement à un use case | La frontière n'est plus validée : le domaine encaisse n'importe quelle clé venue du web (ADR-0013) | Construire un `Dtos::…`, vérifier `dto.invalid?`, passer `dto` |
| Mettre un `before_save` métier dans `Orm::` | La règle s'exécute même dans les seeds, les imports et les tests, et personne ne la voit (ADR-0021) | La règle va dans l'entité, l'ORM reste anémique |
| Écrire une Query qui persiste | Casse la séparation lecture/écriture et contourne toute validation métier (ADR-0006) | Si ça écrit, c'est un use case |

---

## 7. Écarts connus entre cette architecture et le code

La liste de référence est dans [`conventions.md` §8](conventions.md#8-écarts-connus-entre-la-doc-et-le-code). Ce qui suit la complète, côté architecture. **Ne corrige pas ça en passant** : ouvre un chantier.

| Écart | Où | Conséquence |
|---|---|---|
| Ports et repositories désalignés | `Ports::Catalog::CourseRepositoryPort` déclare `find_all/find_by_slug/save/delete` ; `Repositories::Catalog::CourseRepository` implémente `find_course_by_slug/save_course/delete_course` | Les méthodes du port restent celles qui lèvent `NotImplementedError`. `UseCases::Catalog::CreateCourse#call` appelle `@course_repository.save(course)` et lèverait donc `NotImplementedError` avec ce repository. |
| Use case orphelin | `app/domain/use_cases/catalog/create_course.rb` n'est appelé par aucun contrôleur ; `Catalog::CoursesController#create` passe par `UseCases::Catalog::ManageResource` (ADR-0012) | Ne prends pas `CreateCourse` comme modèle du chemin de création réel. |
| Contrat de retour non figé | 29 `execute` contre 10 `call`, et 166 usages d'`OpenStruct`. `docs/blueprints/result.md` décrit un `Shared::Result` inexistant | Suis l'existant du contexte que tu touches, et ne crée pas un troisième style. |
| `ViewObjects` | ADR-0012 §4.1 les décide ; aucun dossier `view_objects/` n'existe | Les Queries renvoient des Hash / relations, pas des objets typés. |
| `Orm::ClassroomExercise` | Référencé dans `app/infrastructure/queries/student_feed_query.rb` et `app/controllers/teachers/classroom_exercises_controller.rb` ; la classe et la table n'existent pas (remplacées par `classroom_assignments`, ADR-0007) | Ces deux chemins de code lèvent `NameError` s'ils sont exécutés. Bug latent. |
| ORM dans un contrôleur | `MessagesController#index` requête `Orm::Message` directement, et fabrique des données de démo en `Rails.env.development?` | C'est l'anti-pattern du §6 dans le code réel. Ne le recopie pas. |

---

## 8. Où aller ensuite

| Tu veux | Ouvre |
|---|---|
| Écrire un fichier d'une couche donnée | [`../blueprints/`](../blueprints/) — un patron par couche |
| Connaître la règle de nommage exacte | [`conventions.md`](conventions.md) |
| Savoir dans quel ordre coder | [`../workflows/README.md`](../workflows/README.md#phase-4--exécuter) |
| Comprendre pourquoi un choix a été fait | [`../decisions/adr/`](../decisions/adr/) — en particulier 0001, 0006, 0012, 0013, 0021 |
| Parler le bon vocabulaire | [`glossaire.md`](glossaire.md) |

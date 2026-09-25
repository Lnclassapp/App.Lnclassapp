# Blueprint: Query (côté lecture)

Une Query est le **côté lecture du CQRS** (ADR-0006, ADR-0012). Elle sert un écran : elle interroge l'ORM en une passe, agrège, et retourne des structures d'affichage. Elle **court-circuite volontairement** les entités et les repositories.

**Quand l'utiliser** : `index`, `show`, tableau de bord, rapport, feed — tout ce qui ne modifie rien. Dès qu'il y a écriture, c'est un [Use Case](use_case.md).

## Structure

```ruby
# app/infrastructure/queries/classroom_report_query.rb
# frozen_string_literal: true

# 🔌 INFRA · Queries::ClassroomReportQuery
# Rôle : agrège les résultats d'un exercice pour une classe (lecture seule)
# ADR  : 0001, 0006

module Queries
  class ClassroomReportQuery
    def get_exercise_stats(classroom_id, exercise_id)
      Rails.cache.fetch("classroom_report_stats:#{classroom_id}:#{exercise_id}", expires_in: 1.hour) do
        students   = Orm::Classroom.find(classroom_id).students.ordered
        student_ids = students.map(&:id)

        # 1. Une requête par table, jamais une requête par élève
        sessions_by_student = Orm::ExerciseSession
          .where(student_id: student_ids, exercise_id: exercise_id)
          .completed
          .order(completed_at: :desc)
          .group_by(&:student_id)

        badges_by_student = Orm::ExerciseBadge
          .where(student_id: student_ids, exercise_id: exercise_id)
          .index_by(&:student_id)

        # 2. Agrégation en mémoire
        results = students.map do |student|
          sessions = sessions_by_student[student.id] || []
          {
            student:    student,
            sessions:   sessions,
            best_score: sessions.map(&:percentage).max,
            attempts:   sessions.size,
            badge:      badges_by_student[student.id]
          }
        end

        all_sessions = results.flat_map { |r| r[:sessions] }
        stats = {
          total_students:  students.size,
          completed_count: results.count { |r| r[:sessions].any? },
          completion_rate: students.any? ? ((results.count { |r| r[:sessions].any? }.to_f / students.size) * 100).round : 0,
          average_score:   all_sessions.any? ? (all_sessions.sum(&:percentage).to_f / all_sessions.size).round : 0,
          total_attempts:  all_sessions.size
        }

        # 3. Retour : structure d'affichage prête pour la vue
        { students: students, results: results, stats: stats }
      end
    end
  end
end
```

Consommation par le contrôleur :

```ruby
def report
  @report = Queries::ClassroomReportQuery.new.get_exercise_stats(params[:classroom_id], params[:exercise_id])
end
```

## Règles

- Emplacement `app/infrastructure/queries/` (pas de sous-dossier par contexte aujourd'hui), namespace **`Queries::`**, suffixe `Query`.
- **Lecture seule.** Aucun `save`, `create!`, `update`, `destroy` dans une Query.
- Les méthodes publiques sont nommées par l'écran servi : `get_exercise_stats`, `get_course_details`, `get_catalog`. Une Query peut en exposer plusieurs (`Queries::CatalogQuery`).
- Retour : un `Hash` de clés d'affichage, ou un `OpenStruct` (forme historique très présente, ex. `Queries::CatalogQuery#get_catalog`). Le retour peut contenir des `Orm::` — c'est assumé côté lecture, le domaine n'est pas concerné.
- Anti-N+1 obligatoire : `includes`, `group_by`, `index_by`, `pluck`. Une boucle qui requête est un bug, pas un détail de perf.
- `Rails.cache.fetch` avec une clé incluant **tous** les identifiants du calcul, et un `expires_in` explicite, pour les rapports coûteux.
- Retourner `nil` quand la ressource n'existe pas ; c'est le contrôleur qui redirige.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| Faire passer une lecture d'index par un Use Case + Repository | `Queries::…Query` directement depuis le contrôleur |
| `students.each { |s| Orm::ExerciseSession.where(student_id: s.id) }` | Une requête `where(student_id: student_ids)` + `group_by(&:student_id)` |
| Écrire (`update_column`, `touch`) depuis une Query | La Query ne modifie rien |
| Clé de cache incomplète (`"report:#{classroom_id}"`) | Inclure tous les paramètres : `"report:#{classroom_id}:#{exercise_id}"` |
| Instancier des `Entities::` dans une Query | Retourner des records / hashes ; l'hydratation d'entités est le travail du Repository |
| Nommer la classe `ClassroomReportService` | Suffixe `Query`, namespace `Queries::` |

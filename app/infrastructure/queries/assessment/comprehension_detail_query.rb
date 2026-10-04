# 🔌 INFRA · Queries::Assessment::ComprehensionDetailQuery
# Rôle : section « Compréhension » du suivi : catégories, signes, taux par question et élèves d'une catégorie (UDR-0072 §3.5)
# ADR  : 0026, 0072, 0079 · appelée après FollowAssignmentPolicy seulement : elle nomme des élèves ; requêtes en nombre constant
module Queries
  module Assessment
    class ComprehensionDetailQuery
      Comprehension = Entities::Assessment::Comprehension

      # category : la dominante si lisible, sinon nil ; selected : la catégorie dont on lit les questions et les élèves.
      Detail = Data.define(:done, :present, :category, :readable, :category_counts, :trend_counts, :selected, :questions, :students)
      # rate, first_rate : pourcentages arrondis, nil sans tentative ; first_rate nil aussi sans élève à deux sessions.
      QuestionRate = Data.define(:number, :content, :rate, :first_rate, :to_revisit)
      StudentRow = Data.define(:display_name, :best, :trend)

      # « Sans évolution » regroupe stable et stagne ; les élèves sans signe n'entrent pas dans la synthèse (ADR-0079 §4.3).
      TREND_GROUPS = { progress: :progress, stable: :flat, stagnant: :flat, decline: :decline }.freeze

      # category : un symbole de Comprehension::CATEGORIES, ou n'importe quoi d'autre (ignoré).
      # → Detail | nil (assignation inconnue, archivée ou d'une autre classe)
      def call(classroom_public_id:, assignment_public_id:, category:)
        classroom_id, id, exercise_id =
          Orm::ClassroomAssignment.joins(:classroom)
                                  .where(public_id: assignment_public_id, status: "active", assignable_type: "Exercise",
                                         classrooms: { public_id: classroom_public_id })
                                  .pick(:classroom_id, :id, :assignable_id)
        return if id.nil?

        scores = AssignmentScores.for(classroom_id:, assignment_ids: [ id ]).fetch(id, [])
        detail(scores, Queries::Classroom::AssignmentFollowUpQuery.present_students(classroom_id).count, exercise_id, category)
      end

      private

      def detail(scores, present, exercise_id, category)
        category_counts = Comprehension::CATEGORIES.index_with { 0 }.merge(scores.map { category_of(it) }.tally)
        dominant = Comprehension.dominant(category_counts)
        readable = Comprehension.readable?(scores.size)
        selected = Comprehension::CATEGORIES.include?(category) ? category : dominant || :struggling
        members = scores.select { category_of(it) == selected }
        Detail.new(done: scores.size, present:, category: (dominant if readable), readable:, category_counts:,
                   trend_counts: trend_counts(scores), selected:, questions: questions(exercise_id, members), students: students(members))
      end

      def category_of(student_scores) = Comprehension.category_for(student_scores.scores.max)

      def trend_counts(scores)
        { progress: 0, flat: 0, decline: 0 }.merge(scores.filter_map { TREND_GROUPS[Comprehension.trend_for(it.scores)] }.tally)
      end

      # Une requête pour les questions, une pour les tentatives des meilleures et des premières sessions de la catégorie.
      def questions(exercise_id, members)
        best_ids = members.map(&:best_session_id)
        first_ids = members.any? { it.scores.size > 1 } ? members.map(&:first_session_id) : []
        attempts = Orm::QuestionAttempt.where(exercise_session_id: best_ids | first_ids)
                                       .pluck(:exercise_session_id, :question_id, :correct).group_by(&:second)
        Orm::Question.where(exercise_id:).order(:position).pluck(:id, :content).each_with_index.map do |(question_id, content), index|
          question_attempts = attempts.fetch(question_id, [])
          rate = rate(question_attempts, best_ids)
          QuestionRate.new(number: index + 1, content:, rate:, first_rate: rate(question_attempts, first_ids),
                           to_revisit: Comprehension.to_revisit?(rate))
        end
      end

      # Une tentative au plus par session et par question (index unique) : le taux ne dépasse jamais 100 % (ADR-0079 §4.5).
      def rate(attempts, session_ids)
        corrects = attempts.select { |session_id, _, _| session_ids.include?(session_id) }.map(&:last)
        (corrects.count(true) * 100.0 / corrects.size).round unless corrects.empty?
      end

      # Ceux qui ont le plus besoin de l'enseignant d'abord (ADR-0079 §4.7), puis par nom.
      def students(members)
        by_student = members.index_by(&:student_id)
        Orm::User.where(id: by_student.keys).order(:last_name, :first_name, :id).pluck(:id, :first_name, :last_name)
                 .map do |id, first_name, last_name|
                   scores = by_student.fetch(id).scores
                   StudentRow.new(display_name: "#{first_name} #{last_name}", best: scores.max, trend: Comprehension.trend_for(scores))
                 end
                 .each_with_index.sort_by { |row, rank| [ Comprehension::TREND_ORDER.index(row.trend), rank ] }.map(&:first)
      end
    end
  end
end

# 🔌 INFRA · Queries::Assessment::ComprehensionDetailQuery
# Rôle : section « Compréhension » du suivi : cases par badge, justes par question et élèves d'un badge, du meilleur score au plus faible (UDR enseignant §3.8)
# ADR  : 0026, 0072, 0079, 0097 (§4.9) · UDR : 0072, enseignant §3.8 · après FollowAssignmentPolicy seulement : elle nomme des élèves ; requêtes en nombre constant
module Queries
  module Assessment
    class ComprehensionDetailQuery
      Comprehension = Entities::Assessment::Comprehension
      Grading = Entities::Assessment::Grading

      # Les cinq cases du rapport : « Pas encore » (sous le Bronze) puis les paliers de Grading, du plus bas au plus haut.
      BADGES = [ :none, *Entities::Assessment::Grading::BADGE_ORDER ].freeze

      # category : la dominante (struggling, fragile, acquired) si lisible, sinon nil : elle choisit le prochain geste ;
      # badge_counts : { none:, bronze:, silver:, gold:, diamond: }, le palier du meilleur score de chaque élève qui l'a fait ;
      # selected : la case filtrée (un symbole de BADGES), nil pour tous les élèves qui l'ont fait.
      # weakest_question : le numéro de la question la moins réussie de toute la classe (NextStep.weakest_question), que la case
      # filtrée ne change pas ; nil sans tentative.
      Detail = Data.define(:done, :present, :category, :readable, :badge_counts, :trend_counts, :selected, :questions, :students,
                           :weakest_question)
      # « 18 / 20 justes » : correct, les élèves listés qui ont juste à cette question sur leur meilleure session ; answered,
      # ceux qui l'ont faite (une tentative au plus par session et par question) ; rate, correct en pourcentage arrondi (la
      # barre), nil sans tentative.
      QuestionRate = Data.define(:number, :content, :rate, :correct, :answered)
      # public_id : celui de l'élève, le lien vers sa fiche dans la classe (ADR-0097 §4.9) ; best : son meilleur score (sur 100) ;
      # grade : ce score ramené sur 20 (Grading.grade_on_20, ADR-0106) ; badge : son palier, :none sous le Bronze ;
      # done_on : la date locale de sa première session faite (« Fait le 22 oct. »).
      StudentRow = Data.define(:public_id, :display_name, :best, :grade, :badge, :done_on)

      # « Sans évolution » regroupe stable et stagne ; les élèves sans signe n'entrent pas dans la synthèse (ADR-0079 §4.3).
      TREND_GROUPS = { progress: :progress, stable: :flat, stagnant: :flat, decline: :decline }.freeze

      # badge : un symbole de BADGES, ou n'importe quoi d'autre (ignoré : tous les élèves).
      # → Detail | nil (assignation inconnue, archivée ou d'une autre classe)
      def call(classroom_public_id:, assignment_public_id:, badge:)
        classroom_id, id, exercise_id =
          Orm::ClassroomAssignment.joins(:classroom)
                                  .where(public_id: assignment_public_id, status: "active", assignable_type: "Exercise",
                                         classrooms: { public_id: classroom_public_id })
                                  .pick(:classroom_id, :id, :assignable_id)
        return if id.nil?

        scores = AssignmentScores.for(classroom_id:, assignment_ids: [ id ]).fetch(id, [])
        detail(scores, Queries::Classroom::AssignmentFollowUpQuery.present_students(classroom_id).count, exercise_id, badge,
               classroom_id:, id:)
      end

      private

      def detail(scores, present, exercise_id, badge, classroom_id:, id:)
        dominant = Comprehension.dominant(Comprehension::CATEGORIES.index_with { 0 }.merge(scores.map { category_of(it) }.tally))
        readable = Comprehension.readable?(scores.size)
        selected = badge if BADGES.include?(badge)
        members = selected ? scores.select { badge_of(it) == selected } : scores
        questions = questions(exercise_id, members)
        everybody = selected ? questions(exercise_id, scores) : questions
        Detail.new(done: scores.size, present:, category: (dominant if readable), readable:,
                   badge_counts: BADGES.index_with { 0 }.merge(scores.map { badge_of(it) }.tally),
                   trend_counts: trend_counts(scores), selected:, questions:, students: students(members, classroom_id, id),
                   weakest_question: Entities::Assessment::NextStep.weakest_question(everybody.map(&:rate)))
      end

      def category_of(student_scores) = Comprehension.category_for(student_scores.scores.max)

      # Le palier du meilleur score ; :none sous la note de Bronze (« Pas encore »).
      def badge_of(student_scores) = Entities::Assessment::Grading.badge_for(student_scores.scores.max) || :none

      def trend_counts(scores)
        { progress: 0, flat: 0, decline: 0 }.merge(scores.filter_map { TREND_GROUPS[Comprehension.trend_for(it.scores)] }.tally)
      end

      # Une requête pour les questions, une pour les tentatives des meilleures sessions des élèves listés.
      def questions(exercise_id, members)
        attempts = Orm::QuestionAttempt.where(exercise_session_id: members.map(&:best_session_id))
                                       .pluck(:question_id, :correct).group_by(&:first)
        Orm::Question.where(exercise_id:).order(:position).pluck(:id, :content).each_with_index.map do |(question_id, content), index|
          answers = attempts.fetch(question_id, []).map(&:last)
          correct = answers.count(true)
          rate = (correct * 100.0 / answers.size).round unless answers.empty?
          QuestionRate.new(number: index + 1, content:, rate:, correct:, answered: answers.size)
        end
      end

      # Du meilleur score au plus faible, puis par nom (« Fait le … » : la première session faite, quel que soit son kind).
      def students(members, classroom_id, id)
        by_student = members.index_by(&:student_id)
        done_on = Queries::Classroom::AssignmentFollowUpQuery.first_done(classroom_id, [ id ]).to_h { [ it.student_id, it.done_on ] }
        Orm::User.where(id: by_student.keys).order(:last_name, :first_name, :id).pluck(:id, :public_id, :first_name, :last_name)
                 .map do |student_id, public_id, first_name, last_name|
                   best = by_student.fetch(student_id).scores.max
                   StudentRow.new(public_id:, display_name: "#{first_name} #{last_name}", best:, grade: Grading.grade_on_20(best),
                                  badge: Grading.badge_for(best) || :none, done_on: done_on.fetch(student_id))
                 end
                 .each_with_index.sort_by { |row, rank| [ -row.best, rank ] }.map(&:first)
      end
    end
  end
end

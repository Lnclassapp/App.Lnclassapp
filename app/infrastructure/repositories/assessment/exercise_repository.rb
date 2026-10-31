# 🔌 INFRA · Repositories::Assessment::ExerciseRepository
# Rôle : traduit Orm::Exercise, ses questions, propositions et images ↔ Entities::Assessment::Exercise, avec la publication des parents
# ADR  : 0035, 0036, 0039, 0054, 0091, 0105, 0113, 0115, 0120-questions-a-plusieurs-cases-et-indice (§4 : blank, hint), XXXX-sujets-de-devoir-et-verification-sur-la-feuille
module Repositories
  module Assessment
    class ExerciseRepository
      include Ports::Assessment::ExerciseRepositoryPort

      def find_by_public_id(public_id:)
        record = hydrated.find_by(public_id:)
        record && map_to_entity(record)
      end

      def find(id:)
        record = hydrated.find_by(id:)
        record && map_to_entity(record)
      end

      def for_course(course_id:)
        hydrated.left_joins(:essential).where(course_id:).order(Arel.sql("essentials.position NULLS LAST, essentials.id NULLS LAST, exercises.position"))
                .map { map_to_entity(it) }
      end

      # Appelé dans la transaction du use case : l'exercice, ses questions et leurs propositions. La leçon d'une notion est
      # celle de la notion : une autre est refusée (la redondance course_id / notion ne se contredit jamais).
      def create(exercise:)
        course_id = course_of(exercise)
        record = Orm::Exercise.create!(
          public_id: exercise.public_id, course_id:, essential_id: exercise.essential_id, author_id: exercise.author_id,
          position: exercise.position || next_course_position(course_id),
          status: exercise.status || "draft", statement_blocks: exercise.statement_blocks.presence, **editable_attributes(exercise)
        )
        write_questions(record.id, exercise.questions)
        find_by_public_id(public_id: record.public_id)
      end

      # replace_questions : interdit par le use case dès qu'une session existe (ADR-0036).
      def update(exercise:, replace_questions:)
        record = Orm::Exercise.find(exercise.id)
        record.update!(editable_attributes(exercise))
        if replace_questions
          question_ids = Orm::Question.where(exercise_id: record.id).select(:id)
          # FK RESTRICT (ADR-0105) : les images quittent leurs questions avant elles, puis seules celles qui ne sont plus
          # citées partent, fichier compris.
          previous = Orm::QuestionImage.where(question_id: question_ids).pluck(:id)
          Orm::QuestionImage.where(id: previous).update_all(question_id: nil)
          Orm::Answer.where(question_id: question_ids).delete_all
          Orm::Question.where(exercise_id: record.id).delete_all
          write_questions(record.id, exercise.questions)
          destroy_uncited(previous)
        end
        find_by_public_id(public_id: record.public_id)
      end

      # La première publication pose published_at ; l'archivage pose archived_at (ADR-0035).
      def transition(id:, to:, at:)
        scope = Orm::Exercise.where(id:)
        case to
        when "published"
          scope.update_all([ "status = 'published', published_at = COALESCE(published_at, ?), archived_at = NULL, updated_at = ?", at, at ])
        when "archived" then scope.update_all(status: "archived", archived_at: at, updated_at: at)
        else raise ArgumentError, "transition impossible vers #{to.inspect}"
        end
        true
      end

      def has_sessions?(exercise_id:)
        Orm::ExerciseSession.exists?(exercise_id:)
      end

      def existing_keys(essential_ids: nil)
        scope = essential_ids.nil? ? Orm::Exercise.all : Orm::Exercise.where(essential_id: essential_ids)
        scope.pluck(:essential_id, :title).to_set { |essential_id, title| [ essential_id, Entities::Shared::NaturalKey.normalize(title) ] }
      end

      def draft_public_ids(course_id: nil, essential_id: nil)
        scope = Orm::Exercise.left_joins(:essential).where(status: "draft")
        # Un exercice de toute la leçon n'a pas de notion à attendre : il suit la leçon.
        scope = course_id ? scope.where(course_id:).where("exercises.essential_id IS NULL OR essentials.status = 'published'") : scope.where(essential_id:, essentials: { status: "published" })
        scope.order(Arel.sql("essentials.position NULLS LAST, essentials.id NULLS LAST, exercises.position, exercises.id")).pluck(:public_id)
      end

      def next_positions(essential_ids:)
        course_ids = Orm::Essential.where(id: essential_ids).pluck(:id, :course_id).to_h
        maximums = Orm::Exercise.where(course_id: course_ids.values).group(:course_id).maximum(:position)
        essential_ids.index_with { |essential_id| maximums.fetch(course_ids.fetch(essential_id), 0) + 1 }
      end

      private

      def hydrated = Orm::Exercise.includes(:course, :essential, questions: %i[answers image])

      def editable_attributes(exercise)
        { title: exercise.title, statement: exercise.statement, exercise_type: exercise.exercise_type }
      end

      def course_of(exercise)
        return exercise.course_id if exercise.essential_id.nil?

        course_id = Orm::Essential.where(id: exercise.essential_id).pick(:course_id)
        raise Ports::Assessment::ExerciseRepositoryPort::EssentialOutsideCourse if exercise.course_id && exercise.course_id != course_id

        course_id
      end

      def next_course_position(course_id) = Orm::Exercise.where(course_id:).maximum(:position).to_i + 1

      def write_questions(exercise_id, questions)
        questions.each_with_index do |question, index|
          record = Orm::Question.create!(exercise_id:, position: question.position || index + 1, content: question.content,
                                         explanation: question.explanation, question_type: question.question_type,
                                         numeric_tolerance: question.numeric_tolerance, image_description: question.image_description,
                                         hint: question.hint.to_s.strip.presence, **correction_attributes(question))
          attach_image(record.id, question.image)
          question.answers.each_with_index do |answer, rank|
            Orm::Answer.create!(question_id: record.id, position: answer.position || rank + 1, content: answer.content,
                                correct: answer.correct, match_content: answer.match_content, blank: answer.blank)
          end
        end
      end

      # ADR-0115 : chaînes vides → null, critères vides retirés. Le sujet en blocs n'est écrit qu'à la création : une modification
      # (qui ne le porte pas) le laisse tel quel. Les bornes de points et d'unité sont celles de la base.
      def correction_attributes(question)
        { points: question.points, unit: question.unit.to_s.strip.presence, starter: question.starter.to_s.strip.presence,
          criteria: Array(question.criteria).map { it.to_s.strip }.reject(&:empty?) }
      end

      # Seule une image qui n'est à aucune question se rattache : une image d'une autre question reste où elle est, et
      # l'enregistrement est refusé plutôt que d'écrire la question sans son image.
      def attach_image(question_id, image)
        return if image.nil?

        attached = Orm::QuestionImage.where(public_id: image.public_id, question_id: nil).update_all(question_id:, alt: image.alt.presence)
        raise Ports::Assessment::ExerciseRepositoryPort::ImageUnavailable if attached != 1
      end

      # Les images que les nouvelles questions ne citent plus partent avec leur fichier ; le journal garde lesquelles.
      def destroy_uncited(previous)
        uncited = Orm::QuestionImage.where(id: previous, question_id: nil).to_a
        return if uncited.empty?

        uncited.each(&:destroy!)
        Rails.logger.info("[ExerciseRepository] images supprimées ids=#{uncited.map(&:id)} public_ids=#{uncited.map(&:public_id)}")
      end

      def map_to_entity(record)
        Entities::Assessment::Exercise.new(
          id: record.id, public_id: record.public_id, course_id: record.course_id, essential_id: record.essential_id,
          title: record.title, statement: record.statement, exercise_type: record.exercise_type, position: record.position,
          author_id: record.author_id, status: record.status, published_at: record.published_at,
          archived_at: record.archived_at, questions: record.questions.map { |question| map_question(question) },
          statement_blocks: record.statement_blocks, hint: record.hint, subject_id: record.subject_id,
          parents_published: [ record.essential, record.course ].compact.all? { |parent| parent.status == "published" }
        )
      end

      def map_question(record)
        Entities::Assessment::Question.new(
          id: record.id, position: record.position, content: record.content, explanation: record.explanation,
          question_type: record.question_type, numeric_tolerance: record.numeric_tolerance,
          image_description: record.image_description, image: map_image(record.image),
          points: record.points, unit: record.unit, starter: record.starter, criteria: record.criteria, hint: record.hint,
          answers: record.answers.map do |answer|
            Entities::Assessment::Answer.new(id: answer.id, position: answer.position, content: answer.content, correct: answer.correct,
                                             match_content: answer.match_content, blank: answer.blank)
          end
        )
      end

      def map_image(image)
        image && Entities::Shared::ContentImage.new(public_id: image.public_id, id: image.id, owner_id: image.question_id, alt: image.alt,
                                                    content_type: image.content_type, byte_size: image.byte_size,
                                                    width: image.width, height: image.height)
      end
    end
  end
end

# 🔌 INFRA · Repositories::Assessment::ExerciseRepository
# Rôle : traduit Orm::Exercise, ses questions, propositions et images ↔ Entities::Assessment::Exercise, avec la publication des parents
# ADR  : 0035, 0036, 0039, 0054, 0091, 0104
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

      # Appelé dans la transaction du use case : l'exercice, ses questions et leurs propositions.
      def create(exercise:)
        record = Orm::Exercise.create!(
          public_id: exercise.public_id, essential_id: exercise.essential_id, author_id: exercise.author_id,
          position: exercise.position || next_positions(essential_ids: [ exercise.essential_id ]).fetch(exercise.essential_id),
          status: exercise.status || "draft", **editable_attributes(exercise)
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
          # FK RESTRICT (ADR-0104) : les images quittent leurs questions avant elles, puis seules celles qui ne sont plus
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
        scope = Orm::Exercise.joins(:essential).where(status: "draft", essentials: { status: "published" })
        scope = course_id ? scope.where(essentials: { course_id: }) : scope.where(essential_id:)
        scope.order("essentials.position", "essentials.id", :position, :id).pluck(:public_id)
      end

      def next_positions(essential_ids:)
        maximums = Orm::Exercise.where(essential_id: essential_ids).group(:essential_id).maximum(:position)
        essential_ids.index_with { |essential_id| maximums.fetch(essential_id, 0) + 1 }
      end

      private

      def hydrated = Orm::Exercise.includes({ essential: :course }, questions: %i[answers image])

      def editable_attributes(exercise)
        { title: exercise.title, description: exercise.description, exercise_type: exercise.exercise_type }
      end

      def write_questions(exercise_id, questions)
        questions.each_with_index do |question, index|
          record = Orm::Question.create!(exercise_id:, position: question.position || index + 1, content: question.content,
                                         explanation: question.explanation, question_type: question.question_type,
                                         numeric_tolerance: question.numeric_tolerance, image_description: question.image_description)
          attach_image(record.id, question.image)
          question.answers.each_with_index do |answer, rank|
            Orm::Answer.create!(question_id: record.id, position: answer.position || rank + 1, content: answer.content,
                                correct: answer.correct, match_content: answer.match_content)
          end
        end
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
          id: record.id, public_id: record.public_id, essential_id: record.essential_id, title: record.title,
          description: record.description, exercise_type: record.exercise_type, position: record.position,
          author_id: record.author_id, status: record.status, published_at: record.published_at,
          archived_at: record.archived_at, questions: record.questions.map { |question| map_question(question) },
          parents_published: [ record.essential, record.essential.course ].all? { |parent| parent.status == "published" }
        )
      end

      def map_question(record)
        Entities::Assessment::Question.new(
          id: record.id, position: record.position, content: record.content, explanation: record.explanation,
          question_type: record.question_type, numeric_tolerance: record.numeric_tolerance,
          image_description: record.image_description, image: map_image(record.image),
          answers: record.answers.map do |answer|
            Entities::Assessment::Answer.new(id: answer.id, position: answer.position, content: answer.content, correct: answer.correct,
                                             match_content: answer.match_content)
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

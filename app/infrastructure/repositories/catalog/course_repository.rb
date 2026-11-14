# 🔌 INFRA · Repositories::Catalog::CourseRepository
# Rôle : traduit Orm::Course et son contenu riche (Action Text) ↔ Entities::Catalog::Course ; slug figé à la création
# ADR  : 0029, 0035, 0039, 0075, 0116, chargement-automatique-des-lecons-hors-production, XXXX-suppression-d-une-lecon-sans-activite-eleve
module Repositories
  module Catalog
    class CourseRepository
      include Ports::Catalog::CourseRepositoryPort

      # ADR-0075 : les assignations d'exercices du cours, de notion ou de toute la leçon, lues par exercises.course_id (ADR-0113).
      ASSIGNED_EXERCISE = "JOIN exercises ON exercises.id = classroom_assignments.assignable_id " \
                          "AND classroom_assignments.assignable_type = 'Exercise'".freeze

      def find_by_slug(slug:)
        # A single record: no eager loading, which Bullet reports as unused (lot B2). The rich text costs one query.
        record = Orm::Course.find_by(slug:)
        record && map_to_entity(record)
      end

      def create(course:)
        persist(Orm::Course.new(slug: course.slug, level_id: course.level_id, series_id: course.series_id,
                                material_id: course.material_id, author_id: course.author_id,
                                status: course.status || "draft", **editable_attributes(course)))
      end

      def update(course:)
        record = Orm::Course.find(course.id)
        record.assign_attributes(level_id: course.level_id, series_id: course.series_id, material_id: course.material_id,
                                 **editable_attributes(course))
        persist(record)
      end

      # La première publication pose published_at ; l'archivage pose archived_at (ADR-0035).
      def transition(id:, to:, at:)
        scope = Orm::Course.where(id:)
        case to
        when "published"
          scope.update_all([ "status = 'published', published_at = COALESCE(published_at, ?), archived_at = NULL, updated_at = ?", at, at ])
        when "archived" then scope.update_all(status: "archived", archived_at: at, updated_at: at)
        else raise ArgumentError, "transition impossible vers #{to.inspect}"
        end
        true
      end

      def existing_keys
        Orm::Course.pluck(:name, :level_id, :material_id, :series_id).to_set do |name, *taxonomy|
          [ Entities::Shared::NaturalKey.compact(name), *taxonomy ]
        end
      end

      def ids_by_key
        Orm::Course.pluck(:id, :name, :level_id, :material_id, :series_id).to_h do |id, name, *taxonomy|
          [ [ Entities::Shared::NaturalKey.compact(name), *taxonomy ], id ]
        end
      end

      def taken_slugs
        Orm::Course.pluck(:slug).to_set
      end

      def slugs_by_key
        Orm::Course.pluck(:slug, :name, :level_id, :material_id, :series_id).to_h do |slug, name, *taxonomy|
          [ [ Entities::Shared::NaturalKey.compact(name), *taxonomy ], slug ]
        end
      end

      # ADR-0116 §4.4 : la leçon et ses notions et exercices sont lus sous verrou (FOR UPDATE), dans la transaction de l'appelant.
      def status_for_update(id:)
        course = Orm::Course.lock.find_by(id:)
        return if course.nil?

        contents = Orm::Essential.where(course_id: id).lock.pluck(:status) + Orm::Exercise.where(course_id: id).lock.pluck(:status)
        { course: course.status, contents: }
      end

      # Lecture d'intégrité dans le contexte classroom (ADR-0075 §5) : une ligne par classe, quel que soit le nombre de
      # ses assignations actives, en une requête (sous-requête IN).
      def assigned_classroom_levels(id:)
        classroom_ids = Orm::ClassroomAssignment.joins(ASSIGNED_EXERCISE).where(status: "active", exercises: { course_id: id })
                                                .select(:classroom_id)
        Orm::Classroom.where(id: classroom_ids).pluck(:level_id, :series_id)
      end

      def student_activity(id:)
        exercise_ids = Orm::Exercise.where(course_id: id).select(:id)
        essential_ids = Orm::Essential.where(course_id: id).select(:id)
        session_ids = Orm::ExerciseSession.where(exercise_id: exercise_ids).select(:id)
        question_ids = Orm::Question.where(exercise_id: exercise_ids).select(:id)
        Entities::Catalog::StudentActivity.new(
          sessions: Orm::ExerciseSession.where(exercise_id: exercise_ids).count,
          # Une réponse se rattache à la leçon par sa question ou par sa séance.
          attempts: Orm::QuestionAttempt.where(question_id: question_ids).or(Orm::QuestionAttempt.where(exercise_session_id: session_ids)).count,
          badges: Orm::ExerciseBadge.where(exercise_id: exercise_ids).count,
          # essential_reads → essentials est en ON DELETE CASCADE : seule cette lecture empêche d'effacer une lecture d'élève.
          reads: Orm::EssentialRead.where(essential_id: essential_ids).count,
          gaps: Orm::KnowledgeGap.where(essential_id: essential_ids).count,
          offline_packs: Orm::OfflinePackDelivery.where(exercise_id: exercise_ids).count,
          # Lien polymorphe sans clé étrangère ; un devoir archivé compte comme un actif.
          assignments: Orm::ClassroomAssignment.where(assignable_type: "Exercise", assignable_id: exercise_ids).count
        )
      end

      # Ordre des verrous : leçon, notions, exercices, questions (celui de ContentTreeWriter#replace_draft, sans interblocage avec un
      # import). Une trace écrite en même temps prend FOR KEY SHARE sur sa ligne parente : elle attend la fin de la transaction.
      def lock_for_deletion(id:)
        return if Orm::Course.lock.find_by(id:).nil?

        Orm::Essential.where(course_id: id).order(:id).lock.pluck(:id)
        exercise_ids = Orm::Exercise.where(course_id: id).order(:id).lock.pluck(:id)
        Orm::Question.where(exercise_id: exercise_ids).order(:id).lock.pluck(:id)
        student_activity(id:)
      end

      # Du plus dépendant au moins dépendant ; aucune table d'élève n'est touchée : la clé RESTRICT d'une trace oubliée lève.
      def delete(id:)
        exercise_ids = Orm::Exercise.where(course_id: id).pluck(:id)
        question_ids = Orm::Question.where(exercise_id: exercise_ids).pluck(:id)
        deleted = {}
        # Détruites une à une : Active Storage purge leurs fichiers après la validation.
        deleted[:question_images] = Orm::QuestionImage.where(question_id: question_ids).to_a.each(&:destroy!).size
        deleted[:answers] = Orm::Answer.where(question_id: question_ids).delete_all
        deleted[:questions] = Orm::Question.where(id: question_ids).delete_all
        deleted[:exercises] = Orm::Exercise.where(id: exercise_ids).delete_all
        deleted[:subjects] = Orm::Subject.where(course_id: id).delete_all
        deleted[:essentials] = Orm::Essential.where(course_id: id).delete_all
        # Détruit par Action Text, pour que ses pièces jointes partent avec lui.
        deleted[:course_text] = ActionText::RichText.where(record_type: "Orm::Course", record_id: id).to_a.each(&:destroy!).size
        deleted[:courses] = Orm::Course.where(id:).delete_all
        deleted.slice(:courses, :essentials, :exercises, :questions, :answers, :subjects, :question_images, :course_text)
      end

      private

      def editable_attributes(course)
        { name: course.name, subtitle: course.subtitle, content: Repositories::Shared::RichTextSanitizer.call(course.content) }
      end

      # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
      def persist(record)
        Orm::Course.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
      end

      # Le HTML du contenu riche, assaini à l'écriture (RichTextSanitizer) puis de nouveau au rendu par Action Text.
      def map_to_entity(record)
        Entities::Catalog::Course.new(
          id: record.id, slug: record.slug, name: record.name, subtitle: record.subtitle, level_id: record.level_id,
          series_id: record.series_id, material_id: record.material_id, author_id: record.author_id,
          status: record.status, published_at: record.published_at, archived_at: record.archived_at,
          content: record.content.body&.to_html
        )
      end
    end
  end
end

require "test_helper"

module Repositories
  module Catalog
    # ADR-XXXX-suppression-d-une-lecon-sans-activite-eleve : l'activité d'élève se lit source par source (CA-02), sous verrou, et la
    # suppression emporte tout le contenu de la leçon, rien d'autre (CA-03, CA-04).
    class CourseRepositoryDeletionTest < ActiveSupport::TestCase
      setup do
        @repository = CourseRepository.new
        @level = create_level
        @material = create_material
        @course = create_course(level: @level, material: @material, name: "Les suites", content: "<p>Cours</p>")
        @notion = create_essential(course: @course, name: "Suites arithmétiques")
        @exercise = create_exercise(essential: @notion)
        @question = @exercise.questions.first
        @problem = create_lesson_wide_exercise(course: @course)
        @subject = create_subject(course: @course)
        @subject_exercise = create_exercise(subject: @subject)
        @image = create_question_image(question: @question)
        # Une leçon voisine : ses traces servent de séance « ailleurs » pour isoler chaque source, et elle ne doit rien perdre.
        @neighbour = create_course(level: @level, material: @material, name: "Voisine", content: "<p>Voisine</p>")
        @neighbour_exercise = create_exercise(essential: create_essential(course: @neighbour))
        @student = create_student
      end

      def elsewhere = @elsewhere ||= create_exercise_session(student: @student, exercise: @neighbour_exercise, status: "completed")

      def activity = Orm::Course.transaction { @repository.lock_for_deletion(id: @course.id) }

      def assert_only(source)
        result = activity
        assert result.any?, "#{source} doit compter comme activité"
        assert_equal [ source ], result.to_h.select { |_, count| count.positive? }.keys
      end

      test "a lesson nobody used has no activity" do
        elsewhere

        assert_not activity.any?
        assert_equal Entities::Catalog::StudentActivity.none, @repository.student_activity(id: @course.id)
      end

      test "CA-02 : a started session on a notion exercise, a lesson-wide problem or a subject exercise counts" do
        [ @exercise, @problem, @subject_exercise ].each do |exercise|
          session = create_exercise_session(student: @student, exercise:)
          assert_only :sessions
          session.destroy!
        end
      end

      test "CA-02 : an answer counts, even inside a session of another lesson" do
        create_attempt(session: elsewhere, question: @question)

        assert_only :attempts
      end

      test "CA-02 : a badge counts" do
        create_badge(student: @student, exercise: @exercise, session: elsewhere)

        assert_only :badges
      end

      test "CA-02 : a read notion counts (the database would erase it in cascade)" do
        create_essential_read(student: @student, essential: @notion)

        assert_only :reads
      end

      test "CA-02 : a knowledge gap on a notion counts" do
        create_gap(student: @student, essential: @notion, source_session: elsewhere)

        assert_only :gaps
      end

      test "CA-02 : an offline pack delivered counts" do
        Orm::OfflinePackDelivery.create!(student: @student, exercise: @problem, first_delivered_at: Time.current, last_delivered_at: Time.current)

        assert_only :offline_packs
      end

      test "CA-02 : an assignment counts, active or archived" do
        %w[active archived].each do |status|
          assignment = create_assignment(assignable: @subject_exercise, status:)
          assert_only :assignments
          assignment.destroy!
        end
      end

      test "CA-02 : the student activity read without lock gives the same count" do
        create_essential_read(student: @student, essential: @notion)

        assert_equal 1, @repository.student_activity(id: @course.id).reads
      end

      test "CA-03 : delete takes away the lesson and all its content, images and course text, and the neighbour keeps everything" do
        neighbour_before = [ Orm::Essential.where(course_id: @neighbour.id).count, Orm::Exercise.where(course_id: @neighbour.id).count,
                             Orm::Question.joins(:exercise).where(exercises: { course_id: @neighbour.id }).count, elsewhere.id ]
        exercise_ids = Orm::Exercise.where(course_id: @course.id).pluck(:id)
        question_ids = Orm::Question.where(exercise_id: exercise_ids).pluck(:id)
        attachment_id = @image.file.attachment.id

        deleted = Orm::Course.transaction do
          @repository.lock_for_deletion(id: @course.id)
          @repository.delete(id: @course.id)
        end

        assert_equal({ courses: 1, essentials: 1, exercises: 3, questions: 6, answers: 24, subjects: 1, question_images: 1, course_text: 1 }, deleted)
        assert_not Orm::Course.exists?(@course.id)
        assert_equal [ 0, 0, 0, 0, 0 ], [ Orm::Essential.where(course_id: @course.id), Orm::Exercise.where(id: exercise_ids),
                                          Orm::Question.where(id: question_ids), Orm::Answer.where(question_id: question_ids),
                                          Orm::Subject.where(course_id: @course.id) ].map(&:count)
        assert_not Orm::QuestionImage.exists?(@image.id)
        assert_not Orm::RichTextRow.exists?(record_type: "Orm::Course", record_id: @course.id)
        # Le fichier part avec l'image : son attachement est détruit, la purge du blob suit la validation (purge_later).
        assert_not ActiveStorage::Attachment.exists?(attachment_id)
        assert_equal neighbour_before, [ Orm::Essential.where(course_id: @neighbour.id).count, Orm::Exercise.where(course_id: @neighbour.id).count,
                                         Orm::Question.joins(:exercise).where(exercises: { course_id: @neighbour.id }).count,
                                         Orm::ExerciseSession.find(elsewhere.id).id ]
        assert_equal "<p>Voisine</p>", @neighbour.reload.content.body.to_html.strip
      end

      test "CA-04 : a draft or an archived lesson is deleted the same way" do
        %w[draft archived].each do |status|
          course = create_course(level: @level, material: @material, status:)
          create_exercise(essential: create_essential(course:, status:), status:)

          Orm::Course.transaction do
            assert_not @repository.lock_for_deletion(id: course.id).any?
            assert_equal 1, @repository.delete(id: course.id).fetch(:courses)
          end
          assert_not Orm::Course.exists?(course.id)
        end
      end

      test "a student trace the check missed is never erased : the restricted foreign key aborts the delete" do
        create_exercise_session(student: @student, exercise: @exercise)

        assert_raises(ActiveRecord::InvalidForeignKey) { Orm::Course.transaction { @repository.delete(id: @course.id) } }
        assert Orm::Course.exists?(@course.id)
        assert_equal 1, Orm::ExerciseSession.where(exercise_id: @exercise.id).count
      end

      test "a missing lesson has no activity to lock" do
        assert_nil Orm::Course.transaction { @repository.lock_for_deletion(id: -1) }
      end
    end
  end
end

require "test_helper"

module Repositories
  module Classroom
    # ADR-0072 §4.2 : une ligne par jour ; « non renseigné » = aucune ligne ; remplacer = supprimer puis insérer.
    class SessionDaysRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = SessionDaysRepository.new
        @classroom = create_classroom
        @teacher = create_teacher(classrooms: [ @classroom ])
        @at = Time.zone.parse("2026-10-05 10:00")
      end

      def rows = Orm::ClassroomSessionDay.where(teacher_id: @teacher.id, classroom_id: @classroom.id)

      test "sans ligne, les jours sont vides : non renseigné" do
        session_days = @repository.for(teacher_id: @teacher.id, classroom_id: @classroom.id)

        assert_equal Entities::Classroom::SessionDays.new(weekdays: []), session_days
        assert session_days.none?
      end

      test "remplace les jours, une ligne par jour, puis les relit triés" do
        assert_equal true, @repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 4, 1, 4 ], at: @at)

        assert_equal [ 1, 4 ], @repository.for(teacher_id: @teacher.id, classroom_id: @classroom.id).weekdays
        assert_equal [ @at ], rows.distinct.pluck(:created_at)

        @repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 2 ], at: @at + 1.day)

        assert_equal [ 2 ], @repository.for(teacher_id: @teacher.id, classroom_id: @classroom.id).weekdays
        assert_equal 1, rows.count
      end

      test "tout décocher revient à non renseigné : aucune ligne" do
        @repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ], at: @at)

        assert @repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [], at: @at)
        assert_not rows.exists?
      end

      test "chaque enseignant a ses jours dans chaque classe ; remplacer ne touche qu'à ceux-là" do
        colleague = create_teacher(classrooms: [ @classroom ])
        other_classroom = create_classroom(school: @classroom.school)
        Orm::TeacherClassroom.create!(teacher: @teacher, classroom: other_classroom)
        @repository.replace(teacher_id: colleague.id, classroom_id: @classroom.id, weekdays: [ 3 ], at: @at)
        @repository.replace(teacher_id: @teacher.id, classroom_id: other_classroom.id, weekdays: [ 6 ], at: @at)

        @repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1 ], at: @at)

        assert_equal [ 3 ], @repository.for(teacher_id: colleague.id, classroom_id: @classroom.id).weekdays
        assert_equal [ 6 ], @repository.for(teacher_id: @teacher.id, classroom_id: other_classroom.id).weekdays
        assert_equal [ 1 ], @repository.for(teacher_id: @teacher.id, classroom_id: @classroom.id).weekdays
      end

      test "un jour hors de 1..6 lève ArgumentError et ne remplace rien" do
        @repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1 ], at: @at)

        assert_raises(ArgumentError) { @repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 7 ], at: @at) }
        assert_equal [ 1 ], @repository.for(teacher_id: @teacher.id, classroom_id: @classroom.id).weekdays
      end

      test "une classe non déclarée par l'enseignant n'a pas de jours : la base refuse, rien n'est écrit" do
        undeclared = create_classroom(school: @classroom.school)

        assert_raises(ActiveRecord::InvalidForeignKey) do
          @repository.replace(teacher_id: @teacher.id, classroom_id: undeclared.id, weekdays: [ 1 ], at: @at)
        end
      end

      test "le modèle nomme son enseignant et sa classe" do
        @repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 5 ], at: @at)

        row = rows.sole

        assert_equal [ @teacher, @classroom, 5 ], [ row.teacher, row.classroom, row.weekday ]
      end
    end
  end
end

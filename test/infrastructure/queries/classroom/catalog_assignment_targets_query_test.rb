require "test_helper"

module Queries
  module Classroom
    # RE-21 à RE-24 — UDR-0069 §3.8 : depuis le catalogue, l'enseignant assigne un exercice à ses seules classes du niveau du
    # cours (et de sa série s'il en a une) : actives, de l'année scolaire, déclarées par lui. Pour chacune, l'assignation
    # active de chaque exercice et son échéance, et si la modale des jours doit s'ouvrir (ADR-0072 §4.2).
    class CatalogAssignmentTargetsQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @tle = create_level(name: "Tle")
        @d = create_series(name: "D")
        @c = create_series(name: "C")
        @course = create_course(level: @tle, series: @d)
        essential = create_essential(course: @course)
        @first = create_exercise(essential:, title: "Les phases")
        @second = create_exercise(essential:, title: "Le bilan")
        @tle_d1 = create_classroom(school: @school, level: @tle, series: @d, name: "Tle D 1")
        @teacher = create_teacher(school: @school, classrooms: [ @tle_d1 ])
      end

      def targets(course: @course, teacher: @teacher, exercises: [ @first, @second ], **)
        CatalogAssignmentTargetsQuery.new.call(teacher_id: teacher.id, course_slug: course.slug,
                                               exercise_public_ids: exercises.map(&:public_id), **)
      end

      def declare(name, level: @tle, series: @d, teacher: @teacher, **)
        create_classroom(school: @school, level:, series:, name:, **).tap { Orm::TeacherClassroom.create!(teacher:, classroom: it) }
      end

      def names(result = targets) = result.classrooms.map(&:name)

      test "RE-23 : un cours de Tle D n'offre que les classes de Tle D ; un cours de Tle sans série, toutes celles de Tle" do
        declare("Tle C 1", series: @c)
        declare("Tle A 1", series: create_series(name: "A"))
        declare("3ème 1", level: create_level(name: "3ème"), series: nil)

        assert_equal [ "Tle D 1" ], names
        assert_equal [ "Tle A 1", "Tle C 1", "Tle D 1" ], names(targets(course: create_course(level: @tle, series: nil)))
      end

      test "le libellé du niveau : le niveau, puis la série s'il y en a une" do
        assert_equal "Tle D", targets.scope_label
        assert_equal "3ème", targets(course: create_course(level: create_level(name: "3ème"))).scope_label
      end

      test "seulement les classes déclarées par l'enseignant, actives, de l'année scolaire du jour donné" do
        create_teacher(school: @school, classrooms: [ create_classroom(school: @school, level: @tle, series: @d, name: "Tle D 2") ])
        create_classroom(school: @school, level: @tle, series: @d, name: "Tle D 3")
        declare("Tle D 4", status: "archived")
        declare("Tle D 5", school_year: "2000-2001")

        assert_equal [ "Tle D 1" ], names
        assert_equal [ "Tle D 5" ], names(targets(today: Date.new(2000, 9, 15)))
      end

      test "tri par nom naturel : « Tle D 2 » avant « Tle D 10 »" do
        declare("Tle D 10")
        declare("Tle D 2")

        assert_equal [ "Tle D 1", "Tle D 2", "Tle D 10" ], names
      end

      test "une cible : identifiant public, nom, et la modale des jours tant que l'enseignant ne les a pas donnés" do
        with_days = declare("Tle D 2")
        Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: with_days.id,
                                                                    weekdays: [ 1, 4 ], at: Time.current)
        # Les jours d'un collègue dans la même classe ne dispensent pas l'enseignant de donner les siens.
        colleague = create_teacher(school: @school, classrooms: [ @tle_d1 ])
        Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: colleague.id, classroom_id: @tle_d1.id,
                                                                    weekdays: [ 2 ], at: Time.current)

        assert_equal [ [ @tle_d1.public_id, "Tle D 1", true ], [ with_days.public_id, "Tle D 2", false ] ],
                     targets.classrooms.map { it.to_h.values_at(:public_id, :name, :needs_session_days) }
      end

      test "les états : l'assignation active de chaque exercice dans chaque classe, avec son échéance ; rien d'autre" do
        tle_d2 = declare("Tle D 2")
        active = create_assignment(classroom: @tle_d1, assignable: @first, by: @teacher, due_on: Date.current + 3)
        create_assignment(classroom: @tle_d1, assignable: @second, by: @teacher, status: "archived")
        undated = create_assignment(classroom: tle_d2, assignable: @second, by: @teacher)
        # Une autre classe, ou un exercice hors de la liste demandée, n'apparaissent pas.
        create_assignment(classroom: create_classroom(school: @school, level: @tle, series: @d), assignable: @first)
        create_assignment(classroom: @tle_d1, assignable: create_exercise(essential: create_essential(course: @course)))

        assert_equal({ [ @tle_d1.public_id, @first.public_id ] => [ active.public_id, Date.current + 3 ],
                       [ tle_d2.public_id, @second.public_id ] => [ undated.public_id, nil ] },
                     targets.states.transform_values { it.to_h.values_at(:assignment_public_id, :due_on) })
      end

      test "aucune classe au bon niveau : aucune cible, aucun état, le libellé reste" do
        teacher = create_teacher(school: @school)
        declare("Tle C 1", series: @c, teacher:)
        create_assignment(classroom: @tle_d1, assignable: @first, by: @teacher)

        result = targets(teacher:)

        assert_empty result.classrooms
        assert_empty result.states
        assert_equal "Tle D", result.scope_label
      end

      test "sans exercice demandé : les classes, sans état" do
        create_assignment(classroom: @tle_d1, assignable: @first, by: @teacher)

        result = targets(exercises: [])

        assert_equal [ "Tle D 1" ], names(result)
        assert_empty result.states
      end

      test "un cours inconnu : nil" do
        assert_nil CatalogAssignmentTargetsQuery.new.call(teacher_id: @teacher.id, course_slug: "inconnu", exercise_public_ids: [])
      end

      test "deux requêtes au plus, quel que soit le nombre d'exercices et de classes" do
        exercises = [ @first, @second, *Array.new(3) { create_exercise(essential: @first.essential) } ]
        3.times { |index| declare("Tle D #{index + 2}") }
        exercises.each { create_assignment(classroom: @tle_d1, assignable: it, by: @teacher) }

        queries = count_queries { targets(exercises:) }

        assert_operator queries, :<=, 2
      end

      private

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end

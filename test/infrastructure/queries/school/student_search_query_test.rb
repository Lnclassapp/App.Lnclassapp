require "test_helper"

# ED-60 to ED-65 (UDR-0094 §3.2): the present students of one school whose name contains the term, first name or last
# name first, without case nor accents; with their classroom; never another school, a withdrawn student, an archived
# classroom, an anonymized account, nor a phone number; three letters at least; one query on the trigram name indexes.
module Queries
  module School
    class StudentSearchQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @sixth = create_classroom(school: @school, level: create_level(name: "6ème", position: 1), name: "6ème 3")
        @terminal = create_classroom(school: @school, level: create_level(name: "Tle", position: 7), name: "Tle D1")
        @aya = create_student(classroom: @sixth, first_name: "Aya", last_name: "Kouassi", contact: "0701020304")
        @brou = create_student(classroom: @terminal, first_name: "Brou", last_name: "Kouassi")
        @query = StudentSearchQuery.new
      end

      def names(term, **) = @query.call(school_id: @school.id, term:, **).map(&:display_name)

      test "ED-60: both Kouassi with their classroom and level, by name then classroom" do
        rows = @query.call(school_id: @school.id, term: "kouas")

        assert_equal [ [ "Aya Kouassi", @sixth.public_id, "6ème 3", "6ème" ], [ "Brou Kouassi", @terminal.public_id, "Tle D1", "Tle" ] ],
                     rows.map { [ it.display_name, it.classroom_public_id, it.classroom_name, it.level_name ] }
      end

      test "ED-61: without case nor accents, first name or last name first" do
        [ "AYA KOUASSI", "kouassi aya", "Aÿa", "  aya   kouassi " ].each { assert_includes names(it), "Aya Kouassi", it }
      end

      test "ED-62: never another school, a withdrawn student, an archived classroom nor an anonymized account" do
        create_student(classroom: create_classroom(name: "6ème 1"), first_name: "Ailleurs", last_name: "Kouassi")
        create_student(classroom: create_classroom(school: @school, name: "5ème 2", status: "archived", archived_at: 1.day.ago),
                       first_name: "Archivé", last_name: "Kouassi")
        withdrawn = create_student(classroom: @sixth, first_name: "Retiré", last_name: "Kouassi")
        Orm::ClassroomStudent.where(student: withdrawn).update_all(left_at: Time.current)
        create_student(classroom: @sixth, first_name: "Anonyme", last_name: "Kouassi").update_columns(anonymized_at: Time.current)
        create_teacher(school: @school, classrooms: [ @sixth ], first_name: "Prof", last_name: "Kouassi")

        assert_equal [ "Aya Kouassi", "Brou Kouassi" ], names("kouassi")
      end

      test "ED-63: under three letters, nothing is read" do
        assert_no_queries { assert_empty names("ko") }
        assert_no_queries { assert_empty names("  ko  ") }
        assert_not StudentSearchQuery.searchable?("ko")
        assert StudentSearchQuery.searchable?("kou")
      end

      test "ED-64: the limit bounds the rows read" do
        25.times { create_student(classroom: @sixth, first_name: "Élève #{it}", last_name: "Koné") }

        assert_equal 21, names("kone").size
        assert_equal 5, names("kone", limit: 5).size
      end

      test "ED-65: a phone number finds nobody, and no row carries one" do
        assert_empty names("0701020304")
        assert_equal %i[display_name classroom_public_id classroom_name level_name], StudentSearchQuery::Row.members
      end

      test "one query, whatever the number of students" do
        5.times { create_student(classroom: @sixth, first_name: "Élève", last_name: "Kouassi") }

        assert_queries_count(1) { names("kouassi") }
      end
    end
  end
end

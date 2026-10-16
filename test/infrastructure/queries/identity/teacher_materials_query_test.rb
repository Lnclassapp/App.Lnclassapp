require "test_helper"

module Queries
  module Identity
    # ADR-0103 §4.3, §4.5 (UDR-0127 §3.5): the subjects of a list of teachers, in one query, in the order of addition.
    class TeacherMaterialsQueryTest < ActiveSupport::TestCase
      setup do
        @pc = create_material(name: "Physique-Chimie", shortname: "PC")
        @svt = create_material(name: "SVT", shortname: "SVT")
        @school = create_school
        @query = TeacherMaterialsQuery.new
      end

      test "the subjects of each teacher in that school, in order, in one query for any number of teachers" do
        both = create_teacher(school: @school, materials: [ @pc, @svt ])
        one = create_teacher(school: @school, materials: [ @svt ])
        add_teacher_school(both, create_school, materials: [ @svt ])
        none = create_user(role: "teacher")

        tags = assert_queries_count(1) { @query.tags_for(teacher_ids: [ both.id, one.id, none.id ], school_id: @school.id) }

        assert_equal [ %w[Physique-Chimie PC], %w[SVT SVT] ], tags[both.id].map { [ it.name, it.shortname ] }
        assert_equal [ "SVT" ], tags[one.id].map(&:name)
        assert_equal [], tags[none.id]
        assert_equal({}, @query.tags_for(teacher_ids: [], school_id: @school.id))
      end

      test "without a school, all his lists, each subject once (a teacher with no attachment)" do
        teacher = create_teacher(school: @school, materials: [ @pc ])
        add_teacher_school(teacher, create_school, materials: [ @svt, @pc ], at: 1.minute.from_now)

        assert_equal %w[PC SVT], @query.for_pairs([ [ teacher.id, nil ] ])[[ teacher.id, nil ]].map(&:shortname)
      end

      test "the label: the name alone for one subject, the short names for several, nil for none" do
        tags = @query.tags_for(teacher_ids: [ create_teacher(school: @school, materials: [ @pc, @svt ]).id ], school_id: @school.id).values.first

        assert_equal "PC, SVT", TeacherMaterialsQuery.label(tags)
        assert_equal "Physique-Chimie", TeacherMaterialsQuery.label(tags.first(1))
        assert_nil TeacherMaterialsQuery.label([])
      end
    end
  end
end

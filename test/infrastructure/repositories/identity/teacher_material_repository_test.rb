require "test_helper"

module Repositories
  module Identity
    # ADR-0103 §4.3, §4.4: the subjects of a teacher in one school (the attachment teacher_schools), replaced as a whole,
    # inherited by a new attachment.
    class TeacherMaterialRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = TeacherMaterialRepository.new
        @pc, @svt, @maths = create_material(name: "Physique-Chimie"), create_material(name: "SVT"), create_material(name: "Mathématiques")
        @school = create_school
        @teacher = create_teacher(school: @school, materials: [ @pc ])
      end

      def ids(school = @school) = @repository.material_ids_for(teacher_id: @teacher.id, school_id: school.id)

      test "material_ids_for reads the list of that school only, in the order of addition" do
        other = create_school
        add_teacher_school(@teacher, other, materials: [ @svt, @maths ])

        assert_equal [ @pc.id ], ids
        assert_equal [ @svt.id, @maths.id ], ids(other)
        assert_equal [], @repository.material_ids_for(teacher_id: create_teacher.id, school_id: @school.id)
      end

      test "replace keeps the rank of the kept subjects, appends the new ones, drops the others" do
        @repository.replace(teacher_id: @teacher.id, school_id: @school.id, material_ids: [ @svt.id, @pc.id ], at: 1.minute.from_now)

        assert_equal [ @pc.id, @svt.id ], ids, "PC, déjà là, garde son rang"

        @repository.replace(teacher_id: @teacher.id, school_id: @school.id, material_ids: [ @svt.id, @maths.id ], at: 2.minutes.from_now)

        assert_equal [ @svt.id, @maths.id ], ids
      end

      test "replace writes the first subject twice, in teacher_profiles.material_id (ADR-0103 §4.6, until the lot Z)" do
        assert @repository.replace(teacher_id: @teacher.id, school_id: @school.id, material_ids: [ @maths.id ], at: Time.current)

        assert_equal @maths.id, @teacher.teacher_profile.reload.material_id
      end

      test "inherit gives a new school the list of the school it is added from" do
        other, third = create_school, create_school
        add_teacher_school(@teacher, other, materials: [ @svt, @maths ])
        Orm::TeacherSchool.create!(teacher: @teacher, school: third)

        assert @repository.inherit(teacher_id: @teacher.id, school_id: third.id, from_school_id: other.id, at: Time.current)
        assert_equal [ @svt.id, @maths.id ], ids(third)
      end

      test "inherit keeps a list already known for that school (a return), and falls back on the latest list" do
        back, fresh = create_school, create_school
        add_teacher_school(@teacher, back, materials: [ @maths ], at: 1.minute.from_now)
        @repository.inherit(teacher_id: @teacher.id, school_id: back.id, from_school_id: @school.id, at: Time.current)

        assert_equal [ @maths.id ], ids(back), "sa liste d'avant son départ revient"

        @repository.inherit(teacher_id: @teacher.id, school_id: fresh.id, from_school_id: nil, at: Time.current)

        assert_equal [ @maths.id ], ids(fresh), "sans établissement d'origine : sa dernière liste écrite"
      end

      test "inherit writes nothing for a teacher without any list" do
        pending = create_teacher(school: nil)

        assert @repository.inherit(teacher_id: pending.id, school_id: @school.id, from_school_id: nil, at: Time.current)
        assert_not Orm::TeacherSchoolMaterial.exists?(teacher_id: pending.id)
      end
    end
  end
end

require "test_helper"

module Queries
  module Catalog
    # CA-5 (UDR-0077 §3.2) : le catalogue de l'enseignant, ce sont sa matière et les niveaux de ses classes actives de l'année.
    class TeacherAudienceQueryTest < ActiveSupport::TestCase
      test "sa matière, et les (niveau, série) de ses classes actives de l'année ; ni archivée, ni d'une autre année, ni d'un collègue" do
        maths = create_material(name: "Mathématiques")
        tle = create_level(name: "Tle")
        d = create_series(name: "D")
        seconde = create_level(name: "2nde")
        classrooms = [ create_classroom(level: tle, series: d, name: "Tle D 1"), create_classroom(level: tle, series: d, name: "Tle D 2"),
                       create_classroom(level: seconde), create_classroom(level: create_level, status: "archived"),
                       create_classroom(level: create_level, school_year: current_school_year(on: 1.year.ago.to_date)) ]
        teacher = create_teacher(material: maths, classrooms:)
        create_teacher(classrooms: [ create_classroom(level: create_level) ])

        scope = TeacherAudienceQuery.new.call(teacher_id: teacher.id)

        assert_equal maths.id, scope.material_id
        assert_equal [ [ seconde.id, nil ], [ tle.id, d.id ] ].sort_by(&:first), scope.audience.pairs.sort_by(&:first)
      end

      test "sans classe de l'année : une audience vide, sa matière quand même" do
        svt = create_material(name: "SVT")

        scope = TeacherAudienceQuery.new.call(teacher_id: create_teacher(material: svt).id)

        assert scope.audience.empty?
        assert_equal svt.id, scope.material_id
      end
    end
  end
end

require "test_helper"

module Queries
  module Catalog
    # CA-5 (UDR-0077 §3.2) : le catalogue de l'enseignant, ce sont sa matière et les niveaux de ses classes actives de l'année.
    # ME-07 (ADR-0094 §4.6) : de l'établissement courant seulement.
    class TeacherAudienceQueryTest < ActiveSupport::TestCase
      setup { @school = create_school }

      def scope_of(teacher, school: @school) = TeacherAudienceQuery.new.call(teacher_id: teacher.id, school_id: school.id)

      test "sa matière, et les (niveau, série) de ses classes actives de l'année ; ni archivée, ni d'une autre année, ni d'un collègue" do
        maths = create_material(name: "Mathématiques")
        tle = create_level(name: "Tle")
        d = create_series(name: "D")
        seconde = create_level(name: "2nde")
        classrooms = [ create_classroom(school: @school, level: tle, series: d, name: "Tle D 1"),
                       create_classroom(school: @school, level: tle, series: d, name: "Tle D 2"),
                       create_classroom(school: @school, level: seconde),
                       create_classroom(school: @school, level: create_level, status: "archived"),
                       create_classroom(school: @school, level: create_level, school_year: current_school_year(on: 1.year.ago.to_date)) ]
        teacher = create_teacher(school: @school, material: maths, classrooms:)
        create_teacher(school: @school, classrooms: [ create_classroom(school: @school, level: create_level) ])

        scope = scope_of(teacher)

        assert_equal maths.id, scope.material_id
        assert_equal [ [ seconde.id, nil ], [ tle.id, d.id ] ].sort_by(&:first), scope.audience.pairs.sort_by(&:first)
      end

      test "les niveaux d'un autre de ses établissements ne comptent pas" do
        other = create_school
        sixth = create_level(name: "6ème")
        fifth = create_level(name: "5ème")
        teacher = create_teacher(school: @school, classrooms: [ create_classroom(school: @school, level: sixth),
                                                                 create_classroom(school: other, level: fifth) ])
        Orm::TeacherSchool.create!(teacher:, school: other, primary: false)

        assert_equal [ [ sixth.id, nil ] ], scope_of(teacher).audience.pairs
        assert_equal [ [ fifth.id, nil ] ], scope_of(teacher, school: other).audience.pairs
      end

      test "sans classe de l'année : une audience vide, sa matière quand même" do
        svt = create_material(name: "SVT")

        scope = scope_of(create_teacher(school: @school, material: svt))

        assert scope.audience.empty?
        assert_equal svt.id, scope.material_id
      end
    end
  end
end

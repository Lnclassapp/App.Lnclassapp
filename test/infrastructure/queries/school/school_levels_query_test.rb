require "test_helper"

# IL-04, IL-06 (ADR-0085 §4.2, UDR-0081 §3.3): the levels list of the cascade. Only the levels where an active school has
# an active classroom of the current school year, in the order of the referential; never a classroom, a headcount nor a
# teacher.
class Queries::School::SchoolLevelsQueryTest < ActiveSupport::TestCase
  setup do
    @school = create_school(name: "Lycée Moderne de Cocody")
    @troisieme = create_level(name: "3ème", position: 4)
    @sixieme = create_level(name: "6ème", position: 1)
    @seconde = create_level(name: "2nde", position: 5)
    create_classroom(school: @school, level: @troisieme, name: "3e 2")
    create_classroom(school: @school, level: @troisieme, name: "3e 1")
    create_classroom(school: @school, level: @sixieme, name: "6e 1")
  end

  def levels(public_id = @school.public_id, **options) = Queries::School::SchoolLevelsQuery.new.call(school_public_id: public_id, **options)

  test "IL-04: the levels with an active classroom this year, once each, in the referential's order" do
    assert_equal [ [ @sixieme.slug, "6ème" ], [ @troisieme.slug, "3ème" ] ], levels.map { [ it.slug, it.name ] }
  end

  test "IL-04: the row names the level and nothing else" do
    assert_equal %i[slug name], Queries::School::SchoolLevelsQuery::Row.members
  end

  test "IL-06: a level whose classrooms are archived, or of another year, or of another school, is not offered" do
    create_classroom(school: @school, level: @seconde, status: "archived")
    create_classroom(school: @school, level: @seconde, school_year: "2020-2021")
    create_classroom(school: create_school, level: @seconde)

    assert_not_includes levels.map(&:slug), @seconde.slug
  end

  test "IL-06: a school without an active classroom gives no level" do
    assert_empty levels(create_school.public_id)
  end

  test "ADR-0085 §4.2: a draft or inactive school, or an unknown one, gives no level" do
    assert_empty levels("sch-inconnu")
    assert_empty levels(nil)

    %w[draft inactive].each do |status|
      @school.update!(status:)

      assert_empty levels, status
    end
  end

  test "the school year can be given" do
    create_classroom(school: @school, level: @seconde, school_year: "2020-2021")

    assert_equal [ @seconde.slug ], levels(school_year: "2020-2021").map(&:slug)
  end
end

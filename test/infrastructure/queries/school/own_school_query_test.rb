require "test_helper"

# ADR-0071 §4.6 : la page « Établissement » de la direction lit son établissement, par l'identifiant de son compte.
class Queries::School::OwnSchoolQueryTest < ActiveSupport::TestCase
  def own(school_id) = Queries::School::OwnSchoolQuery.new.call(school_id:)

  test "gives the public id, name, type, status and school code of the school, whatever its status" do
    school = create_school(name: "Lycée Moderne de Bouaké", school_type: "private", status: "inactive", school_code: "k7m4qz")
    create_school(name: "Lycée Classique d'Abidjan")

    row = own(school.id)

    assert_equal [ school.public_id, "Lycée Moderne de Bouaké", "private", "inactive", "k7m4qz" ],
                 [ row.public_id, row.name, row.school_type, row.status, row.school_code ]
    assert_not_predicate row, :active?
    assert_predicate own(create_school(status: "active").id), :active?
  end

  test "reads nothing else: no identifier of the database, no teacher, no headcount" do
    assert_equal %i[public_id name school_type status school_code direction_invite_token], Queries::School::OwnSchoolQuery::Row.members
  end

  test "an unknown or missing school gives nil, in one query at most" do
    school_id = create_school.id

    assert_nil own(0)
    assert_queries_count(0) { assert_nil own(nil) }
    assert_queries_count(1) { own(school_id) }
  end
end

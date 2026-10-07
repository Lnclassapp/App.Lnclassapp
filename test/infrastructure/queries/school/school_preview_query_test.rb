require "test_helper"

# IE-06, IE-09 (ADR-0083 §4.1, UDR-0079 §3.6): the banner of an invite link names the school and its DRENA, nothing
# more, and only for an active school.
class Queries::School::SchoolPreviewQueryTest < ActiveSupport::TestCase
  setup do
    @school = create_school(drena: create_drena(name: "Abidjan 1"), name: "Lycée Moderne de Cocody")
  end

  def preview(school_id) = Queries::School::SchoolPreviewQuery.new.call(school_id:)

  test "an active school gives its name and the name of its DRENA" do
    row = preview(@school.id)

    assert_equal [ "Lycée Moderne de Cocody", "Abidjan 1" ], [ row.school_name, row.drena_name ]
  end

  test "the row reveals no identifier, no code, no headcount and no teacher" do
    assert_equal %i[school_name drena_name], Queries::School::SchoolPreviewQuery::Row.members
  end

  test "an inactive or draft school gives nil, like an unknown one" do
    assert_nil preview(0)
    assert_nil preview(nil)

    %w[inactive draft].each do |status|
      @school.update!(status:)

      assert_nil preview(@school.id), status
    end
  end
end

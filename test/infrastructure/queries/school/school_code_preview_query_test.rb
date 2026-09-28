require "test_helper"

# CE-02, CE-03 (ADR-0057, UDR-0044): the preview of /e/<code> names the school and its DRENA, nothing more, and only
# for an active school.
class Queries::School::SchoolCodePreviewQueryTest < ActiveSupport::TestCase
  setup do
    @school = create_school(drena: create_drena(name: "Abidjan 1"), name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
  end

  def preview(code) = Queries::School::SchoolCodePreviewQuery.new.call(code:)

  test "the code, typed in any case, with spaces or a hyphen, gives the school and DRENA names" do
    row = preview(" K7M-4qz ")

    assert_equal [ "Lycée Classique d'Abidjan", "Abidjan 1" ], [ row.school_name, row.drena_name ]
  end

  test "the row reveals no identifier, no headcount and no teacher" do
    create_teacher(school: @school)

    assert_equal %i[school_name drena_name], Queries::School::SchoolCodePreviewQuery::Row.members
  end

  test "an unknown, blank, malformed or replaced code gives nil" do
    assert_nil preview("zzz999")
    assert_nil preview("")
    assert_nil preview(nil)
    assert_nil preview("k7m4qz'--")

    @school.update!(school_code: "abc234")

    assert_nil preview("k7m4qz")
  end

  test "the code of an inactive or draft school gives nil, like an unknown one" do
    %w[inactive draft].each do |status|
      @school.update!(status:)

      assert_nil preview("k7m4qz"), status
    end
  end
end

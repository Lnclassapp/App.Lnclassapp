require "test_helper"

# ADR-0094 §4.1 : trois établissements au plus par enseignant.
class Entities::School::TeacherSchoolsTest < ActiveSupport::TestCase
  test "a teacher has three schools at most" do
    assert_equal 3, Entities::School::TeacherSchools::MAX
  end
end

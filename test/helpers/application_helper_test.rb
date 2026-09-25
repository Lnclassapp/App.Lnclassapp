require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "the shared helpers are available to every view" do
    assert_includes self.class.ancestors, ApplicationHelper
    assert_kind_of Module, HomepageHelper
  end
end

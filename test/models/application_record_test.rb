require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "is the abstract primary class every Orm model inherits from" do
    assert ApplicationRecord.abstract_class?
    assert ApplicationRecord.primary_class?
  end
end

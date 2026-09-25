require "test_helper"

# ADR-0050 : the PIN is stored by bcrypt and never shows, not even in inspect or logs.
class Orm::UserTest < ActiveSupport::TestCase
  def create_student = Orm::User.create!(last_name: "Kouassi", first_name: "Jean Marc", contact: "0701020304",
                                          gender: "male", role: "student", pin: "1234")

  test "the PIN is stored as a bcrypt digest and authenticates" do
    user = create_student

    assert user.pin_digest.start_with?("$2")
    assert_equal user, user.authenticate_pin("1234")
    assert_not user.authenticate_pin("4321")
  end

  test "neither the PIN nor its digest appear in inspect" do
    user = create_student

    assert_not_includes user.inspect, user.pin_digest
    assert_includes user.inspect, "pin_digest: [FILTERED]"
  end

  test "a PIN is required at creation" do
    user = Orm::User.new(last_name: "Kouassi", first_name: "Jean", gender: "male", role: "student")

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :pin
  end

  test "the public_id is generated and used as URL parameter" do
    user = create_student

    assert_equal 14, user.public_id.length
    assert_equal user.public_id, user.to_param
  end
end

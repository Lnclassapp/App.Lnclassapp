require "test_helper"

# ADR-0029 : an opaque 14 character base58 public_id, generated once, used in URLs.
class Orm::HasPublicIdTest < ActiveSupport::TestCase
  def build_drena(**attributes) = Orm::Drena.new(name: "Abidjan 1", **attributes)

  test "a public_id of 14 base58 characters is generated at creation" do
    drena = build_drena
    drena.save!

    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{14}\z/, drena.public_id)
  end

  test "a public_id given at creation is kept" do
    drena = build_drena(public_id: "abcdefghijkmno")
    drena.save!

    assert_equal "abcdefghijkmno", drena.reload.public_id
  end

  test "a public_id of the wrong length is refused" do
    drena = build_drena(public_id: "short")

    assert_not drena.valid?
    assert_includes drena.errors.attribute_names, :public_id
  end

  test "the public_id is the URL parameter, never the numeric id" do
    school = Orm::School.new(public_id: "abcdefghijkmno")

    assert_equal "abcdefghijkmno", school.to_param
  end
end

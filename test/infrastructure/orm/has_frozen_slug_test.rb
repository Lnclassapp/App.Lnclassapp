require "test_helper"

# ADR-0029 : a slug derived from the name at creation, suffixed on collision, frozen afterwards.
class Orm::HasFrozenSlugTest < ActiveSupport::TestCase
  def create_level(name, position) = Orm::Level.create!(name:, position:, cycle: "first")

  test "the slug is the parameterized name" do
    assert_equal "6eme", create_level("6ème", 1).slug
  end

  test "a collision is suffixed -2, then -3" do
    create_level("Tle", 1)

    assert_equal "tle-2", create_level("TLE", 2).slug
    assert_equal "tle-3", create_level("tle ", 3).slug
  end

  test "a name without any latin letter falls back on the model name" do
    assert_equal "level", create_level("π", 1).slug
    assert_equal "level-2", create_level("???", 2).slug
  end

  test "renaming never changes the slug" do
    level = create_level("2nde", 1)
    level.update!(name: "Seconde")

    assert_equal "2nde", level.reload.slug
  end

  test "the slug is the URL parameter" do
    assert_equal "6eme", create_level("6ème", 1).to_param
  end

  test "a record without a name has no slug and is refused" do
    level = Orm::Level.new(position: 1, cycle: "first")

    assert_not level.valid?
    assert_includes level.errors.attribute_names, :slug
  end

  test "an essential sheet slug comes from its course name, then its own" do
    author = Orm::User.create!(last_name: "Koné", first_name: "Awa", gender: "female", role: "team", team_role: "admin", pin: "1234")
    course = Orm::Course.create!(name: "Nombres complexes", level: create_level("Tle", 1), author:,
                                 material: Orm::Material.create!(name: "Mathématiques", shortname: "Maths", category: "science"))
    essential = Orm::Essential.create!(course:, name: "Forme algébrique", position: 1, author:)

    assert_equal "nombres-complexes-forme-algebrique", essential.slug
  end

  test "an essential sheet without course is refused, not crashed" do
    essential = Orm::Essential.new(name: "Forme algébrique", position: 1)

    assert_not essential.valid?
    assert_equal "forme-algebrique", essential.slug
    assert_includes essential.errors.attribute_names, :course
  end

  # ADR-0055: the DRENA slug is the domain rule, prefixed drena-, never the model name.
  test "a DRENA keeps its public_id in URLs, its slug is the import target" do
    drena = Orm::Drena.create!(name: "Abidjan 1")

    assert_equal "drena-abidjan-1", drena.slug
    assert_equal drena.public_id, drena.to_param
    assert_equal "drena-abidjan-1-2", Orm::Drena.create!(name: "Abidjan-1").slug
  end

  test "a DRENA without any latin letter or digit gets no slug and is refused" do
    drena = Orm::Drena.new(name: "???")

    assert_not drena.valid?
    assert_nil drena.slug
    assert_includes drena.errors.attribute_names, :slug
  end
end

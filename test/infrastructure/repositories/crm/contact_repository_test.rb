require "test_helper"

# Lot B: contacts of a school, by name; removal is archiving, and an archived contact leaves the choices but not the history.
class Repositories::Crm::ContactRepositoryTest < ActiveSupport::TestCase
  setup do
    @school = create_school
    @author = create_team_member(team_role: "field")
    @repo = Repositories::Crm::ContactRepository.new
  end

  def entity(**overrides)
    Entities::Crm::Contact.new(**{ public_id: nil, school_id: @school.id, full_name: "Mme Kouassi", position: "director", phone: "0701020304",
                                   note: nil, created_by_id: @author.id, archived_at: nil }.merge(overrides))
  end

  test "create stores the contact and returns it with its public id" do
    result = @repo.create(contact: entity)

    assert result.success?
    assert_predicate result.value.public_id, :present?
    assert_equal "Mme Kouassi", @repo.find_by_public_id(public_id: result.value.public_id).full_name
  end

  test "a malformed phone number is :invalid and nothing is written" do
    result = @repo.create(contact: entity(phone: "12345"))

    assert_equal :invalid, result.code
    assert_equal [ :invalid ], result.errors[:phone]
    assert_equal 0, Orm::CrmContact.count
  end

  test "active_for_school lists this school's non-archived contacts by name" do
    @repo.create(contact: entity(full_name: "Zoé"))
    @repo.create(contact: entity(full_name: "Aya"))
    gone = @repo.create(contact: entity(full_name: "Bamba")).value
    @repo.create(contact: entity(full_name: "Autre école", school_id: create_school.id))
    @repo.archive(public_id: gone.public_id, at: Time.current)

    assert_equal %w[Aya Zoé], @repo.active_for_school(school_id: @school.id).map(&:full_name)
  end

  test "archive stamps once; archiving again keeps the first instant; an unknown id is :not_found" do
    contact = @repo.create(contact: entity).value
    first = Time.utc(2026, 11, 6, 9)

    assert @repo.archive(public_id: contact.public_id, at: first).value.archived?
    again = @repo.archive(public_id: contact.public_id, at: first + 1.day)

    assert again.success?
    assert_equal first, again.value.archived_at
    assert_equal :not_found, @repo.archive(public_id: "nope", at: first).code
    assert_nil @repo.find_by_public_id(public_id: "nope")
  end
end

require "test_helper"

# ADR-0034: the seeds fill development and test with the referential, the DRENA and a few schools; production
# only gets the bootstrap invitation of the first team member.
class SeedsTest < ActiveSupport::TestCase
  TABLES = [ Orm::Drena, Orm::School, Orm::Classroom, Orm::Level, Orm::Series, Orm::LevelSeries, Orm::ClassroomPlanEntry,
             Orm::Material, Orm::User, Orm::Invitation ].freeze

  def counts = TABLES.to_h { [ it.name, it.count ] }

  # Wrapped: SEEDS is defined in an anonymous module, not once per run at the top level.
  def run_seeds
    capture_io { load Rails.root.join("db/seeds.rb").to_s, true }.first
  end

  def as_production
    Rails.env = "production"
    yield
  ensure
    Rails.env = "test"
  end

  def with_bootstrap_contact(contact)
    previous = ENV["TEAM_BOOTSTRAP_CONTACT"]
    ENV["TEAM_BOOTSTRAP_CONTACT"] = contact
    yield
  ensure
    ENV["TEAM_BOOTSTRAP_CONTACT"] = previous
  end

  test "in test, the referential, the 41 DRENA and four schools with their generated classrooms" do
    run_seeds

    assert_equal 41, Orm::Drena.count
    assert_equal %w[6eme 5eme 4eme 3eme 2nde 1ere tle], Orm::Level.order(:position).pluck(:slug)
    assert_equal 10, Orm::LevelSeries.count
    assert_equal 28, Orm::ClassroomPlanEntry.count
    assert_equal %w[literature literature literature literature science science science], Orm::Material.order(:category).pluck(:category)
    assert_equal({ "Lycée Moderne de Treichville" => 77, "Lycée privé Les Lauriers" => 38, "Lycée mixte La Réussite" => 38,
                   "Collège Moderne de Marcory" => 28 },
                 Orm::School.joins(:classrooms).group(:name).count)
    assert_equal "abidjan-2", Orm::School.first.drena.slug
    assert_equal 0, Orm::User.count
  end

  test "two runs give the same counts" do
    run_seeds
    first = counts

    run_seeds

    assert_equal first, counts
  end

  test "production gets neither DRENA, nor school, nor referential" do
    before = counts

    as_production { run_seeds }

    assert_equal before, counts
  end

  test "the development and test files refuse to run in production" do
    as_production do
      %w[catalog school development].each do |name|
        error = assert_raises(RuntimeError) { load Rails.root.join("db/seeds/#{name}.rb").to_s, true }
        assert_match "db/seeds/#{name}.rb est réservé", error.message
      end
    end
  end

  test "the development accounts are never seeded in test" do
    error = assert_raises(RuntimeError) { load Rails.root.join("db/seeds/development.rb").to_s, true }

    assert_match "réservé au développement", error.message
  end

  test "without a team account, the bootstrap contact receives one admin invitation, whose link is printed" do
    output = with_bootstrap_contact("0700000042") { as_production { run_seeds } }

    invitation = Orm::Invitation.sole
    token = output[%r{/invitations/(\w+)}, 1]
    assert_equal [ "team", "0700000042", "admin", nil ], invitation.values_at(:kind, :contact, :team_role, :invited_by_id)
    assert_equal secret_digest(token), invitation.token_digest
    assert_in_delta 72.hours.from_now, invitation.expires_at, 5
  end

  # The link lives only in the pre-deploy logs, which Railway may cut when the container stops: a later run revokes the
  # open invitation and prints a new link, so a lost link never locks the platform out.
  test "a later run revokes the open bootstrap invitation and prints a new link" do
    first = with_bootstrap_contact("0700000042") { as_production { run_seeds } }[%r{/invitations/(\w+)}, 1]

    again = with_bootstrap_contact("0700000042") { as_production { run_seeds } }[%r{/invitations/(\w+)}, 1]

    assert_not_equal first, again
    assert_equal [ secret_digest(again) ], Orm::Invitation.where(revoked_at: nil).pluck(:token_digest)
    assert_equal 2, Orm::Invitation.count
  end

  test "an expired bootstrap invitation is revoked and replaced" do
    expired = create_invitation(kind: "team", contact: "0700000042", team_role: "admin", expires_at: 1.hour.ago)

    output = with_bootstrap_contact("0700000042") { run_seeds }

    assert_not_nil expired.reload.revoked_at
    assert_equal 2, Orm::Invitation.count
    assert_match "/invitations/", output
  end

  test "no bootstrap invitation once a team account exists, or without a contact" do
    with_bootstrap_contact(nil) { run_seeds }
    assert_equal 0, Orm::Invitation.count

    create_team_member(second_factor: false)
    with_bootstrap_contact("0700000042") { run_seeds }
    assert_equal 0, Orm::Invitation.count
  end
end

require "test_helper"

module UseCases
  module Communication
    # AN-15, AN-19, ADR-0078 §4.2: its author archives a draft, a scheduled or a published announcement; it then
    # disappears for everyone else and is frozen. Anyone else, the team and the direction included, gets not_found.
    class ArchiveMessageTest < ActiveSupport::TestCase
      # Reads the announcement, then lets another request change it before the use case writes (ADR-0078 §4.2).
      class Racing < SimpleDelegator
        def initialize(repository, &race) = super(repository).tap { @race = race }
        def find_by_public_id(public_id:) = __getobj__.find_by_public_id(public_id:).tap { @race.call }
      end

      setup do
        @lauriers = create_school(name: "Collège Les Lauriers")
        @kamate = create_school_admin(school: @lauriers, last_name: "Kamaté")
      end

      def actor(user) = Repositories::Identity::UserRepository.new.actor_for(user_id: user.id)

      def archive(user, message, messages: Repositories::Communication::MessageRepository.new)
        ArchiveMessage.new(messages:, policy: Policies::Communication::ManageOwnPolicy.new)
                      .call(actor: actor(user), public_id: message.public_id)
      end

      test "ADR-0078 §4.2 — withdrawn while its author was archiving it, it stays withdrawn: conflict" do
        message = create_message(author: @kamate)
        team = create_team_member(second_factor: false)
        racing = Racing.new(Repositories::Communication::MessageRepository.new) do
          Orm::Message.where(id: message.id).update_all(status: "withdrawn", withdrawn_at: Time.current, withdrawn_by_id: team.id)
        end

        assert_equal :conflict, archive(@kamate, message, messages: racing).code
        assert_equal [ "withdrawn", team.id ], message.reload.values_at(:status, :withdrawn_by_id)
      end

      test "AN-19 — its author archives a published, a scheduled and a draft announcement" do
        messages = [ create_message(author: @kamate), create_message(author: @kamate, status: "scheduled", published_at: 2.days.from_now),
                     create_message(author: @kamate, status: "draft", published_at: nil) ]

        messages.each do |message|
          result = archive(@kamate, message)

          assert result.success?, message.status
          assert_equal "archived", result.value.status
        end
        assert_equal %w[archived archived archived], messages.map { it.reload.status }
        assert_nil messages.last.ends_at, "un brouillon s'archive sans date de fin"
      end

      test "AN-19 — archived, it cannot be archived again" do
        message = create_message(author: @kamate, status: "archived")

        assert_equal :conflict, archive(@kamate, message).code
      end

      test "AN-15 — another direction, the team and a teacher receive not_found; the announcement is unchanged" do
        message = create_message(author: @kamate)

        [ create_school_admin(school: @lauriers), create_team_member(second_factor: false), create_teacher(school: @lauriers) ].each do |other|
          assert_equal :not_found, archive(other, message).code, other.role
        end
        assert_equal "published", message.reload.status
      end

      test "an unknown announcement is not_found" do
        assert_equal :not_found, archive(@kamate, Orm::Message.new(public_id: "inconnue")).code
      end
    end
  end
end

require "test_helper"

# ADR-XXXX (contexte crm) : le journal est en ajout seul ; les échanges se relisent du plus récent au plus ancien, par pages.
module Repositories
  module Crm
    class InteractionRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = InteractionRepository.new
        @school = create_school
        @author = create_team_member(team_role: "field")
      end

      def interaction(**overrides)
        Entities::Crm::Interaction.new(public_id: nil, school_id: @school.id, author_id: @author.id, kind: "call",
                                       occurred_at: Time.utc(2026, 11, 5, 9), contact_id: nil, contact_name: "Mme Kouassi",
                                       outcome: "positive", next_step: "Envoyer la plaquette", note: "Intéressée", source: "manual",
                                       **overrides)
      end

      def create_crm_contact(school)
        Orm::CrmContact.create!(school:, full_name: "Mme Kouassi", position: "director", created_by: @author)
      end

      test "create writes the interaction and returns it with its public id" do
        result = @repository.create(interaction:)

        assert result.success?
        created = result.value
        assert_equal 14, created.public_id.length
        assert_equal [ @school.id, @author.id, "call", "positive", "Mme Kouassi", "Envoyer la plaquette", "Intéressée", "manual" ],
                     [ created.school_id, created.author_id, created.kind, created.outcome, created.contact_name, created.next_step,
                       created.note, created.source ]
      end

      test "create links the contact chosen by public id" do
        contact = create_crm_contact(@school)

        created = @repository.create(interaction:, contact_public_id: contact.public_id).value

        assert_equal contact.id, created.contact_id
        assert_equal contact.id, Orm::CrmInteraction.find_by!(public_id: created.public_id).contact_id
      end

      test "create refuses an unknown contact public id, or a contact of another school, and writes nothing" do
        other_contact = create_crm_contact(create_school)

        [ "unknown-public", other_contact.public_id ].each do |public_id|
          result = @repository.create(interaction:, contact_public_id: public_id)

          assert result.failure?
          assert_equal :not_found, result.code
        end
        assert_equal 0, Orm::CrmInteraction.count
      end

      test "recent_for_school lists newest first, only this school, and pages with limit and offset" do
        other = create_school
        3.times { |i| @repository.create(interaction: interaction(occurred_at: Time.utc(2026, 11, 1 + i), note: "n#{i}")) }
        @repository.create(interaction: interaction(school_id: other.id, note: "ailleurs"))

        assert_equal %w[n2 n1 n0], @repository.recent_for_school(school_id: @school.id, limit: 20, offset: 0).map(&:note)
        assert_equal %w[n1], @repository.recent_for_school(school_id: @school.id, limit: 1, offset: 1).map(&:note)
        assert_empty @repository.recent_for_school(school_id: @school.id, limit: 20, offset: 3)
      end

      test "the adapter offers no way to change or delete an interaction (CA-12)" do
        assert_empty %i[update destroy delete save update!].select { @repository.respond_to?(it) }
      end
    end
  end
end

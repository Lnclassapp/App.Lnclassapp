require "test_helper"

# ADR-XXXX (modèles de langage, « Données envoyées ») : les faits d'une relance, sans nom de contact ni numéro.
module Queries
  module Crm
    class WhatsappDraftInputsQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @user = create_team_member(team_role: "field")
      end

      test "R2: a contact's full name and a phone number in a note, next step or reason never reach the messages" do
        Orm::CrmContact.create!(school: @school, full_name: "Mme Kouassi Ahou", position: "director", created_by: @user)
        Orm::CrmInteraction.create!(school: @school, author: @user, kind: "call", occurred_at: 1.day.ago, outcome: "positive",
                                    note: "Kouassi Ahou au 07 01 02 03 04", next_step: "Rappeler Ahou au +225 05 11 22 33 44")
        follow_up = Orm::CrmFollowUp.create!(school: @school, assignee: @user, created_by: @user, due_on: Date.current + 1,
                                             reason: "Appeler Mme Kouassi Ahou (0701020304)")

        content = WhatsappDraftInputsQuery.new.call(public_id: follow_up.public_id).messages.map { it[:content] }.join("\n")

        %w[Kouassi Ahou 0701020304 11\ 22\ 33\ 44].each { assert_not_includes content, it }
        assert_includes content, "[numéro]"
        assert_includes content, "[contact]"
      end
    end
  end
end

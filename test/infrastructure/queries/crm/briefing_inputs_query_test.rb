require "test_helper"

# ADR-XXXX (modèles de langage, « Données envoyées ») : les faits d'une école, sans nom d'élève ni de contact ; requêtes en nombre constant.
module Queries
  module Crm
    class BriefingInputsQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school(name: "Lycée Classique d'Abidjan", drena: create_drena(name: "Abidjan 1"))
        @user = create_team_member(team_role: "field")
      end

      def interaction(note:, at:)
        Orm::CrmInteraction.create!(school: @school, author: @user, kind: "call", occurred_at: at, outcome: "positive", note:, next_step: "Devis")
      end

      test "an unknown school is nil, by public_id or id" do
        assert_nil BriefingInputsQuery.new.call(public_id: "unknown-public")
        assert_nil BriefingInputsQuery.new.call(school_id: 0)
      end

      test "the school, its DRENA, the computed stage and the usage" do
        Orm::CrmAccount.create!(school: @school, stage: "demo_done", stage_changed_at: Time.current)

        prompt = BriefingInputsQuery.new.call(public_id: @school.public_id)

        assert_equal [ @school.id, "Lycée Classique d'Abidjan", "Abidjan 1", "demo_done" ],
                     prompt.to_h.values_at(:school_id, :school_name, :drena_name, :stage)
        assert_equal prompt, BriefingInputsQuery.new.call(school_id: @school.id)
      end

      test "the five latest exchanges, the open follow-ups and the contact positions, no names or phones" do
        7.times { |index| interaction(note: "Échange #{index}", at: (index + 1).days.ago) }
        Orm::CrmFollowUp.create!(school: @school, assignee: @user, created_by: @user, due_on: Date.current + 2, reason: "Rappeler")
        Orm::CrmFollowUp.create!(school: @school, assignee: @user, created_by: @user, due_on: Date.current, reason: "Faite", status: "done",
                                 done_at: Time.current, done_by: @user)
        Orm::CrmContact.create!(school: @school, full_name: "Mme Kouassi", position: "director", phone: "0701020304", created_by: @user)
        Orm::CrmContact.create!(school: @school, full_name: "Archivée", position: "censor", created_by: @user, archived_at: Time.current)

        prompt = BriefingInputsQuery.new.call(public_id: @school.public_id)

        assert_equal (0..4).map { "Échange #{it}" }, prompt.interactions.map { it[:note] }
        assert_equal [ "Rappeler" ], prompt.follow_ups.map { it[:reason] }
        assert_equal [ "director" ], prompt.contact_positions
        assert_not_includes prompt.messages.last[:content], "Kouassi"
      end

      test "the number of queries does not depend on the number of exchanges" do
        count = ->(&block) { n = 0; counter = ->(*, payload) { n += 1 unless payload[:name] == "SCHEMA" }; ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block); n }
        interaction(note: "Un", at: 1.day.ago)
        few = count.call { BriefingInputsQuery.new.call(school_id: @school.id) }
        6.times { interaction(note: "Plus", at: 2.days.ago) }

        assert_equal few, count.call { BriefingInputsQuery.new.call(school_id: @school.id) }
      end
    end
  end
end

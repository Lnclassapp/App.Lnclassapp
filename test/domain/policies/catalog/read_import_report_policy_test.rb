require "test_helper"

module Policies
  module Catalog
    class ReadImportReportPolicyTest < ActiveSupport::TestCase
      test "autorise l'équipe" do
        assert ReadImportReportPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :team, team_role: "content")).success?
      end

      test "refuse élève, enseignant, direction et anonyme" do
        %i[student teacher school_admin].each do |role|
          assert_equal :forbidden, ReadImportReportPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:)).code
        end
        assert_equal :forbidden, ReadImportReportPolicy.new.call(actor: nil).code
      end
    end
  end
end

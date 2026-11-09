require "test_helper"

module Policies
  module Catalog
    class ReadOwnMaterialPolicyTest < ActiveSupport::TestCase
      def call(role, slugs: [ "maths" ], material_slug: "maths")
        actor = Entities::Identity::Actor.new(user_id: 1, role:, school_id: 5)
        ReadOwnMaterialPolicy.new.call(actor:, own_material_slugs: slugs, material_slug:)
      end

      test "un enseignant lit une leçon de l'une de ses matières" do
        assert call(:teacher, slugs: %w[maths pc]).success?
      end

      test "un enseignant ne lit pas une leçon hors de ses matières ni sans matière : not_found" do
        assert_equal :not_found, call(:teacher, material_slug: "svt").code
        assert_equal :not_found, call(:teacher, slugs: []).code
        assert_equal :not_found, call(:teacher, material_slug: nil).code
      end

      test "direction, équipe et élève ne sont pas concernés" do
        %i[school_admin team student].each { assert call(it, slugs: [], material_slug: "svt").success?, it }
      end

      test "un visiteur est refusé" do
        assert_equal :forbidden, ReadOwnMaterialPolicy.new.call(actor: nil, own_material_slugs: [], material_slug: "maths").code
      end
    end
  end
end

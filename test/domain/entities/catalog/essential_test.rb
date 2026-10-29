require "test_helper"

module Entities
  module Catalog
    class EssentialTest < ActiveSupport::TestCase
      def build(**overrides)
        Essential.new(name: " Mitose ", subtitle: " La division ", course_id: 1, position: 1, status: "published",
                      course_status: "published", **overrides)
      end

      test "une fiche complète est valide" do
        assert build.valid?
        assert_equal "Mitose", build.name
        assert_equal "La division", build.subtitle
        assert_nil build(subtitle: nil).subtitle
      end

      test "exige nom borné, cours et statut connu" do
        assert build(name: "").invalid?
        assert build(name: nil).invalid?
        assert build(name: "a" * 151).invalid?
        assert build(subtitle: "a" * 151).invalid?
        assert build(course_id: nil).invalid?
        assert build(status: "brouillon").invalid?
      end

      test "lisible seulement si elle et son cours sont publiés" do
        assert build.readable_chain_published?
        assert_not build(course_status: "draft").readable_chain_published?
        assert_not build(status: "archived").readable_chain_published?
      end
    end
  end
end

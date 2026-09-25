require "test_helper"

module Entities
  module Catalog
    class CourseTest < ActiveSupport::TestCase
      def build(**overrides)
        Course.new(name: "  Génétique   humaine ", subtitle: " ", level_id: 1, material_id: 2, status: "draft", **overrides)
      end

      test "garde la casse du nom après squish" do
        course = build(name: " SVT  et génétique ")

        assert course.valid?
        assert_equal "SVT et génétique", course.name
        assert_nil course.subtitle
        assert_nil build(subtitle: nil).subtitle
      end

      test "exige nom, niveau, matière et statut connu" do
        assert build(name: nil).invalid?
        assert build(name: "a" * 201).invalid?
        assert build(subtitle: "a" * 151).invalid?
        assert build(level_id: nil).invalid?
        assert build(material_id: nil).invalid?
        assert build(status: "publié").invalid?
      end

      test "sa chaîne est publiée s'il l'est" do
        assert build(status: "published").readable_chain_published?
        assert_not build.readable_chain_published?
      end
    end
  end
end

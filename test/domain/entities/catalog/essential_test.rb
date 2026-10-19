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

      # ADR-0104 §4.3-§4.4 : emplacements restants et images sans texte de remplacement empêchent de publier.
      test "image_publish_errors" do
        image = ->(id, alt) { Entities::Shared::ContentImage.new(public_id: id, alt:) }

        assert_empty build(content: "<p>Texte</p>").image_publish_errors
        assert_equal({ image_slots_left: 2 }, build(content: "<p>[[image: a]]</p><p>[[image: b]]</p>").image_publish_errors)
        assert_equal({ image_slots_malformed: 1, image_slots_left: 1 },
                     build(content: "<p>[[image: a]]</p><ul><li>[[image: b]]</li></ul>").image_publish_errors)
        with_images = build(content: "<p>x</p>")
        with_images.images = [ image.("ok", "Une pile"), image.("ko", "") ]
        assert_equal({ image_alts_blank: [ "ko" ] }, with_images.image_publish_errors)
        assert_empty build.images
      end
    end
  end
end

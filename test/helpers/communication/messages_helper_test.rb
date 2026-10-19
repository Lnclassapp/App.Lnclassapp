require "test_helper"

module Communication
  # UDR-0071 §3.2: the signature of a card. The team signs « Lnclass »; a teacher « M. Kouassi · SVT » (civility from the
  # gender, last name, subject); a direction « Mme Kamaté · Direction ». An anonymized author keeps their function alone.
  class MessagesHelperTest < ActionView::TestCase
    Card = Queries::Communication::InboxQuery::MessageCard
    Tag = Queries::Identity::TeacherMaterialsQuery::MaterialTag
    SVT = Tag.new(id: 1, name: "SVT", shortname: "SVT", category: "science", slug: "svt")
    PC = Tag.new(id: 2, name: "Physique-Chimie", shortname: "PC", category: "science", slug: "physique-chimie")

    def card(author_role:, gender: "male", last_name: "Kouassi", material_name: nil, anonymized: false, materials: nil)
      materials ||= material_name ? [ Tag.new(id: 9, name: material_name, shortname: material_name, category: "science", slug: "x") ] : []
      Card.new(public_id: "msg", title: "Nouvelles fiches", body: "En ligne.", illustration: "sheets", author_role:, gender:,
               last_name:, materials:, anonymized:, official: author_role == :school_admin, image: false, audio: false,
               edited: false, dismissed: false)
    end

    test "AN-01 — the team signs « Lnclass »" do
      assert_equal "Lnclass", announcement_signature(card(author_role: :team, last_name: "Traoré"))
    end

    test "AN-05 — a teacher signs with civility, last name and subject" do
      assert_equal "M. Kouassi · SVT", announcement_signature(card(author_role: :teacher, material_name: "SVT"))
      assert_equal "Mme Bamba · Français",
                   announcement_signature(card(author_role: :teacher, gender: "female", last_name: "Bamba", material_name: "Français"))
    end

    # EPM-21 (UDR-0127 §3.4) : plusieurs matières, les noms courts dans l'ordre ; anonymisé, la fonction seule.
    test "EPM-21 — a teacher of two subjects signs with their short names, in order" do
      assert_equal "M. Kouassi · PC, SVT", announcement_signature(card(author_role: :teacher, materials: [ PC, SVT ]))
      assert_equal "PC, SVT", announcement_signature(card(author_role: :teacher, materials: [ PC, SVT ], anonymized: true))
    end

    test "AN-03 — a direction signs « Mme Kamaté · Direction »" do
      assert_equal "Mme Kamaté · Direction",
                   announcement_signature(card(author_role: :school_admin, gender: "female", last_name: "Kamaté"))
    end

    test "an anonymized author keeps their function alone" do
      assert_equal "SVT", announcement_signature(card(author_role: :teacher, material_name: "SVT", anonymized: true))
      assert_equal "Direction", announcement_signature(card(author_role: :school_admin, anonymized: true))
    end

    test "a teacher without subject signs with their name alone" do
      assert_equal "M. Kouassi", announcement_signature(card(author_role: :teacher))
    end
  end
end

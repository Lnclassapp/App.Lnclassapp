require "test_helper"

module Entities
  module School
    # ADR standard-de-test §4.1 et §7 : contacts dans la plage fictive 0[157]0000xxxx, noms tirés de la liste du dépôt.
    class FictitiousIdentityTest < ActiveSupport::TestCase
      NAMES = {
        "prenoms" => { "male" => %w[Ibrahim Serge Paul], "female" => %w[Awa Mariam Adjoua Fatou] },
        "noms" => %w[Koné Traoré Kouassi Yao Bamba],
        "etablissements" => { "lycee" => "Lycée Modèle Horizon" }
      }.freeze

      def identity = FictitiousIdentity.new(NAMES)

      test "a contact is a valid ivorian number inside the reserved range, by role and index" do
        FictitiousIdentity::ROLES.each_key do |role|
          [ 0, 1, 42, 999 ].each do |index|
            contact = identity.contact(role:, index:)
            assert_match Entities::Identity::Contact::FORMAT, contact
            assert_match(/\A0[157]0000\d{4}\z/, contact)
            assert FictitiousIdentity.fictitious_contact?(contact), contact
            assert identity.fictitious_contact?(contact), contact
          end
        end
      end

      test "the prefix follows the role" do
        assert identity.contact(role: :student, index: 1).start_with?("01")
        assert identity.contact(role: :teacher, index: 1).start_with?("05")
        assert identity.contact(role: :direction, index: 1).start_with?("07")
        assert identity.contact(role: :admin, index: 1).start_with?("07")
      end

      test "contacts are deterministic and distinct across roles and indexes" do
        assert_equal identity.contact(role: :student, index: 7), FictitiousIdentity.new(NAMES).contact(role: :student, index: 7)
        contacts = FictitiousIdentity::ROLES.keys.flat_map { |role| (0...200).map { identity.contact(role:, index: it) } }
        assert_equal contacts.size, contacts.uniq.size
      end

      test "students have room for a large school" do
        assert_equal "0100001999", identity.contact(role: :student, index: 1999)
        assert_equal "0100009999", identity.contact(role: :student, index: 9999)
      end

      test "refuses an unknown role, a negative index and an index beyond the role capacity" do
        assert_raises(ArgumentError) { identity.contact(role: :stranger, index: 0) }
        assert_raises(ArgumentError) { identity.contact(role: :student, index: -1) }
        assert_raises(ArgumentError) { identity.contact(role: :student, index: 10_000) }
        assert_raises(ArgumentError) { identity.contact(role: :teacher, index: FictitiousIdentity::ROLES.fetch(:teacher).last) }
      end

      test "fictitious_contact? refuses a real-looking number, a short one, a wrong prefix and nil" do
        [ "0707070707", "0501234567", "0100001234x", "010000123", "0200001234", "", nil, 100000 ].each do |contact|
          assert_not FictitiousIdentity.fictitious_contact?(contact), contact.inspect
        end
      end

      test "a name comes from the lists, with a gender, deterministically" do
        name = identity.name(role: :student, index: 3)
        assert_includes NAMES["noms"], name.last_name
        assert_includes NAMES["prenoms"].fetch(name.gender), name.first_name
        assert_equal name, identity.name(role: :student, index: 3)
      end

      test "both genders appear and consecutive indexes give different people" do
        names = (0...12).map { identity.name(role: :student, index: it) }
        assert_equal %w[female male], names.map(&:gender).uniq.sort
        assert_equal names.size, names.map { [ it.first_name, it.last_name ] }.uniq.size
      end

      test "an unknown role has no name either" do
        assert_raises(ArgumentError) { identity.name(role: :stranger, index: 0) }
      end

      test "the real lists give 1500 distinct students, and distinct people in every role" do
        real = FictitiousIdentity.new(YAML.load_file(Rails.root.join("db/seeds/standard/noms.yml")))
        FictitiousIdentity::ROLES.each_key do |role|
          people = (0...1500).map { real.name(role:, index: it) }
          assert_equal 1500, people.map { [ it.first_name, it.last_name ] }.uniq.size, role.to_s
        end
      end

      test "a school name is taken from the list" do
        assert_equal "Lycée Modèle Horizon", identity.school_name("lycee")
        assert_raises(KeyError) { identity.school_name("inconnu") }
      end

      test "refuses lists that are empty or missing" do
        assert_raises(ArgumentError) { FictitiousIdentity.new(NAMES.merge("noms" => [])) }
        assert_raises(KeyError) { FictitiousIdentity.new(NAMES.except("prenoms")) }
      end
    end
  end
end

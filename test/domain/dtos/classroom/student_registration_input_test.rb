require "test_helper"

module Dtos
  module Classroom
    # IL-01, IL-02, IL-08, IL-20 (ADR-0085 §4.3, UDR-0081 §3.2): the name and the first names are two fields, under the
    # ADR-0037 rules, as for the teacher (memo Q24, IE-03, IE-05, IE-19); the classroom is chosen in the cascade or given
    # by the token of a classroom link; no classroom code, no role.
    class StudentRegistrationInputTest < ActiveSupport::TestCase
      def build(**overrides)
        StudentRegistrationInput.new(last_name: " KOUASSI ", first_name: "Aya  Marie", gender: "female", contact: "07 01 02 03 04",
                                     pin: "2468", pin_confirmation: "2468", drena_public_id: "drn-1",
                                     school_public_id: "sch-1", level_slug: "3eme", classroom_public_id: "cls-1", **overrides)
      end

      def errors(**overrides) = build(**overrides).tap(&:validate).errors

      test "IL-01: a complete entry is valid, the names squished, the number normalized" do
        input = build

        assert input.valid?
        assert_equal [ "KOUASSI", "Aya Marie", "0701020304", "07 01 02 03 04" ],
                     [ input.last_name, input.first_name, input.contact, input.raw_contact ]
        assert_equal [ "drn-1", "sch-1", "3eme", "cls-1" ],
                     [ input.drena_public_id, input.school_public_id, input.level_slug, input.classroom_public_id ]
        assert_kind_of Identity::PersonNameInput, input
      end

      test "IL-20 (IE-03): the case and the apostrophes are kept, the spaces reduced" do
        input = build(last_name: "N'GUESSAN", first_name: "Konan  Jean-Baptiste")

        assert_equal [ "N'GUESSAN", "Konan Jean-Baptiste" ], [ input.last_name, input.first_name ]
      end

      test "IL-20 (IE-05): a missing name or missing first names are refused under their own field" do
        assert errors(first_name: "  ").of_kind?(:first_name, :blank)
        assert errors(last_name: nil).of_kind?(:last_name, :blank)
        assert_empty errors(first_name: "").attribute_names - %i[first_name]
      end

      test "IL-20 (IE-03): no full name any more: the attribute is unknown" do
        assert_not_includes StudentRegistrationInput.attribute_names, "full_name"
        assert_raises(ActiveModel::UnknownAttributeError) { build(full_name: "KOUASSI Aya Marie") }
      end

      test "ADR-0037: a forbidden character or a name too long is refused under its field" do
        assert errors(first_name: "Aya2").of_kind?(:first_name, :invalid)
        assert errors(last_name: "K" * 51).of_kind?(:last_name, :too_long)
      end

      test "requires a known gender" do
        assert errors(gender: nil).of_kind?(:gender, :inclusion)
        assert errors(gender: "other").of_kind?(:gender, :inclusion)
        assert build(gender: "male").valid?
      end

      test "IL-20 (IE-19): tells a missing number from an invalid one; +225 typed is cleaned" do
        assert errors(contact: "").of_kind?(:contact, :blank)
        assert errors(contact: nil).of_kind?(:contact, :blank)
        assert errors(contact: "0801020304").of_kind?(:contact, :invalid)
        assert_not errors(contact: "0801020304").of_kind?(:contact, :blank)
        assert_equal "0701020304", build(contact: "+225 07 01 02 03 04").contact
      end

      test "IL-20 (IE-17): requires a 4-digit secret code and the same confirmation" do
        assert errors(pin: "", pin_confirmation: "").of_kind?(:pin, :blank)
        assert errors(pin: "12a4", pin_confirmation: "12a4").of_kind?(:pin, :invalid)
        assert errors(pin_confirmation: "1357").of_kind?(:pin_confirmation, :confirmation)
      end

      test "IL-01: without a link, the classroom is required; the DRENA, school and level are the server's to judge" do
        found = errors(classroom_public_id: " ", drena_public_id: nil, school_public_id: nil, level_slug: nil)

        assert found.of_kind?(:classroom_public_id, :blank)
        assert_equal %i[classroom_public_id], found.attribute_names
      end

      test "IL-08: with a link token, no classroom is asked; the token is normalized" do
        input = build(classroom_public_id: nil, school_public_id: nil, level_slug: nil, link_token: " 0A1B2C3D4E5F ")

        assert input.valid?
        assert_equal "0a1b2c3d4e5f", input.link_token
        assert_nil build(link_token: "kfm37").link_token
        assert_nil build(link_token: "cls-1").link_token
      end

      test "ADR-0085 §4.1: a link token has the form of the ADR-0083 tokens, any other form gives nil" do
        assert_equal "0a1b2c3d4e5f", StudentRegistrationInput.normalize_link_token("0A1B2C3D4E5F")
        [ "kfm37", "0a1b2c3d4e5", "0a1b2c3d4e5fa", "0a1b2c3d4e5g", "", nil ].each do |raw|
          assert_nil StudentRegistrationInput.normalize_link_token(raw), raw.inspect
        end
      end

      test "an identifier outside the public id alphabet (NUL byte) is forgotten" do
        input = build(drena_public_id: "a\u0000", school_public_id: "b\u0000", level_slug: "c\u0000",
                      classroom_public_id: "d\u0000")

        assert_equal [ nil, nil, nil, nil ],
                     [ input.drena_public_id, input.school_public_id, input.level_slug, input.classroom_public_id ]
        assert input.tap(&:validate).errors.of_kind?(:classroom_public_id, :blank)
      end

      test "IL-02: no classroom code nor role attribute" do
        assert_empty StudentRegistrationInput.attribute_names & %w[code join_code role team_role]
        assert_raises(ActiveModel::UnknownAttributeError) { build(join_code: "KFM37") }
        assert_raises(ActiveModel::UnknownAttributeError) { build(role: "team") }
      end
    end
  end
end

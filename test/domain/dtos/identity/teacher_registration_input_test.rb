require "test_helper"

module Dtos
  module Identity
    # IE-03, IE-05, IE-19 (ADR-0083 §4.4, UDR-0079 §3.3): the name and the first names are two fields, under the ADR-0037
    # rules; no full name any more. The school is chosen in its DRENA, or given by an invite token; no school code any more.
    class TeacherRegistrationInputTest < ActiveSupport::TestCase
      def build(**overrides)
        TeacherRegistrationInput.new(last_name: " KOUASSI ", first_name: "Aya  Marie", gender: "female",
                                     contact: "07 01 02 03 04", pin: "2468", pin_confirmation: "2468", drena_public_id: "drn-1",
                                     school_public_id: "sch-1", material_slug: "svt", **overrides)
      end

      def errors(**overrides) = build(**overrides).tap(&:validate).errors

      test "a complete entry is valid, the names squished, the number normalized" do
        input = build

        assert input.valid?
        assert_equal [ "KOUASSI", "Aya Marie", "0701020304", "07 01 02 03 04" ],
                     [ input.last_name, input.first_name, input.contact, input.raw_contact ]
        assert_kind_of PersonNameInput, input
      end

      test "IE-03: the case and the apostrophes are kept, the spaces reduced" do
        input = build(last_name: "N'GUESSAN", first_name: "Konan  Jean-Baptiste")

        assert_equal [ "N'GUESSAN", "Konan Jean-Baptiste" ], [ input.last_name, input.first_name ]
      end

      test "IE-05: a missing name or missing first names are refused under their own field" do
        assert errors(first_name: "  ").of_kind?(:first_name, :blank)
        assert errors(last_name: nil).of_kind?(:last_name, :blank)
        assert_empty errors(first_name: "").attribute_names - %i[first_name]
      end

      test "IE-03: no full name any more: the attribute is unknown" do
        assert_not_includes TeacherRegistrationInput.attribute_names, "full_name"
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

      test "IE-19: tells a missing number from an invalid one; +225 typed is cleaned" do
        assert errors(contact: "").of_kind?(:contact, :blank)
        assert errors(contact: nil).of_kind?(:contact, :blank)
        assert errors(contact: "0801020304").of_kind?(:contact, :invalid)
        assert_not errors(contact: "0801020304").of_kind?(:contact, :blank)
        assert_equal "0701020304", build(contact: "+225 07 01 02 03 04").contact
      end

      test "requires a 4-digit PIN and the same confirmation" do
        assert errors(pin: "", pin_confirmation: "").of_kind?(:pin, :blank)
        assert errors(pin: "12a4", pin_confirmation: "12a4").of_kind?(:pin, :invalid)
        assert errors(pin_confirmation: "1357").of_kind?(:pin_confirmation, :confirmation)
      end

      test "IE-11: without a link, the DRENA and the school are required, and the subject" do
        found = errors(drena_public_id: " ", school_public_id: nil, material_slug: "")

        assert found.of_kind?(:drena_public_id, :blank)
        assert found.of_kind?(:school_public_id, :blank)
        assert found.of_kind?(:material_slug, :blank)
      end

      test "ADR-0083 §4.1: with an invite token, no DRENA nor school is asked; the token is normalized" do
        input = build(drena_public_id: nil, school_public_id: nil, invite_token: " 0A1B2C3D4E5F ")

        assert input.valid?
        assert_equal "0a1b2c3d4e5f", input.invite_token
        assert_nil build(invite_token: "usr-41").invite_token
      end

      test "an identifier outside the public id alphabet (NUL byte) is forgotten" do
        input = build(drena_public_id: "a\u0000", school_public_id: "b\u0000")

        assert_nil input.drena_public_id
        assert_nil input.school_public_id
        assert input.tap(&:validate).errors.of_kind?(:school_public_id, :blank)
      end

      test "IE-02: no school code nor referral attribute any more, and no role" do
        assert_empty TeacherRegistrationInput.attribute_names & %w[school_code ref role national_code]
        assert_raises(ActiveModel::UnknownAttributeError) { build(school_code: "K7M-4QZ") }
        assert_raises(ActiveModel::UnknownAttributeError) { build(role: "team") }
      end
    end
  end
end

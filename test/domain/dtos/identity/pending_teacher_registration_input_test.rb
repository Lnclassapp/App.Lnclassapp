require "test_helper"

module Dtos
  module Identity
    # CP-11 (ADR-0063, UDR-0050): a sign-up without school code designates the school by its national code, or by the
    # school chosen in the list of its DRENA; the rest of the form is the teacher sign-up.
    class PendingTeacherRegistrationInputTest < ActiveSupport::TestCase
      def input(**overrides)
        PendingTeacherRegistrationInput.new(last_name: "Koné", first_name: "Awa", gender: "female", contact: "0501020304",
                                            pin: "4821", pin_confirmation: "4821", material_slug: "svt", **overrides)
      end

      def errors_of(form) = form.tap(&:validate).errors

      test "the national code, typed with spaces, designates the school; no school code is asked" do
        form = input(national_code: " 012 345 ")

        assert form.valid?
        assert_equal "012345", form.national_code
      end

      test "or the school chosen in the list of its DRENA" do
        assert input(school_public_id: "sch-1", drena_public_id: "drn-1").valid?
      end

      test "neither: an error on the form; a malformed national code: an error on its field" do
        assert errors_of(input).of_kind?(:base, :school_missing)
        assert errors_of(input(national_code: "12345")).of_kind?(:national_code, :invalid)
      end

      test "m2: an identifier outside the public id alphabet (NUL byte) is forgotten" do
        form = input(drena_public_id: "a\u0000", school_public_id: "b\u0000")

        assert_nil form.drena_public_id
        assert_nil form.school_public_id
        assert errors_of(form).of_kind?(:base, :school_missing)
      end

      test "the rest of the teacher sign-up still applies" do
        assert errors_of(input(national_code: "012345", pin_confirmation: "1357")).of_kind?(:pin_confirmation, :confirmation)
      end
    end
  end
end

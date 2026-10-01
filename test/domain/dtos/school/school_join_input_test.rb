require "test_helper"

module Dtos
  module School
    # ADR-0071 §4.3: the code an unattached teacher types on the waiting screen, normalised as at sign-up (ADR-0057).
    class SchoolJoinInputTest < ActiveSupport::TestCase
      def errors(school_code) = SchoolJoinInput.new(school_code:).tap(&:validate).errors

      test "un code saisi n'importe comment est normalisé ; la saisie brute reste pour le re-rendu" do
        input = SchoolJoinInput.new(school_code: " k7m-4QZ ")

        assert input.valid?
        assert_equal "k7m4qz", input.school_code
        assert_equal " k7m-4QZ ", input.raw_school_code
        assert_equal({ school_code: "k7m4qz" }, input.to_h)
      end

      test "distingue un code absent, mal formé, ou un code de classe saisi par erreur" do
        assert errors("").of_kind?(:school_code, :blank)
        assert errors(nil).of_kind?(:school_code, :blank)
        assert errors("k7m4q").of_kind?(:school_code, :invalid)
        assert errors("KFM 37").of_kind?(:school_code, :classroom_code)
        assert_not errors("KFM 37").of_kind?(:school_code, :invalid)
      end

      test "sans saisie, la saisie brute est vide" do
        assert_equal "", SchoolJoinInput.new.raw_school_code
      end

      test "le message d'un code mal formé et d'un code refusé" do
        assert_equal [ "Code d'établissement invalide. Il compte 6 caractères, par exemple K7M-4QZ." ],
                     errors("k7m4q").messages_for(:school_code)
        assert_equal "Code d'établissement invalide. Vérifiez-le auprès de votre établissement.",
                     SchoolJoinInput.new.errors.generate_message(:school_code, :inclusion)
      end
    end
  end
end

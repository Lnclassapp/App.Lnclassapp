require "test_helper"

# ADR questions à plusieurs cases §4 : la saisie par case `answers[<q>][blanks][<i>]`, lue champ par champ.
module Dtos
  module Assessment
    class BlanksInputTest < ActiveSupport::TestCase
      def input(blanks) = AttemptInput.new(session_public_id: "abc", question_id: 1, blanks:)

      test "les cases postées en hash se rangent par numéro de case, les cases sautées sont vides" do
        assert_equal [ "3", "", "5" ], input({ "0" => " 3 ", "2" => "5" }).blanks
        assert_equal [ "a", "b" ], input([ "a", "b" ]).blanks
        assert input({ "0" => "3", "1" => "4" }).valid?
      end

      test "plus de six cases, une case hors bornes ou une valeur qui n'est pas un texte sont refusées" do
        [ (0..6).to_h { [ it.to_s, "x" ] }, { "6" => "x" }, { "a" => "x" }, { "0" => { "1" => "x" } }, { "0" => [ "x" ] }, "texte" ].each do |bad|
          subject = input(bad)

          assert_not subject.valid?, bad.inspect
          assert_equal [], subject.blanks
        end
      end

      test "une case trop longue ou à l'octet nul est refusée sous l'erreur de response_text" do
        assert_equal [ :text_too_long ], input({ "0" => "x" * 201 }).tap(&:valid?).errors.details[:response_text].pluck(:error)
        assert_equal [ :invalid ], input({ "0" => "a\0b" }).tap(&:valid?).errors.details[:response_text].pluck(:error)
      end

      test "la copie lit blanks, et une question dont toutes les cases sont vides reste sans réponse" do
        copy = CopyInput.new(session_public_id: "abc", answers: { "7" => { blanks: { "0" => "3", "1" => "" } }, "8" => { blanks: { "0" => " ", "1" => "" } } })

        assert copy.valid?
        assert_equal [ "3", "" ], copy.answers.fetch(7).blanks
        assert_nil copy.answers.fetch(8)
      end
    end
  end
end

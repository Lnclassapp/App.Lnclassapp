require "test_helper"

# ADR-0096 §4.2, UDR-0104: what the confirmation of a mass regeneration sends.
module Dtos
  module School
    class CodeRegenerationInputTest < ActiveSupport::TestCase
      def input(**) = CodeRegenerationInput.new(target: "school_codes", **)

      test "the two targets are known, any other is invalid" do
        assert input.valid?
        assert input(target: "classroom_links").valid?
        refute input(target: "users").valid?
        refute input(target: nil).valid?
      end

      test "the typed number tolerates spaces, thin spaces and dots, as « 3 912 » is written" do
        assert_equal 3912, input(typed_count: " 3 912 ").typed_count
        assert_equal 3912, input(typed_count: "3 912").typed_count
        assert_equal 3912, input(typed_count: "3.912").typed_count
        assert_nil input(typed_count: "").typed_count
        assert_nil input(typed_count: "douze").typed_count
        assert_nil input(typed_count: "12345678").typed_count
        assert_nil input.typed_count
      end

      test "the current year only is the default, and only an explicit no turns it off" do
        assert input.current_year_only
        refute input(current_year_only: "0").current_year_only
        assert input(current_year_only: "1").current_year_only
      end

      test "the selection is built from its parameters" do
        assert_equal({ "drena" => "abc" }, input(selection: { "drena" => "abc", "school" => "" }).selection.to_h)
        assert_equal({}, input.selection.to_h)
      end
    end
  end
end

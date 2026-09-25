require "test_helper"

module Shared
  class ResultTest < ActiveSupport::TestCase
    test "un succès porte sa valeur, sans code ni erreur" do
      result = Result.success(42)

      assert result.success?
      assert_not result.failure?
      assert_equal 42, result.value
      assert_nil result.code
      assert_equal({}, result.errors)
    end

    test "un succès peut n'avoir aucune valeur" do
      assert_nil Result.success.value
    end

    test "un échec porte son code et ses erreurs" do
      result = Result.failure(:invalid, errors: { name: [ :blank ] })

      assert result.failure?
      assert_not result.success?
      assert_nil result.value
      assert_equal :invalid, result.code
      assert_equal({ name: [ :blank ] }, result.errors)
    end

    test "accepte chacun des six codes de la liste fermée" do
      assert_equal %i[forbidden not_found invalid conflict locked expired], Result::ERROR_CODES

      Result::ERROR_CODES.each { |code| assert_equal code, Result.failure(code).code }
    end

    test "refuse un code hors de la liste" do
      error = assert_raises(ArgumentError) { Result.failure(:unauthorized) }

      assert_match "unauthorized", error.message
    end
  end
end

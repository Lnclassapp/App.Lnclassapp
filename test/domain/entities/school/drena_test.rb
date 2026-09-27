require "test_helper"

module Entities
  module School
    class DrenaTest < ActiveSupport::TestCase
      test "normalise les espaces du nom et le limite à 80 caractères" do
        drena = Drena.new(name: "  Abidjan   1 ")

        assert drena.valid?
        assert_equal "Abidjan 1", drena.name
        assert Drena.new(name: "a" * 81).invalid?
        assert Drena.new(name: nil).tap(&:validate).errors.of_kind?(:name, :blank)
      end

      test "la clé est le slug figé, sinon celui du nom" do
        assert_equal "abidjan-1", Drena.new(name: "Abidjan 1").key
        assert_equal "abidjan-un", Drena.new(name: "Abidjan 1", slug: "abidjan-un").key
      end
    end
  end
end

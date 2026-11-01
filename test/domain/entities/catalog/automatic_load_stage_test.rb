require "test_helper"

module Entities
  module Catalog
    # ADR chargement-automatique-des-lecons-hors-production §4.1 : seul le nom de l'environnement Railway décide.
    class AutomaticLoadStageTest < ActiveSupport::TestCase
      def stage(name, pr_environment: false) = AutomaticLoadStage.for(name:, pr_environment:)

      test "Develop and Staging load, whatever the case and the spaces" do
        [ "Develop", "develop", "DEVELOP", " Staging ", "staging" ].each do |name|
          assert stage(name).load?, name
          assert_not stage(name).skip?, name
          assert_not stage(name).unknown?, name
        end
      end

      test "production never loads, whatever the case" do
        %w[production Production PRODUCTION].each do |name|
          assert stage(name).skip?, name
          assert_not stage(name).load?, name
        end
      end

      test "a PR environment never loads, even under a name that is Develop or unknown" do
        assert stage("Develop", pr_environment: true).skip?
        assert stage("pr-1234", pr_environment: true).skip?
      end

      test "a missing name (local machine, CI) loads nothing and is not a warning" do
        [ nil, "", "  " ].each do |name|
          assert stage(name).skip?, name.inspect
          assert_not stage(name).unknown?, name.inspect
        end
      end

      test "any other name is unknown and carries its name" do
        result = stage(" Recette ")

        assert result.unknown?
        assert_not result.load?
        assert_not result.skip?
        assert_equal "Recette", result.name
        assert_nil stage("Develop").name
      end
    end
  end
end

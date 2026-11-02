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
      # ADR-0123 : Develop seul remplace entières les leçons v3 du programme ; les leçons à sujets gardent leur mode partout.
      test "only Develop, whatever the case, replaces whole lessons; Staging, production, a PR and an unknown name never do" do
        [ "Develop", " develop ", "DEVELOP" ].each { assert stage(it).whole_lessons?, it }
        [ "Staging", "production", "Recette", nil ].each { assert_not stage(it).whole_lessons?, it.inspect }
        assert_not stage("Develop", pr_environment: true).whole_lessons?
      end

      test "a lesson with subjects keeps its exercises-only mode everywhere it loads" do
        [ "Develop", "Staging" ].each do |name|
          assert_equal :exercises, stage(name).mode_for(level_directory: "tle-c", subjects: true), name
          assert_equal :exercises, stage(name).mode_for(level_directory: "3eme", subjects: true), name
        end
      end

      test "on Develop a programme lesson without subjects is replaced whole; outside the programme or elsewhere it is not loaded" do
        assert_equal :lesson, stage("Develop").mode_for(level_directory: "tle-c", subjects: false)
        assert_equal :lesson, stage("Develop").mode_for(level_directory: "1ere-a1", subjects: false)
        assert_nil stage("Develop").mode_for(level_directory: "3eme", subjects: false)
        assert_nil stage("Staging").mode_for(level_directory: "tle-c", subjects: false)
      end
    end
  end
end

require "test_helper"

module UseCases
  module Identity
    # CL-09, TR-08 remplacée : « Terminer la configuration » enregistre l'onboarding, et seulement s'il y a une classe.
    class CompleteTeacherOnboardingTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      # Idempotent comme le vrai dépôt : une date déjà posée n'est jamais déplacée.
      class FakeProfiles
        include Ports::Identity::TeacherProfileRepositoryPort

        attr_reader :completed

        def initialize
          @completed = {}
        end

        def complete_onboarding(user_id:, at:)
          @completed[user_id] ||= at
          true
        end
      end

      class FakeTeachings
        include Ports::Classroom::TeachingRepositoryPort

        def initialize(by_teacher) = @by_teacher = by_teacher
        def classroom_ids_for(teacher_id:) = @by_teacher.fetch(teacher_id, [])
      end

      setup do
        @profiles = FakeProfiles.new
        @teacher = Entities::Identity::Actor.new(user_id: 5, role: :teacher, school_id: 31)
      end

      def complete(actor: @teacher, declared: { 5 => [ 11, 13 ] }, at: NOW)
        CompleteTeacherOnboarding.new(profiles: @profiles, teachings: FakeTeachings.new(declared),
                                      policy: Policies::Identity::CompleteOnboardingPolicy.new, clock: Clock.new(at))
                                 .call(actor:)
      end

      test "avec au moins une classe déclarée, l'onboarding est enregistré à l'heure de l'horloge" do
        assert complete.success?
        assert_equal({ 5 => NOW }, @profiles.completed)
      end

      test "terminer une seconde fois réussit sans déplacer la date" do
        complete
        assert complete(at: NOW + 3600).success?
        assert_equal({ 5 => NOW }, @profiles.completed)
      end

      test "sans aucune classe déclarée : :invalid, rien n'est enregistré" do
        result = complete(declared: { 6 => [ 11 ] })

        assert_equal :invalid, result.code
        assert_equal({ base: [ :no_classroom ] }, result.errors)
        assert_empty @profiles.completed
      end

      test "hors du rôle enseignant : refus, rien n'est enregistré" do
        assert_equal :forbidden, complete(actor: Entities::Identity::Actor.new(user_id: 5, role: :team)).code
        assert_equal :forbidden, complete(actor: nil).code
        assert_empty @profiles.completed
      end
    end
  end
end

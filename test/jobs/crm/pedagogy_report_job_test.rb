require "test_helper"

# CA-29 (ADR-XXXX modèles de langage) : le job n'envoie au modèle que des agrégats (jamais un nom d'élève) et garde six lignes au plus ;
# un échec ou une réponse vide marque la génération « failed ».
module Crm
  class PedagogyReportJobTest < ActiveSupport::TestCase
    class TestJob < Crm::PedagogyReportJob
      cattr_accessor :model_double

      private

      def language_model = model_double
    end

    setup do
      @repository = Repositories::Crm::GenerationRepository.new
      @school = create_school(name: "Lycée Classique d'Abidjan")
      @user = create_team_member(team_role: "field")
      @fake = FakeLanguageModel.new("- Un\n- Deux\n- Trois\n- Quatre\n- Cinq\n- Six\n- Sept", model: "fake/text")
      TestJob.model_double = @fake
      @classroom = create_classroom(school: @school, level: create_level(name: "Tle", position: 7), name: "Tle D 1")
      @student = create_student(classroom: @classroom, first_name: "Zébulon", last_name: "Quentarin")
      create_exercise_session(student: @student, status: "completed", score_percent: 80)
    end

    def pending
      @repository.create_pending(generation: Entities::Crm::Generation.new(
        public_id: nil, school_id: @school.id, kind: "pedagogy_report", status: "pending", requested_by_id: @user.id, follow_up_id: nil,
        input_fingerprint: "a" * 64, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
      )).value
    end

    test "the model gets the figures and the answer is kept as six lines at most" do
      generation = pending

      TestJob.perform_now(generation.public_id)

      done = @repository.find_by_public_id(public_id: generation.public_id)
      assert done.done?
      assert_equal %w[Un Deux Trois Quatre Cinq Six], done.content.split("\n")
      call = @fake.calls.last
      assert_equal Rails.configuration.x.language_models.model_text, call[:model]
      assert_includes call[:messages].last[:content], "Élèves actifs : 1"
      assert_not call[:json]
    end

    test "no student name, no school name and no public id reaches the model" do
      generation = pending

      TestJob.perform_now(generation.public_id)

      sent = @fake.calls.last[:messages].map { it[:content] }.join("\n")
      [ @student.first_name, @student.last_name, @student.public_id, @school.name, @classroom.name ].reject(&:blank?).each do |personal|
        assert_not_includes sent, personal
      end
    end

    test "a school that lost its activity before the job ran fails without calling the model" do
      Orm::ExerciseSession.delete_all
      generation = pending

      TestJob.perform_now(generation.public_id)

      assert @repository.find_by_public_id(public_id: generation.public_id).failed?
      assert_empty @fake.calls
    end

    test "a model failure marks the generation failed with its code" do
      generation = pending
      @fake.fail_with(:timeout)

      TestJob.perform_now(generation.public_id)

      failed = @repository.find_by_public_id(public_id: generation.public_id)
      assert failed.failed?
      assert_equal "timeout", failed.error_code
    end

    test "an empty answer is a failure, not an empty synthesis" do
      generation = pending
      @fake.respond_with("  \n ")

      TestJob.perform_now(generation.public_id)

      assert_equal "invalid_response", @repository.find_by_public_id(public_id: generation.public_id).error_code
    end
  end
end

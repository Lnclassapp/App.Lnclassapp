require "test_helper"

# CA-28, CA-24 (ADR-XXXX modèles de langage) : le job envoie la relance et les derniers échanges (jamais un nom d'élève ni un numéro) au
# modèle, garde 600 caractères au plus ; un échec du modèle marque la génération « failed » avec son code.
module Crm
  class WhatsappDraftJobTest < ActiveSupport::TestCase
    class TestJob < Crm::WhatsappDraftJob
      cattr_accessor :model_double

      private

      def language_model = model_double
    end

    setup do
      @repository = Repositories::Crm::GenerationRepository.new
      @school = create_school(name: "Lycée Classique d'Abidjan")
      @user = create_team_member(team_role: "field")
      @follow_up = Orm::CrmFollowUp.create!(school: @school, assignee: @user, due_on: Date.current + 1, reason: "Rappeler pour le devis", created_by: @user)
      @fake = FakeLanguageModel.new("Bonjour, je reviens vers vous au sujet du devis.", model: "fake/text")
      TestJob.model_double = @fake
    end

    def pending
      @repository.create_pending(generation: Entities::Crm::Generation.new(
        public_id: nil, school_id: @school.id, kind: "whatsapp_draft", status: "pending", requested_by_id: @user.id, follow_up_id: @follow_up.id,
        input_fingerprint: "a" * 64, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
      )).value
    end

    test "the model gets the follow-up and the school, and the answer is stored" do
      generation = pending

      TestJob.perform_now(generation.public_id)

      done = @repository.find_by_public_id(public_id: generation.public_id)
      assert done.done?
      assert_equal "Bonjour, je reviens vers vous au sujet du devis.", done.content
      call = @fake.calls.last
      assert_equal Rails.configuration.x.language_models.model_text, call[:model]
      assert_includes call[:messages].last[:content], "Lycée Classique d'Abidjan"
      assert_includes call[:messages].last[:content], "Rappeler pour le devis"
      assert_not call[:json]
    end

    test "an answer above 600 characters is cut to 600" do
      generation = pending
      @fake.respond_with("mot " * 400)

      TestJob.perform_now(generation.public_id)

      assert_operator @repository.find_by_public_id(public_id: generation.public_id).content.length, :<=, 600
    end

    test "no student name reaches the model" do
      classroom = create_classroom(school: @school, level: create_level(name: "Tle", position: 7), name: "Tle D 1")
      student = create_student(classroom:, first_name: "Zébulon", last_name: "Quentarin")
      generation = pending

      TestJob.perform_now(generation.public_id)

      sent = @fake.calls.last[:messages].map { it[:content] }.join("\n")
      assert_not_includes sent, student.first_name
      assert_not_includes sent, student.last_name
    end

    test "CA-24: a model failure marks the generation failed with its code" do
      generation = pending
      @fake.fail_with(:timeout)

      TestJob.perform_now(generation.public_id)

      failed = @repository.find_by_public_id(public_id: generation.public_id)
      assert failed.failed?
      assert_equal "timeout", failed.error_code
    end

    test "an empty answer is an invalid response, not an empty draft" do
      generation = pending
      @fake.respond_with("  \n ")

      TestJob.perform_now(generation.public_id)

      failed = @repository.find_by_public_id(public_id: generation.public_id)
      assert failed.failed?
      assert_equal "invalid_response", failed.error_code
    end
  end
end

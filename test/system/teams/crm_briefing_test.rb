require "application_system_test_case"

# CA-22, CA-24 (UDR-XXXX assistants du suivi) : « Préparer l'appel » affiche une fiche de 5 lignes au plus, un second clic sans nouvel
# échange ne rappelle pas le modèle, un échec offre « Réessayer ».
class Teams::CrmBriefingTest < ApplicationSystemTestCase
  cattr_accessor :fake_model # le serveur du test tourne dans un autre fil : pas de Thread.current

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @fake = FakeLanguageModel.new("Un\nDeux\nTrois\nQuatre\nCinq\nSix", model: "fake/text")
    self.class.fake_model = @fake
    Crm::BriefingJob.define_method(:language_model) { Teams::CrmBriefingTest.fake_model }
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    @original_key = Rails.configuration.x.language_models.api_key
    Rails.configuration.x.language_models.api_key = "sk-test"
  end

  teardown do
    Rails.configuration.x.language_models.api_key = @original_key
    Crm::BriefingJob.remove_method(:language_model)
    ActiveJob::Base.queue_adapter = @original_adapter
  end

  def open_assistants
    sign_in_as create_team_member(team_role: "field")
    visit school_path(@school.public_id)
    within("turbo-frame#school_crm_assistants") { click_link I18n.t("teams.crm.assistants.card.briefing") }
  end

  test "CA-22: the briefing shows five lines at most, and a second click does not call the model again" do
    open_assistants

    within("turbo-frame#school_crm_briefing") do
      assert_selector "li", count: 5
      assert_text "Cinq"
      assert_no_text "Six"
    end
    assert_equal 1, @fake.calls.size

    within("turbo-frame#school_crm_assistants") { click_link I18n.t("teams.crm.assistants.card.briefing") }
    assert_selector "turbo-frame#school_crm_briefing li", count: 5
    assert_equal 1, @fake.calls.size
  end

  test "CA-24: a model failure shows the error and a Réessayer button" do
    @fake.fail_with(:timeout)

    open_assistants

    within("turbo-frame#school_crm_briefing") do
      assert_text I18n.t("teams.crm.generations.generation.failed_title")
      assert_selector "a, button", text: I18n.t("teams.crm.generations.generation.retry")
    end
  end
end

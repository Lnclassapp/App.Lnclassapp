require "test_helper"

# UDR-0041, amendement du 2026-10-06 (charte §1) : un texte partagé par tous les rôles tutoie l'élève par sa clé
# « _student », et garde le vouvoiement pour les autres rôles comme pour un visiteur.
class ToneHelperTest < ActionView::TestCase
  attr_accessor :current_actor

  def actor(role) = Entities::Identity::Actor.new(user_id: 1, role:, team_role: nil, school_id: nil)

  test "a student reads the « _student » variant of a key" do
    self.current_actor = actor(:student)

    assert_equal "Ton code secret est changé.", tone_t("identity.profile_pins.update.changed")
  end

  test "a teacher, a team member and a visitor read the key itself" do
    [ actor(:teacher), actor(:team), nil ].each do |someone|
      self.current_actor = someone

      assert_equal "Votre code secret est changé.", tone_t("identity.profile_pins.update.changed")
    end
  end

  test "a key without a variant is the same for the student" do
    self.current_actor = actor(:student)

    assert_equal "Changer mon code secret", tone_t("identity.profiles.show.change_pin")
  end
end

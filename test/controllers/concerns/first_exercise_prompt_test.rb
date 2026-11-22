require "test_helper"

# UDR accueil-eleve-qr-fenetre-inviter §3.2 : la fenêtre « Ton premier exercice » ne concerne que l'élève dont la session ne porte pas
# encore le drapeau ; un écran sans acteur (second facteur, aide publique) ne l'ouvre jamais.
class FirstExercisePromptTest < ActiveSupport::TestCase
  Actor = Struct.new(:role) do
    def student? = role == :student
  end

  Host = Struct.new(:current_actor, :session) do
    def self.helper_method(*); end

    include FirstExercisePrompt
  end

  def prompt?(actor, session = {}) = Host.new(actor, session).send(:first_exercise_prompt?)

  test "a student whose session carries no flag gets the window" do
    assert prompt?(Actor.new(:student))
  end

  test "the flag set by a copy handed in ends it" do
    assert_not prompt?(Actor.new(:student), { FirstExercisePrompt::SESSION_KEY => true })
  end

  test "a teacher, a director or no actor at all never gets it" do
    assert_not prompt?(Actor.new(:teacher))
    assert_not prompt?(Actor.new(:school_admin))
    assert_not prompt?(nil)
  end
end

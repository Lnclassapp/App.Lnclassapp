require "test_helper"

# Routes du socle « Je m'entraîne » (ADR entraînement corrigé sans trace §4, ADR questions à plusieurs cases §4) : le routage seul,
# les contrôleurs viennent avec leurs lots (la route est lue dans la table, sans la faire servir).
class PracticeRoutesTest < ActionDispatch::IntegrationTest
  def route(name) = Rails.application.routes.routes.find { it.name == name.to_s }

  test "POST d'une vérification d'entraînement vers catalog/practice_checks#create" do
    found = route(:practice_check)

    assert_equal [ "POST", "/courses/:course_slug/notions/:slug/practice_check(.:format)", "catalog/practice_checks", "create" ],
                 [ found.verb, found.path.spec.to_s, found.defaults[:controller], found.defaults[:action] ]
    assert_equal "/courses/racines-carrees/notions/simplifier/practice_check", practice_check_path(course_slug: "racines-carrees", slug: "simplifier")
  end

  test "POST de l'ouverture d'un indice vers assessment/hints#create" do
    found = route(:exercise_session_hints)

    assert_equal [ "POST", "/exercise_sessions/:public_id/hints(.:format)", "assessment/hints", "create" ],
                 [ found.verb, found.path.spec.to_s, found.defaults[:controller], found.defaults[:action] ]
    assert_equal "/exercise_sessions/abc123/hints", exercise_session_hints_path("abc123")
  end
end

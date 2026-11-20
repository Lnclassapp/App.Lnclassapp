require "test_helper"

# ADR-XXXX-recherche-etablissement, UDR-XXXX-champ-etablissement : la recherche publique des établissements actifs, le cadre
# « school_results » en boutons radio du formulaire demandé, 20 au plus, limitée à 300 par minute et par adresse.
class School::SchoolSearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tiassale = create_drena(name: "Tiassalé")
    @notre_dame = create_school(drena: @tiassale, name: "Collège Notre-Dame de la Paix")
    @closed = create_school(drena: @tiassale, name: "Lycée de Tiassalé", status: "inactive")
  end

  test "CA-5 : un visiteur cherche ; chaque résultat en radio du scope demandé, avec sa DRENA" do
    get school_search_path(q: "ND paix tiassale", scope: "teacher_registration"), headers: { "Turbo-Frame" => "school_results" }

    assert_response :success
    assert_select "turbo-frame#school_results" do
      assert_select "input[type=radio][required][name='teacher_registration[school_public_id]'][value='#{@notre_dame.public_id}']:not([checked])"
      assert_select "label", text: /Collège Notre-Dame de la Paix\s+DRENA Tiassalé/
      assert_select "legend.sr-only", text: "1 établissement trouvé."
    end
    assert_select "input[value='#{@closed.public_id}']", 0
  end

  test "CA-5 : le scope est une liste fermée ; toute autre valeur nomme les champs de l'inscription élève" do
    School::SchoolSearchesController::SCOPES.each do |scope|
      get school_search_path(q: "tiassale", scope:)

      assert_select "input[name='#{scope}[school_public_id]']", 1, scope
    end
    [ "user", "", nil, "school_join]" ].each do |scope|
      get school_search_path(q: "tiassale", scope:)

      assert_select "input[name='student_registration[school_public_id]']", 1, scope.inspect
    end
  end

  test "le registre suit le formulaire : l'élève est tutoyé, l'enseignant vouvoyé" do
    get school_search_path(q: "korhogo", scope: "student_registration")

    assert_select "turbo-frame#school_results", text: /Aucun établissement trouvé/
    assert_select "turbo-frame#school_results", text: /Vérifie l'orthographe/

    get school_search_path(q: "korhogo", scope: "school_join")

    assert_select "turbo-frame#school_results", text: /Vérifiez l'orthographe/
  end

  test "CA-3 : au-delà de 20, la ligne qui invite à ajouter un mot" do
    21.times { |i| create_school(drena: @tiassale, name: "Lycée moderne #{i}") }

    get school_search_path(q: "lycee moderne")

    assert_select "input[type=radio]", 20
    assert_select "p[data-school--school-search-target=more]", text: /Plus de 20 établissements/
  end

  test "CA-4 : une saisie trop courte rend un cadre vide" do
    [ "a", "", nil ].each do |q|
      get school_search_path(q:)

      assert_response :success
      assert_select "turbo-frame#school_results", text: ""
      assert_select "turbo-frame#school_results *", 0
    end
  end

  test "CA-6 : 40 élèves d'une même adresse, 6 recherches chacun, aucune refusée ; la 301e reçoit 429 et l'état d'erreur" do
    240.times do |i|
      get school_search_path(q: %w[tiassale paix notre nd college ecole][i % 6])

      assert_response :success
    end
    60.times { get school_search_path(q: "paix") }

    assert_response :success
    get school_search_path(q: "paix", scope: "school_join")

    assert_response :too_many_requests
    assert_select "turbo-frame#school_results [role=alert]", text: /Trop de recherches depuis cette connexion/
    assert_select "turbo-frame#school_results a[href*='q=paix']", text: /Réessayer/

    # Par adresse : une autre connexion n'est pas freinée par celle-ci.
    get school_search_path(q: "paix"), headers: { "REMOTE_ADDR" => "10.0.0.2" }

    assert_response :success
  end
end

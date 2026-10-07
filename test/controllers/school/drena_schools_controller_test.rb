require "test_helper"

# ID-08, SC-26 (UDR-0024): the active schools of a DRENA, public and rate limited — the « schools » frame of the
# teacher sign-up (or of the waiting screen, scope=school_join) in HTML, a list of { public_id, name } in JSON.
# Only the active schools, sorted by name.
class School::DrenaSchoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @drena = create_drena(name: "Abidjan 1")
    @lycee = create_school(drena: @drena, name: "Lycée Classique d'Abidjan")
    @college = create_school(drena: @drena, name: "Collège Voltaire")
    @closed = create_school(drena: @drena, name: "Lycée fermé", status: "inactive")
    @elsewhere = create_school(drena: create_drena(name: "Abidjan 2"), name: "Lycée d'Abidjan 2")
  end

  test "HTML: the schools frame of the sign-up form, active schools of the DRENA by name, for a visitor" do
    get drena_schools_path(@drena.public_id), headers: { "Turbo-Frame" => "schools" }

    assert_response :success
    assert_select "turbo-frame#schools" do
      assert_select "input[type=hidden][name='teacher_registration[drena_public_id]'][value='#{@drena.public_id}']:not([id])"
      assert_select "select[name='teacher_registration[school_public_id]'][required]:not([disabled])"
      assert_equal [ "Collège Voltaire", "Lycée Classique d'Abidjan" ], css_select("option[value!='']").map(&:text)
      assert_select "label[for='teacher_registration_school_public_id']", text: /#{I18n.t("school.drena_schools.index.label")}/
    end
    assert_select "option[value='#{@closed.public_id}']", count: 0
    assert_select "option[value='#{@elsewhere.public_id}']", count: 0
  end

  # ADR-0082 §4.5, UDR-0078 §3.9: the waiting screen reuses this frame, its fields in the school_join scope.
  test "HTML: scope=school_join names the fields of the waiting screen's join form" do
    get drena_schools_path(@drena.public_id, scope: "school_join"), headers: { "Turbo-Frame" => "schools" }

    assert_response :success
    assert_select "turbo-frame#schools" do
      assert_select "input[type=hidden][name='school_join[drena_public_id]'][value='#{@drena.public_id}']:not([id])"
      assert_select "select[name='school_join[school_public_id]'][required]:not([disabled])"
      assert_equal [ "Collège Voltaire", "Lycée Classique d'Abidjan" ], css_select("option[value!='']").map(&:text)
      assert_select "label[for='school_join_school_public_id']"
    end
    assert_select "[name^='teacher_registration']", 0
  end

  test "HTML: any other scope falls back to the sign-up's teacher_registration" do
    [ "teacher_registration", "user", "school_join]", "" ].each do |scope|
      get drena_schools_path(@drena.public_id, scope:)

      assert_response :success, scope
      assert_select "select[name='teacher_registration[school_public_id]']", 1, scope
      assert_select "[name^='school_join'], [name^='user']", 0, scope
    end
    get drena_schools_path(@drena.public_id, scope: [ "school_join" ])

    assert_response :success
    assert_select "select[name='teacher_registration[school_public_id]']"
  end

  test "HTML: a DRENA without an active school says so and disables the list" do
    empty = create_drena(name: "Bouaké 1")
    create_school(drena: empty, name: "Lycée fermé", status: "inactive")

    get drena_schools_path(empty.public_id)

    assert_response :success
    assert_select "turbo-frame#schools select[name='teacher_registration[school_public_id]'][disabled]"
    assert_select "turbo-frame#schools", text: /#{Regexp.escape(I18n.t("school.drena_schools.index.none"))}/
  end

  test "JSON: a list of { public_id, name }, active schools only, sorted by name (SC-26)" do
    get drena_schools_path(@drena.public_id, format: :json)

    assert_response :success
    assert_equal [ { "public_id" => @college.public_id, "name" => "Collège Voltaire" },
                   { "public_id" => @lycee.public_id, "name" => "Lycée Classique d'Abidjan" } ],
                 response.parsed_body
  end

  test "an unknown DRENA receives 404, in HTML and in JSON" do
    get drena_schools_path("drn-inconnue")

    assert_response :not_found

    get drena_schools_path("drn-inconnue", format: :json)

    assert_response :not_found
    assert_equal({ "error" => "not_found" }, response.parsed_body)
  end

  test "the 31st request of a minute from the same address receives 429" do
    30.times do
      get drena_schools_path(@drena.public_id, format: :json)

      assert_response :success
    end

    get drena_schools_path(@drena.public_id, format: :json)

    assert_response :too_many_requests
  end
end

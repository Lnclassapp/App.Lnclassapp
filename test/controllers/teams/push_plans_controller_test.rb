require "test_helper"

# UDR XXXX (écran notifications de l'équipe) §3.4, §3.7 : le plan du jour, lu dans le frame « push_plan » ; toute l'équipe le lit,
# aucun nom d'élève ; état vide et état d'erreur dans le frame.
class Teams::PushPlansControllerTest < ActionDispatch::IntegrationTest
  NOW = Time.utc(2026, 11, 25, 10, 12)

  Query = Queries::Communication::PushDailyPlanQuery

  setup do
    @team = create_team_member(team_role: "field")
  end

  def plan = get(teams_push_plan_path, headers: { "Turbo-Frame" => "push_plan" })

  # Le plan lu sur ces lignes, à l'instant donné.
  def plan_of(entries, at: NOW)
    stub_any_instance(Query, :call, ->(**) { entries }) { travel_to(at) { plan } }
  end

  test "an empty plan says nothing is to validate" do
    sign_in_as @team
    travel_to(NOW) { plan }

    assert_response :ok
    assert_select "turbo-frame#push_plan"
    assert_select "p", text: I18n.t("teams.push_plans.show.empty.title")
    assert_select "form", count: 0
  end

  %w[admin content field].each do |team_role|
    test "the team role #{team_role} reads it" do
      sign_in_as create_team_member(team_role:)
      plan

      assert_response :ok
    end
  end

  { teacher: -> { create_teacher }, school_admin: -> { create_school_admin }, student: -> { create_student(classroom: create_classroom) } }.each do |name, build|
    test "a #{name} gets 403" do
      sign_in_as instance_exec(&build)
      plan

      assert_response :forbidden
    end
  end

  test "a motive with students shows the count, the text, the schools, a confirmed button and no student name" do
    entry = Query::Entry.new(motive: "inactive", students: 3, text: "Ta classe avance. Un exercice t'attend sur Lnclass.", more_texts: 0, schools: [ [ "Lycée Alpha", 2 ], [ "Collège Bêta", 1 ] ], approval: nil)
    sign_in_as @team
    plan_of([ entry ])

    assert_select "#push_plan_inactive" do
      assert_select "span", text: "3 élèves"
      assert_select "li", text: "Lycée Alpha — 2"
      assert_select "form[data-turbo-confirm=?]", I18n.t("teams.push_approvals.create.confirm", motive: "Élève inactif (3, 7, 14 jours)", count: 3)
      assert_select "button", text: "Valider l'envoi"
    end
  end

  test "an approved motive shows the badge, the author and the recorded count instead of the button" do
    entry = Query::Entry.new(motive: "inactive", students: 5, text: "x", more_texts: 0, schools: [],
                                                                  approval: Query::Approval.new(by_name: "Awa K.", at: NOW - 1.hour, count: 42))
    sign_in_as @team
    plan_of([ entry ])

    assert_select "#push_plan_inactive" do
      assert_select "span", text: "Validé"
      assert_select "p", text: "par Awa K. à 09 h 12 — 42 élèves"
      assert_select "form", count: 0
    end
  end

  test "after 20 h the buttons are gone and the day is said to be over" do
    entry = Query::Entry.new(motive: "inactive", students: 3, text: "x", more_texts: 0, schools: [ [ "A", 3 ] ], approval: nil)
    sign_in_as @team
    plan_of([ entry ], at: Time.utc(2026, 11, 25, 20, 30))

    assert_select "form", count: 0
    assert_select "p", text: I18n.t("teams.push_plans.show.closed")
  end

  test "more than 5 schools: the first 5, then the rest behind « Voir plus »" do
    schools = Array.new(7) { |i| [ "École #{i}", 10 - i ] }
    entry = Query::Entry.new(motive: "inactive", students: 49, text: "x", more_texts: 0, schools:, approval: nil)
    sign_in_as @team
    plan_of([ entry ])

    assert_select "#push_plan_inactive > ul > li", count: 5
    assert_select "#push_plan_inactive details summary", text: I18n.t("teams.push_plans.show.more_schools", count: 2)
    assert_select "#push_plan_inactive details li", count: 2
  end

  test "a motive with several texts and a motive nobody is concerned by" do
    many = Query::Entry.new(motive: "result", students: 2, text: "Ta copie est corrigée.", more_texts: 3, schools: [ [ "A", 2 ] ], approval: nil)
    none = Query::Entry.new(motive: "unfinished", students: 0, text: nil, more_texts: 0, schools: [], approval: nil)
    sign_in_as @team
    plan_of([ many, none ])

    assert_select "#push_plan_result", text: /\+ 3 autres matières/
    assert_select "#push_plan_unfinished", text: "Exercice commencé — aucun élève concerné aujourd'hui"
    assert_select "#push_plan_unfinished form", count: 0
  end

  test "a failing computation shows the error state in the frame, not a blank page" do
    sign_in_as @team
    stub_any_instance(Query, :call, ->(**) { raise "boom" }) { travel_to(NOW) { plan } }

    assert_response :service_unavailable
    assert_select "turbo-frame#push_plan [role=alert]", text: /#{Regexp.escape(I18n.t("teams.push_plans.show.error.message"))}/
  end
end

require "test_helper"

# ADR-0056, UDR-0043, GC-01, GC-04, GC-08: the team launches the generation of the missing classrooms from the schools
# screen and lands on its report; one at a time; nobody else may launch it.
class Teams::ClassroomGenerationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @member = create_team_member(team_role: "field")
  end

  test "the schools screen offers the generation as a secondary action, confirmed in a dialog" do
    sign_in_as @member

    get schools_path

    assert_select "button[aria-controls=generate-classrooms-modal][aria-haspopup=dialog]", text: /Générer les classes manquantes/
    assert_select "dialog#generate-classrooms-modal" do
      assert_select "h2", text: "Générer les classes manquantes ?"
      assert_select "form#generate-classrooms-form[action='#{classroom_generations_path}'][method=post]"
      assert_select "#generate-classrooms-rules li", 3
      assert_select "#generate-classrooms-rules strong", text: /sans aucune classe de l'année scolaire #{current_school_year}/
      assert_select "button[type=submit][form=generate-classrooms-form]", text: /Lancer la génération/
    end
  end

  test "the launch creates the report, queues the job and leads to the report with a toast" do
    sign_in_as @member

    assert_enqueued_with(job: Classroom::GenerateMissingClassroomsJob) do
      post classroom_generations_path
    end

    report = Orm::ImportReport.sole
    assert_equal [ "classrooms", "queued", @member.id, nil ], report.attributes.values_at("kind", "status", "imported_by_id", "checksum_sha256")
    assert_redirected_to teams_import_path(report.public_id)
    assert_response :see_other
    assert_equal "Génération des classes lancée.", flash[:notice]
  end

  # finitions-generation-menu: one generation at a time is the expected state, not a failure. The team is told so in an
  # information toast (never the red « Une erreur est survenue ») and lands on the report of the running generation.
  test "while a generation runs, a second one is not queued: an information toast leads to the running report" do
    create_import_report(kind: "classrooms", status: "completed", checksum_sha256: nil, created_at: 1.hour.ago)
    running = create_import_report(kind: "classrooms", status: "importing", checksum_sha256: nil, started_at: Time.current)
    sign_in_as @member

    assert_no_enqueued_jobs do
      assert_no_difference -> { Orm::ImportReport.count } do
        post classroom_generations_path
      end
    end

    assert_redirected_to teams_import_path(running.public_id)
    assert_response :see_other
    follow_redirect!

    assert_select "#toasts [data-toast-type]", 1
    assert_select "#toasts [data-toast-type=info]:not([role=alert])" do
      assert_select "p.font-semibold", text: "Génération déjà en cours"
      assert_select "p.text-mute", text: "Une seule génération des classes à la fois : voici l'avancement de celle qui tourne."
    end
    assert_select "#toasts", text: /Une erreur est survenue/, count: 0
  end

  test "a teacher is refused in 403 and nothing is created; a visitor is sent to sign in" do
    post classroom_generations_path
    assert_response :redirect
    assert_not_equal teams_imports_path, response.location

    sign_in_as create_teacher
    post classroom_generations_path

    assert_response :forbidden
    assert_equal 0, Orm::ImportReport.count
  end
end

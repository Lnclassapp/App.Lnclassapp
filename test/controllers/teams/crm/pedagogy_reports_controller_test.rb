require "test_helper"

# CA-29, CA-30, CA-01 (ADR-XXXX modèles de langage, UDR-XXXX assistants du suivi) : POST met la synthèse en file puis redirige vers la page
# imprimable ; une école sans activité l'annonce sans appeler le modèle ; content reçoit 403 ; un identifiant inconnu ou d'un autre type, 404.
class Teams::Crm::PedagogyReportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", drena: create_drena(name: "Abidjan 1"))
    @field = create_team_member(team_role: "field")
    @repository = Repositories::Crm::GenerationRepository.new
    @level = create_level(name: "Tle", position: 7)
    @classroom = create_classroom(school: @school, level: @level, name: "Tle D 1")
  end

  def post_report(school = @school, **headers) = post teams_school_pedagogy_reports_path(school.public_id), as: :turbo_stream, headers: headers

  # Une école active : deux élèves, un devoir rendu par un seul, une lacune.
  def add_activity
    material = create_material(name: "Mathématiques", shortname: "Maths")
    course = create_course(level: @level, material:, name: "Maths Tle")
    @students = Array.new(2) { |index| create_student(classroom: @classroom, first_name: "Zébulon#{index}", last_name: "Quentarin") }
    exercise = create_exercise(course:)
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: create_teacher(school: @school))
    create_exercise_session(student: @students.first, exercise:, status: "completed", score_percent: 80, classroom_assignment: assignment)
    create_gap(student: @students.last, essential: create_essential(course:, name: "Les fractions"))
  end

  def complete(generation, content)
    @repository.complete(public_id: generation.public_id, content:, model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)
  end

  test "CA-29: a school with activity gets a job and a redirect to the printable page" do
    add_activity
    sign_in_as @field

    assert_enqueued_with(job: Crm::PedagogyReportJob) { post_report }

    generation = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    assert_not_nil generation
    assert_redirected_to teams_pedagogy_report_path(generation.public_id)
  end

  test "CA-30: a school without activity says so, creates nothing and never reaches the model" do
    create_student(classroom: @classroom)
    sign_in_as @field

    assert_no_enqueued_jobs { post_report }

    assert_response :success
    assert_select "turbo-stream[action=update][target=school_crm_briefing]"
    assert_includes response.body, "Pas encore assez d&#39;activité"
    assert_nil @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    assert_equal 0, Orm::CrmGeneration.count
  end

  test "a second post with the same figures redirects to the same report and enqueues nothing" do
    add_activity
    sign_in_as @field
    post_report
    generation = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    complete(generation, "Synthèse")
    clear_enqueued_jobs

    assert_no_enqueued_jobs { post_report }

    assert_redirected_to teams_pedagogy_report_path(generation.public_id)
  end

  test "Réessayer from inside the generation frame swaps in the new generation without leaving the page" do
    add_activity
    sign_in_as @field
    post_report
    failed = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    @repository.mark_failed(public_id: failed.public_id, error_code: "timeout", duration_ms: 1)

    post_report("Turbo-Frame" => "generation_#{failed.public_id}")

    assert_response :success
    renewed = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    assert_not_equal failed.public_id, renewed.public_id
    assert_select "turbo-stream[action=replace][target=?]", "generation_#{failed.public_id}"
    assert_includes response.body, "generation_#{renewed.public_id}"
  end

  test "content and a teacher get 403, a visitor is sent to sign in, and nothing is enqueued" do
    add_activity
    [ create_team_member(team_role: "content"), create_teacher ].each do |user|
      sign_in_as user
      assert_no_enqueued_jobs { post_report }
      assert_response :forbidden
      sign_out
    end

    assert_no_enqueued_jobs { post_report }
    assert_redirected_to new_session_path
    assert_equal 0, Orm::CrmGeneration.count
  end

  test "a conflict is a visible message in the frame, with a 409" do
    add_activity
    sign_in_as @field
    racing = Class.new(Repositories::Crm::GenerationRepository) do
      def create_pending(generation:) = Shared::Result.failure(:conflict)
      def pending_for(school_id:, kind:) = nil
    end.new
    Repositories::Crm::GenerationRepository.define_singleton_method(:new) { |*| racing }

    post_report

    assert_response :conflict
    assert_select "turbo-stream[action=update][target=school_crm_briefing]"
    assert_select "[role=status]", text: /Une préparation est déjà en cours, réessayez dans un instant/
  ensure
    Repositories::Crm::GenerationRepository.singleton_class.send(:remove_method, :new)
  end

  test "any other failure is a message in the frame too, not a 409" do
    add_activity
    sign_in_as @field
    refusing = Class.new(Repositories::Crm::GenerationRepository) { def mark_failed(**) = Shared::Result.failure(:not_found) }.new
    Repositories::Crm::GenerationRepository.define_singleton_method(:new) { |*| refusing }
    Crm::PedagogyReportJob.define_singleton_method(:perform_later) { |*| false }

    post_report

    assert_response :service_unavailable
    assert_select "[role=alert]", text: /L'assistant est indisponible/
  ensure
    Repositories::Crm::GenerationRepository.singleton_class.send(:remove_method, :new)
    Crm::PedagogyReportJob.singleton_class.send(:remove_method, :perform_later)
  end

  test "an unknown school is a 404" do
    sign_in_as @field
    post teams_school_pedagogy_reports_path("unknown-public"), as: :turbo_stream
    assert_response :not_found
  end

  test "CA-29: the page shows the four figures, the success per subject, the gaps and the synthesis" do
    add_activity
    sign_in_as @field
    post_report
    generation = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    complete(generation, "<b>Bon</b> début\nLes fractions inquiètent")

    get teams_pedagogy_report_path(generation.public_id)

    assert_response :success
    assert_select "h1", text: /Rapport pédagogique/
    assert_includes response.body, "Lycée Classique d&#39;Abidjan"
    assert_includes response.body, "Abidjan 1"
    assert_select "[data-testid=figure]", 4
    assert_select "[data-testid=figure-active]", text: /2/
    assert_select "[data-testid=figure-submission]", text: /50 %/
    assert_select "table tbody tr", 1
    assert_select "table", text: /Mathématiques/
    assert_select "[data-testid=gap]", text: /Les fractions/
    assert_select "[data-testid=gap]", text: /1 élève/
    assert_select "p.whitespace-pre-line", text: /Les fractions inquiètent/
    assert_includes response.body, "&lt;b&gt;Bon&lt;/b&gt;"
    assert_not_includes response.body, "<b>Bon</b>"
    assert_not_includes response.body, "Zébulon"
  end

  test "the page prints cleanly: print controller, actions hidden on paper, no horizontal overflow classes" do
    add_activity
    sign_in_as @field
    post_report
    generation = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    complete(generation, "Synthèse")

    get teams_pedagogy_report_path(generation.public_id)

    assert_select "[data-controller~=print] [data-print-target=button].print\\:hidden[hidden]"
    assert_select "[data-controller~=print] .print\\:hidden", minimum: 2
    assert_select "table tbody tr.print\\:break-inside-avoid"
    assert_select "div.overflow-x-auto table"
  end

  test "a pending synthesis shows the figures and the waiting state with the poll" do
    add_activity
    sign_in_as @field
    post_report
    generation = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")

    get teams_pedagogy_report_path(generation.public_id)

    assert_select "[data-testid=figure]", 4
    assert_select "[data-controller=generation-poll][data-generation-poll-url-value=?]", teams_generation_path(generation.public_id)
    assert_select "[role=status]", text: /Rédaction de la synthèse/
  end

  test "a failed synthesis keeps the figures and offers Réessayer towards the school route" do
    add_activity
    sign_in_as @field
    post_report
    generation = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    @repository.mark_failed(public_id: generation.public_id, error_code: "timeout", duration_ms: 1)

    get teams_pedagogy_report_path(generation.public_id)

    assert_select "[data-testid=figure]", 4
    assert_select "[role=alert]", text: /L'assistant n'a pas répondu/
    assert_select "a[href=?][data-turbo-method=post]", teams_school_pedagogy_reports_path(@school.public_id), text: /Réessayer/
  end

  test "CA-30: a report whose school lost its activity shows the empty state instead of figures" do
    add_activity
    sign_in_as @field
    post_report
    generation = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    Orm::KnowledgeGap.delete_all
    Orm::ExerciseSession.delete_all
    Orm::ClassroomAssignment.delete_all

    get teams_pedagogy_report_path(generation.public_id)

    assert_response :success
    assert_includes response.body, "Pas encore assez d&#39;activité"
    assert_select "[data-testid=figure]", 0
  end

  test "the report of one school shows its own figures, never another school's" do
    add_activity
    other = create_school
    other_classroom = create_classroom(school: other, level: @level, name: "Tle A 1")
    create_exercise_session(student: create_student(classroom: other_classroom), status: "completed", score_percent: 10)
    sign_in_as @field
    post_report
    mine = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")

    get teams_pedagogy_report_path(mine.public_id)

    assert_select "[data-testid=figure-active]", text: /2/
    assert_includes response.body, "Lycée Classique d&#39;Abidjan"
  end

  test "an unknown id and the id of another kind of generation are 404" do
    sign_in_as @field
    get teams_pedagogy_report_path("unknown-public")
    assert_response :not_found

    briefing = @repository.create_pending(generation: Entities::Crm::Generation.new(
      public_id: nil, school_id: @school.id, kind: "briefing", status: "pending", requested_by_id: @field.id, follow_up_id: nil,
      input_fingerprint: nil, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
    )).value
    get teams_pedagogy_report_path(briefing.public_id)
    assert_response :not_found
  end

  test "content and a teacher get 403 on the page, a visitor is sent to sign in" do
    add_activity
    sign_in_as @field
    post_report
    generation = @repository.pending_for(school_id: @school.id, kind: "pedagogy_report")
    sign_out

    [ create_team_member(team_role: "content"), create_teacher ].each do |user|
      sign_in_as user
      get teams_pedagogy_report_path(generation.public_id)
      assert_response :forbidden
      sign_out
    end

    get teams_pedagogy_report_path(generation.public_id)
    assert_redirected_to new_session_path
  end
end

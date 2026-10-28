require "test_helper"

# CA-11, AS-37 — UDR-0015. The page of an essential sheet: its content rendered by Action Text, then its exercises. The
# student sees only the published ones, each with his badge, best score and « Commencer » or « Reprendre », and the
# label « Assigné par ton enseignant ». The team sees every exercise and its menu opens in the modal. Outside the team,
# a draft sheet, or a sheet of a draft course, answers 404. The old page showed a fake « Conforme au programme » banner.
class Catalog::EssentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Génétique et évolution", level: create_level(name: "Tle"), series: create_series(name: "D"),
                            material: create_material(name: "SVT", category: "science"))
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe de Tle D, le niveau du cours.
    @classroom = create_classroom(level: @course.level, series: @course.series)
    @essential = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions",
                                  content: "<p>Le <strong>brassage</strong> génétique : $2^n$ combinaisons.</p>")
    @exercise = create_exercise(essential: @essential, title: "Méiose et ADN", statement: "Deux divisions successives.",
                                position: 1)
    @student = create_student(classroom: @classroom)
  end

  def scope = "catalog.essentials"
  def page_path(essential = @essential) = course_essential_path(essential.course.slug, essential.slug)
  def row_of(exercise) = "#essential_exercise_#{exercise.public_id}"

  test "the student sees the sheet, its content and each published exercise with his progress" do
    doing = create_exercise(essential: @essential, title: "Anomalies", position: 2)
    create_exercise(essential: @essential, title: "Brouillon caché", status: "draft", position: 3)
    create_exercise(essential: @essential, title: "Archive cachée", status: "archived", position: 4)
    best = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 85)
    create_badge(student: @student, exercise: @exercise, level: "gold", session: best)
    started = create_exercise_session(student: @student, exercise: doing)
    create_assignment(classroom: @classroom, assignable: doing)
    sign_in_as @student

    get page_path

    assert_response :success
    assert_select "title", text: /#{I18n.t("#{scope}.show.page_title", name: "La méiose")}/
    assert_select "#essential_header h1", text: "La méiose"
    assert_select "#essential_header", text: /Deux divisions/
    assert_select "#essential_header", text: /SVT/
    assert_select "#essential_header", text: /Tle D/
    assert_select "#essential_header a[href='#{course_path(@course.slug)}']", text: /Génétique et évolution/
    assert_select "#essential_content[data-controller=math] .trix-content strong", text: "brassage"
    assert_select "#essential_exercises li", 2
    assert_select "#essential_exercises", text: /#{I18n.t("#{scope}.show.exercises_count", count: 2)}/
    assert_no_match(/Brouillon caché|Archive cachée/, response.body)

    # UDR-0015, amendement du 2026-10-02 (UDR-0057) : surtitre sans le cours, que le retour nomme déjà ; plus d'aide « Badges ».
    assert_select "#essential_header p", text: I18n.t("#{scope}.show.student_eyebrow")
    # UDR-0130 : le surtitre nomme la fiche de révision, jamais la « fiche essentielle ».
    assert_select "#essential_header p", text: "Fiche de révision"
    assert_select "#essential_header", text: /essentielle/i, count: 0
    assert_select "#essential_badges_help", 0
    # Une ligne = un lien étiré, le titre, « Type · Assigné par ton enseignant », une seule action à droite.
    assert_select row_of(@exercise) do
      assert_select "a.line-clamp-2.after\\:absolute.after\\:inset-0[href='#{exercise_path(@exercise.public_id)}']", text: "Méiose et ADN"
      assert_select "p.text-mute", text: I18n.t("#{scope}.exercise_progress.exercise_types.fixation")
      assert_select "*", text: /Deux divisions successives|Badge|Meilleur score|Acquis|question/, count: 0
      assert_select "form[method=post][action='#{exercise_sessions_path(@exercise.public_id)}'] button.ui-button-primary",
                    text: I18n.t("#{scope}.exercise_progress.redo")
    end
    assert_select row_of(doing) do
      assert_select "p.text-mute", text: "#{I18n.t("#{scope}.exercise_progress.exercise_types.fixation")} · " \
                                         "#{I18n.t("#{scope}.exercise_progress.assigned")}"
      assert_select "a.ui-button-secondary[href='#{exercise_session_path(started.public_id)}']", text: I18n.t("#{scope}.exercise_progress.resume")
      assert_select "form", 0
    end
    # R1 : seule la première ligne garde « primary » ; aucun « brand ».
    assert_select "#essential_exercises .ui-button-primary", 1
    assert_select "#essential_exercises .ui-button-brand", 0

    assert_select "#essential_team_actions", 0
    assert_select "#content_status_essential_#{@essential.slug}", 0
    assert_select "a[data-turbo-frame=modal]", 0
    assert_select "#essential_gap_since", 0
  end

  test "the old page's leaks and fake promises are gone: no correct answer, no conformity label, no forbidden word" do
    sign_in_as @student

    get page_path

    assert_response :success
    assert_no_match(/Proposition 1|data-correct/, response.body)
    assert_no_match(/conforme au programme|validation collaborative|habilet/i, response.body)
  end

  # CA-E4 (UDR écrans élève §3.4) : l'étiquette « À revoir depuis le <date> » sous le titre ; la carte du bas n'existe plus.
  test "CA-E4: the student's pending gap is a label under the title, and the « Fiche à revoir » card is gone" do
    create_gap(student: @student, essential: @essential, created_at: Time.zone.local(2026, 9, 12, 10))
    create_exercise(essential: @essential, title: "Thalès 3", exercise_type: "fixation", position: 3)
    sign_in_as @student

    get page_path

    assert_select "#essential_header h1 ~ div #essential_gap_since", text: "À revoir depuis le 12 sept."
    assert_select "#essential_gap", 0
    assert_select "form#essential_gap_form, #essential_gap_action, #essential_gap_exercise", 0
    assert_no_match(/Fiche à revoir|Refaire un exercice|Exercice proposé/, response.body)
    assert_no_match(/75 %/, response.body)
  end

  test "starting an exercise of a sheet with a pending gap is a remediation session" do
    gap = create_gap(student: @student, essential: @essential,
                     source_session: create_exercise_session(student: @student, exercise: @exercise, status: "completed",
                                                             score_percent: 30))
    other = create_exercise(essential: @essential, title: "Thalès 2", exercise_type: "evaluation", position: 2)
    sign_in_as @student

    assert_difference -> { Orm::ExerciseSession.count }, 1 do
      post exercise_sessions_path(other.public_id)
    end

    session = Orm::ExerciseSession.order(:id).last
    assert_equal [ other.id, "remediation", gap.id ], [ session.exercise_id, session.kind, session.knowledge_gap_id ]
    assert_redirected_to exercise_session_path(session.public_id)
  end

  test "beyond 3 exercises, the student sees 3 rows then « Voir plus », the others rendered hidden" do
    titles = %w[Anomalies Brassage Caryotype]
    titles.each_with_index { |title, index| create_exercise(essential: @essential, title:, position: index + 2) }
    sign_in_as @student

    get page_path

    assert_select "#essential_exercises [data-controller=reveal]" do
      assert_select "li", 4
      assert_select "li[data-reveal-target=item]", 4
      assert_select "li[hidden]", 1
      assert_select "li[hidden]", text: /Caryotype/
      assert_select "button[data-action='reveal#more']", text: I18n.t("components.reveal.more")
    end
    assert_select "#essential_exercises .ui-button-primary", 1
    assert_select "#{row_of(@exercise)} .ui-button-primary", 1
  end

  # CA-E12 (UDR écrans élève §3.6 bis) : dès 1 024 px, l'élève lit la fiche à gauche et une colonne de 300 px collante à droite.
  test "CA-E12: for the student, the sheet on the left and the « Exercices » card in a sticky 300 px column on the right" do
    sign_in_as @student

    get page_path

    assert_select "#essential_layout[class~='lg:grid-cols-main-side']" do
      assert_select "> #essential_header"
      assert_select "> #essential_side.lg\\:sticky > #essential_exercises"
    end
  end

  test "CA-E12: the teacher and the team keep the old layout, the card under the sheet" do
    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user

      get page_path

      assert_select "#essential_layout", 0
      assert_select "#essential_side", 0
      assert_select "#essential_exercises"
      # Ce que voit l'enseignant : pas de deux colonnes, et la carte « Exercices » vient après le titre de la fiche.
      assert_select "[class~='lg:grid-cols-main-side']", 0
      assert_equal [ "h1", "essential_exercises" ], css_select("main h1, #essential_exercises").map { it["id"] || it.name }
    end
  end

  test "the teacher reads the published exercises, without progress, session button nor team menu" do
    create_exercise(essential: @essential, title: "Brouillon caché", status: "draft")
    sign_in_as create_teacher

    get page_path

    assert_response :success
    # Décision du porteur du 2026-10-02 : la ligne de l'enseignant et le surtitre restent inchangés.
    assert_select "#essential_header p", text: I18n.t("#{scope}.show.eyebrow", course: "Génétique et évolution")
    assert_select "#essential_header p", text: "Fiche de révision · Génétique et évolution"
    assert_select row_of(@exercise) do
      assert_select "a[href='#{exercise_path(@exercise.public_id)}']", text: "Méiose et ADN"
      assert_select "a.ui-button-secondary[href='#{exercise_path(@exercise.public_id)}']", text: I18n.t("#{scope}.exercise_progress.open")
      assert_select "*", text: /Deux divisions successives\./
      assert_select "*", text: /#{I18n.t("#{scope}.exercise_progress.exercise_types.fixation")}/
      assert_select "*", text: /#{I18n.t("#{scope}.exercise_progress.questions", count: 2)}/
      assert_select "form", 0
      assert_select "*", text: /Meilleur score|Pas encore de session/, count: 0
    end
    assert_no_match(/Brouillon caché/, response.body)
    assert_select "#essential_team_actions", 0
    assert_select "#essential_exercises .ui-button-primary, #essential_exercises .ui-button-brand", 0
  end

  # RE-21, RE-23 — UDR-0069 §3.8 : sous chaque exercice publié, une bascule par classe de l'enseignant du niveau et de la
  # série du cours, triées par nom ; la bascule de la classe (UDR-0062 §3.4), dont les libellés nomment la classe.
  test "the teacher gets one toggle per classroom of the course's level and series under each published exercise" do
    travel_to Time.zone.local(2026, 10, 5, 10)
    brassage = create_exercise(essential: @essential, title: "Brassage", position: 2)
    create_exercise(essential: @essential, title: "Brouillon caché", status: "draft", position: 3)
    school = create_school
    tle_d1, tle_d2 = [ "Tle D 1", "Tle D 2" ].map { |name| create_classroom(school:, level: @course.level, series: @course.series, name:) }
    tle_c1 = create_classroom(school:, level: @course.level, series: create_series(name: "C"), name: "Tle C 1")
    teacher = create_teacher(school:, classrooms: [ tle_d2, tle_c1, tle_d1 ])
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: teacher.id, classroom_id: tle_d1.id,
                                                                weekdays: [ 1, 4 ], at: Time.current)
    assignment = create_assignment(classroom: tle_d1, assignable: @exercise, by: teacher, due_on: Date.new(2026, 10, 8))
    sign_in_as teacher

    get page_path

    assert_response :success
    assert_select "#assign_targets_none", 0
    assert_select "#essential_exercises [id^='assignment_']", 4
    assert_select "[id^='assignment_#{tle_c1.public_id}_']", 0
    assert_no_match(/Brouillon caché/, response.body)
    assert_select row_of(@exercise) do
      assert_select "ul[aria-label=?]", I18n.t("#{scope}.exercise_progress.assign_targets", title: "Méiose et ADN") do |list|
        assert_equal [ "Tle D 1", "Tle D 2" ], list.css("li [id^='assignment_'] > div > p:first-child").map { it.text.strip }
      end
      # CA-7 (UDR-0077 §3.3) : une ligne compacte — la classe, l'échéance dessous, « Assigné » et ✕ à droite.
      assert_select "#assignment_#{tle_d1.public_id}_Exercise_#{@exercise.public_id}.flex.justify-between" do
        assert_select "div > p:first-child", text: "Tle D 1"
        assert_select "div > p.text-xs", text: "Pour jeu. 8 oct."
        assert_select "*", text: /Assigné/
        assert_select "form[action='#{archive_assignment_path(assignment.public_id)}'] input[name=compact][value='1']"
        assert_select "form[action='#{archive_assignment_path(assignment.public_id)}'] button.ui-icon-button[aria-label=?]",
                      "Retirer « Méiose et ADN » de Tle D 1", text: ""
      end
      # Tle D 2 : pas encore de jours, « Assigner » ouvre la modale des jours.
      assert_select "#assignment_#{tle_d2.public_id}_Exercise_#{@exercise.public_id} a[data-turbo-frame=modal][href=?][aria-label=?]",
                    new_classroom_assignment_path(tle_d2.public_id, assignable_key: @exercise.public_id, compact: 1),
                    "Assigner « Méiose et ADN » à Tle D 2"
      assert_select "#assignment_#{tle_d2.public_id}_Exercise_#{@exercise.public_id} p.text-xs", 0
      # Sur téléphone, le titre suffit : « Ouvrir » ne se montre qu'à partir de 640 px.
      assert_select "a.hidden.sm\\:inline-flex[href='#{exercise_path(@exercise.public_id)}']",
                    text: I18n.t("#{scope}.exercise_progress.open")
      assert_select "p.text-meta.text-mute", text: "#{I18n.t("#{scope}.exercise_progress.exercise_types.#{@exercise.exercise_type}")} · " \
                                                  "#{I18n.t("#{scope}.exercise_progress.questions", count: @exercise.questions.count)}"
    end
    # Tle D 1 : jours connus, « Assigner » assigne en un clic.
    assert_select "#assignment_#{tle_d1.public_id}_Exercise_#{brassage.public_id} " \
                  "form[action='#{classroom_assignments_path(tle_d1.public_id)}']:has(input[name=compact][value='1']) button[aria-label=?]",
                  "Assigner « Brassage » à Tle D 1"
  end

  # RE-24 — UDR-0069 §3.8 : aucune classe au niveau du cours, aucune bascule ; une phrase le dit au-dessus des exercices.
  test "a teacher without any classroom of the course's level reads « Aucune de vos classes n'est en 3ème. »" do
    course = create_course(level: create_level(name: "3ème"), name: "Nombres et calculs")
    essential = create_essential(course:)
    create_exercise(essential:)
    sign_in_as create_teacher(classrooms: [ create_classroom(level: @course.level, series: @course.series, name: "Tle D 1") ])

    get page_path(essential)

    assert_response :success
    assert_select "#essential_exercises #assign_targets_none", text: "Aucune de vos classes n'est en 3ème."
    assert_select "[id^='assignment_']", 0
    assert_select "#essential_exercises ul[aria-label]", 0
  end

  # RE-26 — UDR-0069 §3.8 : l'équipe n'a pas de classe ; ni bascule ni phrase pour elle, ni pour l'élève. Son menu ⋮ reste.
  test "the team and the student see no assignment toggle on a published sheet" do
    create_teacher(classrooms: [ create_classroom(level: @course.level, series: @course.series) ])
    menu = "#essential_team_actions button[aria-haspopup=menu]"

    [ [ create_team_member, 1 ], [ @student, 0 ] ].each do |user, menus|
      sign_in_as user
      get page_path

      assert_response :success
      assert_select "[id^='assignment_']", 0
      assert_select "#assign_targets_none", 0
      assert_select "#essential_exercises ul[aria-label]", 0
      assert_select menu, menus
      sign_out
    end
  end

  test "the team opens a draft sheet of a draft course: status panel, menu in the modal, every exercise with its status" do
    course = create_course(status: "draft")
    essential = create_essential(course:, name: "Anomalies de la méiose", status: "draft", subtitle: nil)
    create_exercise(essential:, title: "Publié", position: 1)
    create_exercise(essential:, title: "En brouillon", status: "draft", position: 2)
    create_exercise(essential:, title: "Archivé", status: "archived", position: 3)
    sign_in_as create_team_member

    get page_path(essential)

    assert_response :success
    assert_select "#content_status_essential_#{essential.slug}", text: /Brouillon/
    assert_select "#content_status_essential_#{essential.slug} form, #content_status_essential_#{essential.slug} a", 0
    assert_select "#essential_team_actions" do
      # Épuration des en-têtes (2026-09-30) : seul le statut reste visible ; modifier, créer, importer et publier sont dans
      # le menu ⋮ (UDR-0042).
      assert_select "button[aria-haspopup=menu][aria-label=?]", I18n.t("#{scope}.show.actions", name: essential.name)
      assert_select "[role=menu]" do
        assert_select "a[role=menuitem][data-turbo-frame=modal][href='#{edit_teams_essential_path(essential.slug)}']",
                      text: I18n.t("#{scope}.show.edit")
        assert_select "a[role=menuitem][data-turbo-frame=modal][href='#{new_teams_essential_exercise_path(essential.slug)}']",
                      text: I18n.t("#{scope}.show.new_exercise")
        assert_select "a[href*=?]", "kind=exercises", 0
        assert_select "#content_transitions_essential_#{essential.slug} a[role=menuitem][data-turbo-method=patch]" \
                      "[href='#{publish_teams_essential_path(essential.slug)}']"
        assert_select "a[role=menuitem][data-turbo-method=patch][href='#{publish_all_teams_essential_path(essential.slug)}']",
                      text: I18n.t("catalog.content_status.actions.publish_all")
        assert_select "[role=menuitem]", 4
      end
    end
    assert_select "#essential_header p", text: I18n.t("#{scope}.show.eyebrow", course: course.name)
    assert_select "#essential_exercises li", 3
    assert_select "#essential_exercises li[hidden]", 0
    assert_select "#essential_exercises", text: /Brouillon — visible uniquement par l'équipe/
    assert_select "#essential_exercises", text: /Archivé/
    assert_select "#essential_subtitle", 0
    assert_select "#essential_exercises form", 0
  end

  test "empty states: the student learns nothing is published yet, the team is told how to add exercises" do
    empty = create_essential(course: @course, name: "Vide", content: nil)
    create_exercise(essential: empty, status: "draft")
    sign_in_as @student

    get page_path(empty)

    assert_select "#essential_content", text: /#{I18n.t("#{scope}.show.no_content")}/
    assert_select "#essential_exercises", text: /#{I18n.t("#{scope}.show.empty_title")}/
    sign_out

    sign_in_as create_team_member
    get page_path(empty)

    assert_select "#essential_exercises li", 1
    get page_path(create_essential(course: @course, name: "Nue", status: "draft"))

    assert_select "#essential_exercises", text: /#{I18n.t("#{scope}.show.team_empty_title")}/
    assert_select "#essential_exercises", text: /Aucun exercice pour cette fiche de révision\./
  end

  test "outside the team, a draft or archived sheet, or a sheet of a draft course, answers 404 without its content" do
    draft = create_essential(course: @course, name: "Brouillon", status: "draft")
    archived = create_essential(course: @course, name: "Archivée", status: "archived")
    in_draft_course = create_essential(course: create_course(status: "draft"), name: "Cours brouillon")

    [ @student, create_teacher ].each do |user|
      sign_in_as user
      [ draft, archived, in_draft_course ].each do |essential|
        get page_path(essential)

        assert_response :not_found
        assert_no_match(/#{essential.name}|L'essentiel à retenir/, response.body)
      end
      sign_out
    end
    assert_equal 0, Orm::EssentialRead.count
  end

  test "an unknown sheet, or a sheet read under another course, answers 404" do
    sign_in_as @student

    get course_essential_path(@course.slug, "inconnue")
    assert_response :not_found

    get course_essential_path(create_course.slug, @essential.slug)
    assert_response :not_found
  end

  # UDR-0130 §3 : le renommage ne touche aucune adresse ; un lien partagé avant lui s'ouvre sans redirection.
  test "a link shared before the renaming, /courses/<course>/essentials/<sheet>, still opens without redirect" do
    sign_in_as @student

    get "/courses/#{@course.slug}/essentials/#{@essential.slug}"

    assert_response 200
    assert_select "#essential_header h1", text: "La méiose"
  end

  test "without a session, the page sends to the sign-in" do
    get page_path

    assert_redirected_to new_session_path
  end

  # ── Lecture retenue (chantier cours-eleve, ADR-0090 §4.1) ────────────────────

  def reads_of(user) = Orm::EssentialRead.where(student_id: user.id)

  test "CA-7, CA-12: the student's opening of a sheet is kept, once, with the time of the last opening" do
    sign_in_as @student
    first = Time.current.change(usec: 0)
    last = first + 40.minutes

    travel_to(first) { get page_path }
    assert_response :success
    travel_to(last) { get page_path }

    assert_equal [ [ @essential.id, first, last ] ], reads_of(@student).pluck(:essential_id, :first_read_at, :last_read_at)
  end

  test "a link prefetched by Turbo on hover is not an opening: no read, the page still answers" do
    sign_in_as @student

    [ { "X-Sec-Purpose" => "prefetch" }, { "Sec-Purpose" => "prefetch;prerender" }, { "Purpose" => "prefetch" } ].each do |headers|
      get(page_path, headers:)
      assert_response :success
    end

    assert_equal 0, Orm::EssentialRead.count
  end

  test "a prefetch of a sheet already read leaves its last opening unchanged" do
    read = create_essential_read(student: @student, essential: @essential, at: 2.days.ago.change(usec: 0))
    sign_in_as @student

    get page_path, headers: { "X-Sec-Purpose" => "prefetch" }

    assert_equal read.last_read_at, read.reload.last_read_at
  end

  test "a student without a classroom of the year opens no sheet (404) and leaves no read" do
    sign_in_as create_student

    get page_path

    assert_response :not_found
    assert_equal 0, Orm::EssentialRead.count
  end

  test "CA-11: a teacher or a team member opening a sheet leaves no read" do
    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user
      get page_path

      assert_response :success
      sign_out
    end

    assert_equal 0, Orm::EssentialRead.count
  end

  test "a sheet the student may not read (draft, another level, another course) leaves no read" do
    draft = create_essential(course: @course, status: "draft")
    other_level = create_essential(course: create_course(level: create_level))
    sign_in_as @student

    [ page_path(draft), page_path(other_level), course_essential_path(create_course.slug, @essential.slug) ].each do |path|
      get path
      assert_response :not_found
    end

    assert_equal 0, Orm::EssentialRead.count
  end

  # The recording raises `error` for the duration of the block.
  def with_failing_record(error)
    repository = Repositories::Assessment::EssentialReadRepository
    repository.alias_method :original_record, :record
    repository.define_method(:record) { |student_id:, essential_id:, at:| raise error }
    yield
  ensure
    repository.alias_method :record, :original_record
    repository.remove_method :original_record
  end

  test "an outage of the recording never blocks the sheet: it is reported as handled, with the sheet and the student" do
    sign_in_as @student

    [ ActiveRecord::ConnectionTimeoutError.new("pool épuisé"), ActiveRecord::InvalidForeignKey.new("fiche supprimée") ].each do |error|
      report = with_failing_record(error) { assert_error_reported(error.class) { get page_path } }

      assert_response :success
      assert_select "#essential_header h1", text: "La méiose"
      assert report.handled
      assert_equal({ essential_id: @essential.id, student_id: @student.id }, report.context.slice(:essential_id, :student_id))
    end
    assert_equal 0, Orm::EssentialRead.count
  end

  test "any other database error is a bug: it is raised, not swallowed" do
    sign_in_as @student

    with_failing_record(ActiveRecord::StatementInvalid.new("syntaxe")) do
      assert_raises(ActiveRecord::StatementInvalid) { get page_path }
    end
  end
end

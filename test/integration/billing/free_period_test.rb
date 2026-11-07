require "test_helper"

# cartes-activation, Lot B (PRD §4 « Période gratuite et blocage », ADR contexte billing §4.5 et §4.6, UDR-0158 §3) :
# 7 jours gratuits à partir du 2026-11-09, puis « Commencer » et la vérification d'une fiche mènent à Mon abonnement sans rien écrire ;
# leçons, exercices et historique restent lisibles ; un enseignant n'est jamais bloqué.
class BillingFreePeriodTest < ActionDispatch::IntegrationTest
  CREATED_ON = Time.zone.local(2026, 11, 9, 10)
  LAST_FREE_DAY = Time.zone.local(2026, 11, 15, 12)
  BLOCKED_DAY = Time.zone.local(2026, 11, 16, 12)

  setup do
    @exercise = create_exercise(title: "Méiose", questions: 2)
    @course = @exercise.essential.course
    @classroom = create_classroom(level: @course.level, series: @course.series)
  end

  def student_created(at)
    travel_to(at) { create_student(classroom: @classroom) }
  end

  def start(exercise = @exercise) = post(exercise_sessions_path(exercise.public_id))

  test "le 7e jour : la séance démarre et l'accueil dit « Il te reste 1 jour gratuit »" do
    student = student_created(CREATED_ON)
    travel_to(LAST_FREE_DAY) do
      sign_in_as student

      get student_home_path
      assert_select "section[aria-label='#{I18n.t('billing.subscriptions.home_notice.label')}']", text: /Il te reste 1 jour gratuit/

      assert_difference -> { Orm::ExerciseSession.count }, 1 do
        start
      end
      assert_redirected_to exercise_session_path(Orm::ExerciseSession.sole.public_id)
    end
  end

  test "le 8e jour : rien n'est créé, redirection vers Mon abonnement avec le chemin de retour" do
    student = student_created(CREATED_ON)
    travel_to(BLOCKED_DAY) do
      sign_in_as student

      assert_no_difference -> { Orm::ExerciseSession.count } do
        start
      end

      assert_redirected_to billing_subscription_path
      assert_equal I18n.t("billing.subscription_required"), flash[:info]
      assert_nil flash[:alert]
      assert_equal exercise_path(@exercise.public_id), session[:billing_return_to]
    end
  end

  test "un compte antérieur au lancement reste gratuit jusqu'au 2026-11-15" do
    student = student_created(Time.zone.local(2026, 10, 1, 9))
    travel_to(LAST_FREE_DAY) do
      sign_in_as student

      assert_difference -> { Orm::ExerciseSession.count }, 1 do
        start
      end
    end
  end

  test "un exercice donné par l'enseignant est bloqué comme un exercice libre" do
    student = student_created(CREATED_ON)
    teacher = create_teacher(classrooms: [ @classroom ])
    create_assignment(classroom: @classroom, assignable: @exercise, by: teacher)
    travel_to(BLOCKED_DAY) do
      sign_in_as student

      assert_no_difference -> { Orm::ExerciseSession.count } do
        start
      end
      assert_redirected_to billing_subscription_path
    end
  end

  test "la vérification d'une fiche est refusée et mène à Mon abonnement, rien n'est écrit" do
    student = student_created(CREATED_ON)
    questions = @exercise.questions.order(:position).to_a
    answers = questions.to_h { |question| [ question.id.to_s, { display_order: [ "0" ] } ] }
    travel_to(BLOCKED_DAY) do
      sign_in_as student

      assert_no_difference -> { Orm::ExerciseSession.count } do
        post exercise_sheet_check_path(@exercise.public_id), params: { copy: { answers: } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      assert_redirected_to billing_subscription_path
      assert_equal 303, response.status
    end
  end

  test "la vérification d'un entraînement de notion est refusée dans son frame et mène à Mon abonnement" do
    course = create_course(name: "Racines carrées", content: "")
    notion = create_practice_notion(course:, questions: [ numeric_question ])
    student = travel_to(CREATED_ON) { create_student_for(course) }
    digest = Entities::Catalog::NotionPractice.from_raw(raw_practice(numeric_question)).digest
    travel_to(BLOCKED_DAY) do
      sign_in_as student

      post practice_check_path(course_slug: course.slug, slug: notion.slug), params: { digest:, answers: {} }
      assert_redirected_to billing_subscription_path

      post practice_check_path(course_slug: course.slug, slug: notion.slug), params: { digest:, answers: {} },
                                                                           headers: { "Turbo-Frame" => "practice_#{notion.slug}" }
      assert_response :payment_required
      assert_select "turbo-frame#practice_#{notion.slug}[target='_top'] a[href='#{billing_subscription_path}']"
    end
  end

  test "bout en bout : bloqué au 8e jour, il active un code, revient à l'exercice et le démarre" do
    student = student_created(CREATED_ON)
    code = Orm::Billing::ActivationCard.where(state: "issued").order(:serial).first.code
    travel_to(BLOCKED_DAY) do
      sign_in_as student

      assert_no_difference -> { Orm::ExerciseSession.count } do
        start
      end
      assert_redirected_to billing_subscription_path
      assert_equal exercise_path(@exercise.public_id), session[RedirectsSubscriptionRequired::RETURN_KEY]

      post billing_activation_path, params: { code: }

      assert_redirected_to exercise_path(@exercise.public_id)
      assert_nil session[RedirectsSubscriptionRequired::RETURN_KEY]
      assert_difference -> { Orm::ExerciseSession.count }, 1 do
        start
      end
      assert_redirected_to exercise_session_path(Orm::ExerciseSession.sole.public_id)
    end
  end

  test "un élève bloqué lit ses leçons, ses exercices et son historique" do
    student = student_created(CREATED_ON)
    done = create_exercise_session(student:, exercise: @exercise, status: "completed")
    travel_to(BLOCKED_DAY) do
      sign_in_as student

      get course_path(@course.slug)
      assert_response :success
      assert_select "h1", text: /#{Regexp.escape(@course.name)}/
      assert_select "#prepare-interros .ps-card-title", text: @exercise.essential.name
      assert_select "#prepare-interros .ps-card-meta", text: "1 exercice"
      get exercise_path(@exercise.public_id)
      assert_response :success
      assert_select "h1", text: /Méiose/
      get student_home_path
      assert_response :success
      assert_select "section[aria-label='#{I18n.t('billing.subscriptions.home_notice.label')}']", text: /#{Regexp.escape(I18n.t('billing.subscriptions.home_notice.blocked'))}/

      get student_home_path, headers: { "Turbo-Frame" => Classroom::StudentHomesController::RECENT_ACTIVITY_FRAME }
      assert_response :success
      assert_equal "completed", done.reload.status
      assert_match(/Méiose/, response.body)
    end
  end

  test "un élève abonné par une carte démarre après les 7 jours et ne voit aucun bandeau" do
    student = student_created(CREATED_ON)
    travel_to(BLOCKED_DAY) do
      subscribe_student(student)
      sign_in_as student

      get student_home_path
      assert_select "section[aria-label='#{I18n.t('billing.subscriptions.home_notice.label')}']", count: 0

      assert_difference -> { Orm::ExerciseSession.count }, 1 do
        start
      end
    end
  end

  test "bandeau des trois derniers jours : même phrase du PRD, en avertissement, avec le prix" do
    student = student_created(CREATED_ON)
    travel_to(Time.zone.local(2026, 11, 13, 12)) do
      sign_in_as student

      get student_home_path

      assert_select "section[aria-label='#{I18n.t('billing.subscriptions.home_notice.label')}'] p.bg-warning-soft", text: /Il te reste 3 jours gratuits\. Abonne-toi pour 10 000 F/
    end
  end

  test "un enseignant dont le compte a plus de 7 jours n'est jamais bloqué, et n'a aucun bandeau" do
    teacher = travel_to(CREATED_ON) { create_teacher(classrooms: [ @classroom ]) }
    travel_to(BLOCKED_DAY) do
      sign_in_as teacher

      get exercise_path(@exercise.public_id)

      assert_response :success
      assert_equal :subscribed, Queries::Billing::StudentAccessQuery.new.call(student_id: teacher.id, at: Time.current).status
    end
  end
end

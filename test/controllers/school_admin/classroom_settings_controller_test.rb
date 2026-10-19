require "test_helper"

# ADR-0098, UDR-0110, UDR-0111 (PRD §4, Lot A) : la direction modifie le nom (suffixe) et le plafond d'une classe de son seul
# établissement actif, depuis la page d'un niveau. L'établissement vient du compte : la classe d'un autre est introuvable.
class SchoolAdmin::ClassroomSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    referential = seed_referential
    @tle = referential[:levels]["tle"]
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @admin = create_school_admin(school: @school)
    @classroom = create_classroom(school: @school, level: @tle, series: referential[:series]["d"], name: "Tle D 2")
    @other = create_classroom(school: create_school(name: "Collège Moderne de Cocody"), level: @tle,
                              series: referential[:series]["d"], name: "Tle D 2")
  end

  def edit_path(classroom = @classroom) = edit_school_admin_classroom_setting_path(classroom.public_id)
  def update_path(classroom = @classroom) = school_admin_classroom_setting_path(classroom.public_id)
  def including(text) = /#{Regexp.escape(text)}/
  def stored(classroom = @classroom) = Orm::Classroom.where(id: classroom.id).pick(:name, :max_students)
  def settings(suffix: "2", max_students: 60) = { classroom_settings: { suffix:, max_students: } }

  test "la carte de la page du niveau offre « Modifier la classe » ; la modale garde le préfixe « Tle D »" do
    sign_in_as @admin

    get school_admin_level_path(@tle.slug)
    assert_select "#classroom-menu-#{@classroom.public_id} a[href='#{edit_path}'][data-turbo-frame=modal]", text: "Modifier la classe"

    get edit_path
    assert_response :success
    assert_select "#classroom-settings-prefix", text: "Tle D"
    assert_select "input#classroom_settings_suffix[value='2']"
  end

  test "fixe le plafond de « Tle D 2 » à 60 : toast, page rafraîchie, trace" do
    sign_in_as @admin

    patch update_path, params: settings, as: :turbo_stream

    assert_response :success
    assert_equal [ "Tle D 2", 60 ], stored
    assert_select "turbo-stream[action=append][target=toasts]", text: including("Classe Tle D 2 enregistrée.")
    assert_select "turbo-stream[action=refresh]"
    assert_equal "classroom_updated", Orm::AuditEvent.sole.metadata["change"]
  end

  test "sans JavaScript : retour à la page du niveau avec le message" do
    sign_in_as @admin

    patch update_path, params: settings(suffix: "Bilingue")

    assert_redirected_to school_admin_level_path(@tle.slug)
    assert_equal "Classe Tle D Bilingue enregistrée.", flash[:notice]
  end

  test "plafond sous l'effectif présent : refusé sous le champ, le plafond reste" do
    42.times { create_student(classroom: @classroom) }
    sign_in_as @admin

    patch update_path, params: settings(max_students: 40)

    assert_response :unprocessable_entity
    assert_select "#classroom_settings_max_students_error", text: "La classe compte déjà 42 élèves : le plafond ne peut pas être plus bas."
    assert_equal [ "Tle D 2", 80 ], stored
  end

  test "la classe d'un autre établissement : 404, et elle n'a pas changé" do
    sign_in_as @admin

    get edit_path(@other)
    assert_response :not_found
    patch update_path(@other), params: settings, as: :turbo_stream
    assert_response :not_found

    assert_equal [ "Tle D 2", 80 ], stored(@other)
  end

  test "établissement inactif ou en brouillon : aucun geste (403), rien n'est écrit" do
    %w[inactive draft].each do |status|
      @school.update!(status:)
      sign_in_as @admin

      get edit_path
      assert_response :forbidden
      patch update_path, params: settings, as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ "Tle D 2", 80 ], stored
    assert_equal 0, Orm::AuditEvent.count
  end

  test "un enseignant ou un élève reçoit 403" do
    [ create_teacher(school: @school, classrooms: [ @classroom ]), create_student(classroom: @classroom) ].each do |outsider|
      sign_in_as outsider

      patch update_path, params: settings, as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ "Tle D 2", 80 ], stored
  end
end

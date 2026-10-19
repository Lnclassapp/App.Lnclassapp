require "test_helper"

# ADR-0098, UDR-0110, UDR-0111 (PRD §4, Lot A) : depuis la fiche d'un établissement, l'équipe ouvre « Modifier la classe »
# dans le menu ⋮ d'une carte, change la fin du nom et le plafond ; le préfixe du barème reste fixe.
class Teams::ClassroomSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    referential = seed_referential
    @levels = referential[:levels]
    @school = create_school(name: "Lycée Classique d'Abidjan", school_type: "public", cycle: "both")
    @classroom = create_classroom(school: @school, level: @levels["6eme"], name: "6ème 3")
    @tle_d = create_classroom(school: @school, level: @levels["tle"], series: referential[:series]["d"], name: "Tle D 3")
  end

  def edit_path(classroom = @classroom, school = @school) = edit_school_classroom_setting_path(school.public_id, classroom.public_id)
  def update_path(classroom = @classroom, school = @school) = school_classroom_setting_path(school.public_id, classroom.public_id)
  def error(attribute, type) = I18n.t("activemodel.errors.models.dtos/classroom/classroom_settings_input.attributes.#{attribute}.#{type}")
  def including(text) = /#{Regexp.escape(text)}/
  def stored(classroom = @classroom) = Orm::Classroom.where(id: classroom.id).pick(:name, :max_students)
  def settings(suffix: "A", max_students: 95) = { classroom_settings: { suffix:, max_students: } }

  test "la carte d'une classe active offre « Modifier la classe » en tête de son menu ⋮ ; l'archivée, non" do
    archived = create_classroom(school: @school, level: @levels["6eme"], name: "6ème 9", status: "archived")
    sign_in_as @member

    get school_path(@school.public_id)

    assert_select "#classroom-menu-#{@classroom.public_id} [role=menuitem]", count: 2 do |items|
      assert_equal [ "Modifier la classe", "Archiver la classe" ], items.map { it.text.squish }
    end
    assert_select "a[href='#{edit_path}'][data-turbo-frame=modal]"
    assert_select "a[href='#{edit_path(archived)}']", count: 0
  end

  test "la modale montre le préfixe fixe, le suffixe et le plafond préremplis, l'effectif dans l'aide" do
    2.times { create_student(classroom: @tle_d) }
    sign_in_as @member

    get edit_path(@tle_d)

    assert_response :success
    assert_select "turbo-frame#modal dialog#classroom-settings-modal", text: including("Modifier la classe Tle D 3")
    assert_select "#classroom-settings-prefix", text: "Tle D"
    assert_select "input#classroom_settings_suffix[value='3'][maxlength='9']"
    assert_select "input#classroom_settings_max_students[value='80'][min='2'][max='150']"
    assert_select "#classroom_settings_max_students_hint", text: "La classe compte 2 élèves. Entre 2 et 150."
  end

  test "un nom libre d'avant l'ADR-0098 : suffixe vide, l'aide dit qu'il sera remplacé" do
    free = create_classroom(school: @school, level: @levels["6eme"], name: "Bilingue")
    sign_in_as @member

    get edit_path(free)

    assert_select("input#classroom_settings_suffix") { |inputs| assert_predicate inputs.first["value"], :blank? }
    assert_select "#classroom_settings_suffix_hint", text: including("Le nom actuel, « Bilingue », sera remplacé.")
  end

  test "renomme « 6ème 3 » en « 6ème A » et relève le plafond : toast, modale fermée, fiche rafraîchie, trace" do
    sign_in_as @member

    patch update_path, params: settings, as: :turbo_stream

    assert_response :success
    assert_equal [ "6ème A", 95 ], stored
    assert_select "turbo-stream[action=append][target=toasts]", text: including("Classe 6ème A enregistrée.")
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]"
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", @school.id ], [ event.action, event.subject_id ]
    assert_equal({ "change" => "classroom_updated", "classroom_public_id" => @classroom.public_id, "name" => "6ème A",
                   "previous_name" => "6ème 3", "max_students" => 95, "previous_max_students" => 80 }, event.metadata)
  end

  test "sans JavaScript : retour à la fiche avec le message" do
    sign_in_as @member

    patch update_path, params: settings

    assert_redirected_to school_path(@school.public_id)
    assert_equal 303, response.status
    assert_equal "Classe 6ème A enregistrée.", flash[:notice]
  end

  test "erreurs sous leur champ, modale re-rendue en 422 avec la saisie, rien d'écrit" do
    create_classroom(school: @school, level: @levels["6eme"], name: "6ème A", status: "archived")
    42.times { create_student(classroom: @classroom) }
    sign_in_as @member

    patch update_path, params: settings(suffix: " ", max_students: 151)
    assert_response :unprocessable_entity
    assert_select "#classroom_settings_suffix_error", text: error(:suffix, :blank)
    assert_select "#classroom_settings_max_students_error", text: error(:max_students, :in)

    patch update_path, params: settings(suffix: "A", max_students: 95)
    assert_response :unprocessable_entity
    assert_select "#classroom_settings_suffix_error", text: error(:suffix, :taken)

    patch update_path, params: settings(suffix: "B", max_students: 40)
    assert_response :unprocessable_entity
    assert_select "#classroom_settings_max_students_error", text: "La classe compte déjà 42 élèves : le plafond ne peut pas être plus bas."
    assert_select "input#classroom_settings_suffix[value='B']"

    patch update_path(@tle_d), params: settings(suffix: "Excellence")
    assert_response :unprocessable_entity
    assert_select "#classroom_settings_suffix_error", text: "Le nom complet tient en 15 caractères au plus (Tle D + 9)."

    assert_equal [ [ "6ème 3", 80 ], [ "Tle D 3", 80 ] ], [ stored, stored(@tle_d) ]
    assert_equal 0, Orm::AuditEvent.count
  end

  test "une classe archivée entre l'ouverture et l'envoi : toast neutre, modale fermée, page rafraîchie" do
    sign_in_as @member
    get edit_path
    @classroom.update!(status: "archived", archived_at: Time.current)

    patch update_path, params: settings, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including("Cette classe est archivée : restaurez-la pour la modifier.")
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]"
    assert_equal "6ème 3", stored.first
    get edit_path
    assert_response :not_found
  end

  test "enregistrer sans rien changer : toast, aucune trace" do
    sign_in_as @member

    patch update_path, params: settings(suffix: "3", max_students: 80), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: including("Classe 6ème 3 enregistrée.")
    assert_equal 0, Orm::AuditEvent.count
  end

  test "l'équipe corrige aussi la classe d'un établissement désactivé" do
    @school.update!(status: "inactive")
    sign_in_as @member

    patch update_path, params: settings, as: :turbo_stream

    assert_response :success
    assert_equal [ "6ème A", 95 ], stored
  end

  test "établissement inconnu, classe d'un autre établissement ou d'une année passée : 404, rien d'écrit" do
    elsewhere = create_classroom(school: create_school, level: @levels["6eme"], name: "6ème 3")
    past = create_classroom(school: @school, level: @levels["6eme"], name: "6ème 3", school_year: "2020-2021")
    sign_in_as @member

    get edit_school_classroom_setting_path("inconnu", @classroom.public_id)
    assert_response :not_found
    [ elsewhere, past ].each do |classroom|
      get edit_path(classroom)
      assert_response :not_found
      patch update_path(classroom), params: settings, as: :turbo_stream
      assert_response :not_found
    end

    assert_equal [ [ "6ème 3", 80 ], [ "6ème 3", 80 ] ], [ stored(elsewhere), stored(past) ]
  end

  test "droits : élève, enseignant de la classe, direction reçoivent 403, et rien n'est écrit" do
    teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    [ create_student(classroom: @classroom), teacher, create_school_admin(school: @school) ].each do |outsider|
      sign_in_as outsider

      get edit_path
      assert_response :forbidden
      patch update_path, params: settings, as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ "6ème 3", 80 ], stored
    assert_equal 0, Orm::AuditEvent.count
  end
end

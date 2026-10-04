require "test_helper"

# ADR-0065, UDR-0052 (DS-06, DS-10, DS-11): « Enseignants », read by the direction on its own school only.
# ADR-0071 §4.3, UDR-0056 §3.3 (GD-14 to GD-18): the direction of an active school withdraws one of its teachers.
class SchoolAdmin::TeachersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.teachers.index.#{key}", **)

  test "DS-06, DS-10 : la direction voit ses enseignants, leur matière et leurs classes, rien d'un autre établissement" do
    maths = create_material(name: "Mathématiques", category: "science")
    second = create_classroom(school: @school, level: create_level(name: "2nde", position: 5), name: "2nde C 1")
    final = create_classroom(school: @school, level: create_level(name: "Tle", position: 7), name: "Tle D 2")
    awa = create_teacher(school: @school, first_name: "Awa", last_name: "Koné", material: maths, classrooms: [ final, second ])
    idle = create_teacher(school: @school, first_name: "Yao", last_name: "Brou")
    create_teacher(school: @school, first_name: "Anne", last_name: "Anonyme").update!(anonymized_at: Time.current)
    create_join_request(school: @school, teacher: create_teacher(school: nil, first_name: "Paul", last_name: "Attente"))
    other_school = create_school
    create_teacher(school: other_school, first_name: "Jean", last_name: "Ailleurs",
                   classrooms: [ create_classroom(school: other_school, name: "1ère A 3") ])

    sign_in_as @admin
    get school_admin_teachers_path

    assert_response :success
    assert_select "h1", text: t("title")
    assert_select "main", text: /#{Regexp.escape(t('subtitle', school: 'Lycée Moderne de Bouaké', count: 2))}/
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.teachers")
    assert_select "#school_teachers table" do
      assert_select "caption.sr-only", text: t("caption", school: "Lycée Moderne de Bouaké")
      assert_select "th[scope=col]", 4
      assert_select "tbody tr", 2
      assert_select "tr#teacher_#{idle.public_id} th[scope=row]", text: "Yao Brou"
      assert_select "tr#teacher_#{idle.public_id} td", text: t("no_classroom")
      assert_select "tr#teacher_#{awa.public_id} th[scope=row]", text: "Awa Koné"
      assert_select "tr#teacher_#{awa.public_id} td", text: "Mathématiques"
      assert_select "tr#teacher_#{awa.public_id} td", text: "2nde C 1, Tle D 2"
    end
    [ "Anonyme", "Attente", "Ailleurs", "1ère A 3" ].each { assert_not_includes response.body, it }
    Orm::User.where(role: "teacher").pluck(:contact).compact.each { assert_not_includes response.body, it }
  end

  test "un enseignant sans matière connue : « — » lu « non calculé »" do
    teacher = create_user(role: "teacher", first_name: "Awa", last_name: "Koné")
    Orm::TeacherSchool.create!(teacher:, school: @school, primary: true)

    sign_in_as @admin
    get school_admin_teachers_path

    assert_select "tr#teacher_#{teacher.public_id} td span[aria-hidden=true]", text: "—"
    assert_select "tr#teacher_#{teacher.public_id} td span.sr-only", text: t("missing")
  end

  test "un établissement sans enseignant : l'état vide, sans tableau" do
    create_teacher(school: create_school)

    sign_in_as @admin
    get school_admin_teachers_path

    assert_response :success
    assert_select "table", 0
    assert_select "main", text: /#{t('empty.title')}/
    assert_select "main", text: /#{t('empty.description')}/
  end

  test "DS-10 : la direction d'un autre établissement ne voit pas ces enseignants" do
    create_teacher(school: @school, first_name: "Zadi", last_name: "Gnagbo")

    sign_in_as create_school_admin(school: create_school)
    get school_admin_teachers_path

    assert_response :success
    assert_not_includes response.body, "Gnagbo"
  end

  test "DS-11 : élève, enseignant et équipe reçoivent 403 ; le visiteur va à « Se connecter »" do
    get school_admin_teachers_path
    assert_redirected_to new_session_path

    [ create_student, create_teacher(school: @school), create_team_member ].each do |user|
      sign_in_as user
      get school_admin_teachers_path
      assert_response :forbidden, user.role
      sign_out
    end
  end

  # GD-14 — a teacher of A declared in « 6ème 1 » and « 6ème 2 », author of 3 active assignments and 1 archived one,
  # with students' sessions.
  def seed_teacher_of_a
    @first = create_classroom(school: @school, name: "6ème 1")
    @second = create_classroom(school: @school, name: "6ème 2")
    @teacher = create_teacher(school: @school, first_name: "Awa", last_name: "Koné", classrooms: [ @first, @second ])
    @active = [ @first, @first, @second ].map { create_assignment(classroom: it, by: @teacher) }
    @archived = create_assignment(classroom: @second, by: @teacher, status: "archived")
    student = create_student(classroom: @first)
    create_exercise_session(student:, status: "completed")
    @teacher
  end

  # Characterization (chantier ecrans-direction-lents, lot C): each icon of a row draws its heroicon, with the root attributes,
  # size and class of the vendored file, whether written inline or taken from a <symbol> of the page by <use>.
  # Lot 3, lever 3b: the confirmation left the row (loaded on demand in the « modal » frame), and its two icons with it;
  # they are checked on the confirmation itself, in the next test.
  test "chaque icône d'une ligne dessine son heroicon : matière, ⋮ et « Retirer »" do
    teacher = create_teacher(school: @school, first_name: "Awa", last_name: "Koné", material: create_material(category: "literature"),
                             classrooms: [ create_classroom(school: @school, name: "6ème 1") ])

    sign_in_as @admin
    get school_admin_teachers_path

    svgs = css_select("tr#teacher_#{teacher.public_id} svg")
    expected = [ [ "20/solid", "book-open", "shrink-0 size-4" ], [ "24/outline", "ellipsis-vertical", "shrink-0 size-5" ],
                 [ "24/outline", "user-minus", "shrink-0 size-5 opacity-70" ] ]
    assert_equal expected.map { |set, name, css| heroicon(set, name).merge(class: css) }, svgs.map { drawn_icon(it) }
    assert(svgs.all? { it["aria-hidden"] == "true" && it["focusable"] == "false" && it["role"].nil? })
  end

  test "la confirmation dessine les heroicons de la modale d'avant : croix et bouton « Retirer »" do
    teacher = create_teacher(school: @school, first_name: "Awa", last_name: "Koné")

    sign_in_as @admin
    get school_admin_teacher_removal_path(teacher.public_id), headers: { "Turbo-Frame" => "modal" }

    svgs = css_select("dialog#remove-teacher-#{teacher.public_id} svg")
    expected = [ [ "24/outline", "x-mark", "shrink-0 size-5" ], [ "24/outline", "user-minus", "shrink-0 size-5" ] ]
    assert_equal expected.map { |set, name, css| heroicon(set, name).merge(class: css) }, svgs.map { drawn_icon(it) }
  end

  def heroicon(set, name)
    svg = Nokogiri::HTML5.fragment(Rails.root.join("vendor/heroicons/#{set}/#{name}.svg").read).at_css("svg")
    { root: svg.to_h.slice("viewBox", "fill", "stroke", "stroke-width"), paths: svg.css("path").map(&:to_h) }
  end

  def drawn_icon(svg)
    use = svg.at_css("use")
    source = use ? document_root_element.at_css("symbol#{use['href']}") : svg
    { root: svg.to_h.slice("viewBox", "fill", "stroke", "stroke-width"), paths: source.css("path").map(&:to_h), class: svg["class"] }
  end

  def td(key, **) = I18n.t("school_admin.teachers.destroy.#{key}", **)
  def refusal(code) = I18n.t("school_admin.shared.errors.#{code}")

  # GD-14, rewritten by lever 3b of ecrans-direction-lents (UDR-0056, amendment of 2026-10-04): the ⋮ entry is a link that
  # loads the confirmation in the shared « modal » frame; the index no longer carries one <dialog> per row.
  test "GD-14 : établissement actif, chaque ligne a son menu ⋮ « Retirer de l'établissement », lien vers sa confirmation" do
    teacher = seed_teacher_of_a
    colleague = create_teacher(school: @school, first_name: "Yao", last_name: "Brou")

    sign_in_as @admin
    get school_admin_teachers_path

    assert_select "a[href='#{school_admin_departed_teachers_path}']", text: t("departed")
    [ teacher, colleague ].each do |row|
      id = row.public_id
      assert_select "tr#teacher_#{id} td.text-right" do
        assert_select "button[aria-haspopup=menu][aria-controls=teacher-actions-#{id}][aria-label=?]", t("actions", name: "#{row.first_name} #{row.last_name}")
        assert_select "#teacher-actions-#{id}[role=menu] a[role=menuitem][data-turbo-frame=modal]", 1
        assert_select "#teacher-actions-#{id}[role=menu] a[role=menuitem][data-turbo-frame=modal][href='#{school_admin_teacher_removal_path(id)}']",
                      text: t("remove")
      end
    end
    assert_select "#school_teachers dialog, #school_teachers form", 0
    assert_not_includes response.body, "remove-teacher-"
    assert_not_includes response.body, tr("title", name: "Awa Koné")
  end

  def tr(key, **) = I18n.t("school_admin.teachers.removal.#{key}", **)
  def removal(teacher_or_id, frame: true)
    id = teacher_or_id.respond_to?(:public_id) ? teacher_or_id.public_id : teacher_or_id
    get school_admin_teacher_removal_path(id), headers: (frame ? { "Turbo-Frame" => "modal" } : {})
  end

  def assert_confirmation(teacher, name:, first_name:)
    id = teacher.public_id
    assert_select "turbo-frame#modal dialog#remove-teacher-#{id}[open][aria-labelledby=remove-teacher-#{id}-title]" do
      assert_select "h2#remove-teacher-#{id}-title", text: tr("title", name:)
      assert_select "p", text: tr("body", first_name:)
      assert_select "button[type=button][data-action='modal#close']", text: tr("cancel")
      assert_select "button[type=submit][form=remove-teacher-#{id}-form]", text: tr("confirm")
      assert_select "form#remove-teacher-#{id}-form[method=post][action='#{school_admin_teacher_path(id)}'] input[name=_method][value=delete]"
    end
  end

  test "GD-14 : dans le frame « modal », la confirmation : même titre, même texte, mêmes boutons, même DELETE" do
    teacher = seed_teacher_of_a

    sign_in_as @admin
    removal(teacher)

    assert_response :success
    assert_confirmation(teacher, name: "Awa Koné", first_name: "Awa")
    assert_select "turbo-frame#modal", 1
    assert_select "nav, main, h1, #back-to-teachers", 0
  end

  test "sans en-tête Turbo-Frame, la même adresse rend une page complète : shell, retour à la liste, modale ouverte" do
    teacher = seed_teacher_of_a

    sign_in_as @admin
    removal(teacher, frame: false)

    assert_response :success
    assert_select "title", text: /\A#{Regexp.escape(tr('title', name: 'Awa Koné'))}/
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.teachers")
    assert_select "main a#back-to-teachers[href='#{school_admin_teachers_path}']", text: tr("back")
    assert_select "main" do
      assert_confirmation(teacher, name: "Awa Koné", first_name: "Awa")
    end
  end

  test "de bout en bout : la confirmation chargée, son formulaire retire l'enseignant ; toast, puis l'état vide" do
    teacher = seed_teacher_of_a

    sign_in_as @admin
    removal(teacher)
    form = css_select("form#remove-teacher-#{teacher.public_id}-form").sole
    delete form["action"], as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=remove][target=teacher_#{teacher.public_id}]"
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(td('detached', name: 'Awa Koné', count: 3))}/
    assert_select "turbo-stream[action=replace][target=school_teachers] template", text: /#{t('empty.title')}/
    assert_not Orm::TeacherSchool.exists?(teacher_id: teacher.id)
  end

  test "confirmation : élève, enseignant et équipe reçoivent 403, dans le frame comme sans ; le visiteur va à « Se connecter »" do
    teacher = create_teacher(school: @school, first_name: "Zadi", last_name: "Gnagbo")

    removal(teacher)
    assert_redirected_to new_session_path

    [ create_student, create_teacher(school: @school), create_team_member ].each do |user|
      sign_in_as user
      [ true, false ].each do |frame|
        removal(teacher, frame:)
        assert_response :forbidden, user.role
        assert_not_includes response.body, "Gnagbo"
      end
      sign_out
    end
  end

  test "confirmation : la direction d'un autre établissement reçoit 404, comme le retrait (GD-16), sans rien lire de l'enseignant" do
    teacher = create_teacher(school: @school, first_name: "Zadi", last_name: "Gnagbo")

    sign_in_as create_school_admin(school: create_school)
    removal(teacher)

    assert_response :not_found
    assert_not_includes response.body, "Gnagbo"
    assert Orm::TeacherSchool.exists?(teacher_id: teacher.id, school_id: @school.id)
  end

  test "confirmation : inconnu, déjà retiré, en attente, anonymisé ou autre rôle : 404" do
    gone = create_teacher(school: @school, first_name: "Zadi", last_name: "Gnagbo")
    anonymized = create_teacher(school: @school).tap { it.update!(anonymized_at: Time.current) }
    pending = create_teacher(school: nil)
    create_join_request(school: @school, teacher: pending)
    student = create_student(classroom: create_classroom(school: @school))

    sign_in_as @admin
    delete school_admin_teacher_path(gone.public_id), as: :turbo_stream
    assert_response :success

    [ "abcdefghijkmno", gone, anonymized, pending, student, @admin ].each do |target|
      removal(target)
      assert_response :not_found, target.inspect
      assert_not_includes response.body, "Gnagbo"
    end
  end

  test "confirmation : établissement inactif, 403 comme le retrait (GD-17), avant toute lecture : un inconnu aussi" do
    inactive = create_school(status: "inactive")
    teacher = create_teacher(school: inactive, first_name: "Zadi", last_name: "Gnagbo")

    sign_in_as create_school_admin(school: inactive)
    [ teacher.public_id, "abcdefghijkmno" ].each do |id|
      [ true, false ].each do |frame|
        removal(id, frame:)
        assert_response :forbidden
        assert_not_includes response.body, "Gnagbo"
      end
    end
  end

  test "GD-14 : le retrait confirmé ; ligne retirée, toast ; classes, élèves, sessions et compte intacts ; audité" do
    teacher = seed_teacher_of_a
    create_teacher(school: @school, last_name: "Collègue")
    teacher_session = open_session.tap { it.post session_path, params: { session: { contact: teacher.contact, pin: "2468" } } }
    counts = -> { [ Orm::Classroom.count, Orm::ClassroomStudent.count, Orm::ExerciseSession.count, Orm::User.count ] }
    before = counts.call

    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=remove][target=teacher_#{teacher.public_id}]"
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(td('detached', name: 'Awa Koné', count: 3))}/
    assert_select "turbo-stream[action=replace][target=school_teachers]", 0
    assert_not Orm::TeacherSchool.exists?(teacher_id: teacher.id)
    assert_not Orm::TeacherClassroom.exists?(teacher_id: teacher.id)
    @active.each(&:reload).each do
      assert_equal [ "archived", @admin.id ], [ it.status, it.archived_by_id ]
      assert_not_nil it.archived_at
    end
    assert_equal [ "archived", teacher.id ], [ @archived.reload.status, @archived.archived_by_id ], "l'archivé le reste"
    assert_equal before, counts.call
    assert_nil teacher.reload.anonymized_at
    departure = Orm::TeacherSchoolDeparture.sole
    assert_equal [ teacher.id, @school.id, @admin.id, nil ], [ departure.teacher_id, departure.school_id, departure.detached_by_id, departure.reinstated_at ]
    event = Orm::AuditEvent.find_by!(action: "teacher.detached")
    assert_equal [ @admin.id, "User", teacher.id ], [ event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "school_id" => @school.id, "classrooms_count" => 2, "assignments_archived" => 3 }, event.metadata)

    teacher_session.get teacher_home_path
    teacher_session.assert_redirected_to pending_account_path
  end

  test "GD-15 : le devoir actif de l'enseignant dans une classe de B reste actif" do
    teacher = seed_teacher_of_a
    elsewhere = create_assignment(classroom: create_classroom(school: create_school), by: teacher)

    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream

    assert_response :success
    assert_equal "active", elsewhere.reload.status
  end

  test "le dernier enseignant retiré : l'état vide remplace le tableau ; repli HTML : 303 vers la liste, avec la notice" do
    teacher = create_teacher(school: @school, first_name: "Awa", last_name: "Koné")
    other = create_teacher(school: @school, first_name: "Yao", last_name: "Brou")

    sign_in_as @admin
    delete school_admin_teacher_path(other.public_id)
    assert_redirected_to school_admin_teachers_path
    assert_response :see_other
    assert_equal td("detached", name: "Yao Brou", count: 0), flash[:notice]

    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_select "turbo-stream[action=replace][target=school_teachers] template", text: /#{t('empty.title')}/
  end

  test "GD-16 : un enseignant de B : 404, il reste rattaché à B" do
    teacher = create_teacher(school: create_school, last_name: "Ailleurs")

    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{refusal(:not_found)}/

    delete school_admin_teacher_path(teacher.public_id)
    assert_response :not_found
    assert Orm::TeacherSchool.exists?(teacher_id: teacher.id)
    assert_not Orm::TeacherSchoolDeparture.exists?
  end

  test "GD-17 : établissement inactif : aucun menu, retrait forgé 403 ; l'équipe reçoit 403" do
    inactive = create_school(status: "inactive")
    teacher = create_teacher(school: inactive, first_name: "Zadi", last_name: "Gnagbo")

    sign_in_as create_school_admin(school: inactive)
    get school_admin_teachers_path
    assert_response :success
    assert_select "tr#teacher_#{teacher.public_id}"
    assert_select "#school_teachers [role=menu], #school_teachers dialog, #school_teachers form", 0
    assert_not_includes response.body, t("remove")
    assert_not_includes response.body, school_admin_teacher_removal_path(teacher.public_id)

    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{refusal(:forbidden)}/
    sign_out

    sign_in_as create_team_member
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :forbidden
    assert Orm::TeacherSchool.exists?(teacher_id: teacher.id, school_id: inactive.id)
  end

  test "GD-18 : un enseignant en attente de validation pour A : 404" do
    pending = create_teacher(school: nil, last_name: "Attente")
    create_join_request(school: @school, teacher: pending)

    sign_in_as @admin
    delete school_admin_teacher_path(pending.public_id), as: :turbo_stream

    assert_response :not_found
    assert_not Orm::TeacherSchoolDeparture.exists?
  end

  test "déjà retiré (deux onglets) : 404, toast « Introuvable. »" do
    teacher = create_teacher(school: @school)

    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :success
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream

    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{refusal(:not_found)}/
  end
end

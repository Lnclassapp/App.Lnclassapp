require "test_helper"

# ADR-0088, UDR-0083, PRD §4 : depuis la fiche d'un établissement, l'équipe archive une classe (peuplée) depuis son menu ⋮,
# la restaure, et lit les classes archivées (visibles 7 jours, puis derrière « Afficher les archives »).
class Teams::ClassroomArchivalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @levels = seed_referential[:levels]
    @school = create_school(name: "Lycée Classique d'Abidjan", school_type: "public", cycle: "both")
    @classroom = create_classroom(school: @school, level: @levels["6eme"], name: "6ème 1")
    @other = create_classroom(school: @school, level: @levels["6eme"], name: "6ème 2")
  end

  def tc(key, **) = I18n.t("teams.classroom_archivals.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def archive_path(classroom = @classroom, school = @school) = archive_school_classroom_archival_path(school.public_id, classroom.public_id)
  def restore_path(classroom = @classroom, school = @school) = restore_school_classroom_archival_path(school.public_id, classroom.public_id)

  def populate(classroom)
    3.times { create_student(classroom:) }
    teacher = create_teacher(school: @school, classrooms: [ classroom ])
    create_assignment(classroom:, by: teacher)
    teacher
  end

  def archive_at(classroom, ago: 0.days)
    classroom.update_columns(status: "archived", archived_at: Time.current - ago)
  end

  test "droits : un élève, un enseignant ou une direction reçoivent 403 sur archiver et restaurer, et rien n'est écrit" do
    archive_at(@other)
    [ create_student, create_teacher(school: @school), create_school_admin(school: @school) ].each do |outsider|
      sign_in_as outsider

      patch archive_path, as: :turbo_stream
      assert_response :forbidden
      patch restore_path(@other), as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ "active", "archived" ], Orm::Classroom.order(:name).pluck(:status)
    assert_equal 0, Orm::AuditEvent.count
  end

  test "un établissement inconnu donne 404, une classe d'un autre établissement est introuvable, rien n'est écrit" do
    elsewhere = create_classroom(school: create_school, level: @levels["6eme"], name: "6ème 9")
    sign_in_as @member

    patch archive_school_classroom_archival_path("inconnu", @classroom.public_id), as: :turbo_stream
    assert_response :not_found
    patch archive_path(elsewhere), as: :turbo_stream
    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.not_found"))
    patch restore_path(elsewhere), as: :turbo_stream
    assert_response :not_found

    assert_equal "active", elsewhere.reload.status
    assert_equal 0, Orm::AuditEvent.count
  end

  test "archiver une classe peuplée : archivée avec sa date, adhésions, enseignant et assignations intacts, tracé, toast avec « Annuler »" do
    teacher = populate(@classroom)
    sign_in_as @member

    patch archive_path, as: :turbo_stream

    assert_response :success
    assert_equal [ "archived", true ], [ @classroom.reload.status, @classroom.archived_at.present? ]
    assert_equal [ 3, 1, 1 ], [ Orm::ClassroomStudent.where(classroom: @classroom, left_at: nil).count,
                                Orm::TeacherClassroom.where(classroom: @classroom, teacher:).count,
                                Orm::ClassroomAssignment.where(classroom: @classroom, status: "active").count ]
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("archive.done", name: "6ème 1"))
    assert_select "turbo-stream[action=append][target=toasts] form[action=?]", restore_path
    assert_select "turbo-stream[action=replace][target=level_6eme][method=morph]"
    assert_select "turbo-stream[action=replace] template li#classroom_#{@classroom.public_id}", text: including("Archivée")
    assert_select "turbo-stream[action=refresh]:not([request-id])"
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", @member.id, "School", @school.id ], [ event.action, event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "change" => "classroom_archived", "classroom_public_id" => @classroom.public_id, "name" => "6ème 1" }, event.metadata)
  end

  test "l'équipe archive aussi dans un établissement inactif" do
    @school.update!(status: "inactive")
    sign_in_as @member

    patch archive_path, as: :turbo_stream

    assert_response :success
    assert_equal "archived", @classroom.reload.status
  end

  test "double archivage : 422, message « déjà archivée », rien ne change, carte rafraîchie" do
    archive_at(@classroom, ago: 2.days)
    archived_at = @classroom.reload.archived_at
    sign_in_as @member

    patch archive_path, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.already_archived"))
    assert_select "turbo-stream[action=replace][target=level_6eme]"
    assert_select "turbo-stream[action=refresh]", false
    assert_equal archived_at, @classroom.reload.archived_at
    assert_equal 0, Orm::AuditEvent.count
  end

  test "restaurer : active, sans date, mêmes élèves ; une classe active ne se restaure pas" do
    teacher = populate(@classroom)
    archive_at(@classroom)
    sign_in_as @member

    patch restore_path, as: :turbo_stream

    assert_response :success
    assert_equal [ "active", nil ], [ @classroom.reload.status, @classroom.archived_at ]
    assert_equal [ 3, 1 ], [ Orm::ClassroomStudent.where(classroom: @classroom, left_at: nil).count,
                             Orm::TeacherClassroom.where(classroom: @classroom, teacher:).count ]
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("restore.done", name: "6ème 1"))
    assert_select "turbo-stream[action=refresh]:not([request-id])"
    assert_equal "classroom_restored", Orm::AuditEvent.sole.metadata["change"]

    patch restore_path, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.not_archived"))
  end

  test "sans JavaScript : redirection vers la fiche avec un message, succès comme refus" do
    sign_in_as @member

    patch archive_path
    assert_redirected_to school_path(@school.public_id)
    assert_equal tc("archive.done", name: "6ème 1"), flash[:notice]
    patch archive_path
    assert_redirected_to school_path(@school.public_id)
    assert_equal tc("errors.already_archived"), flash[:alert]
    patch restore_path
    assert_equal tc("restore.done", name: "6ème 1"), flash[:notice]
  end

  test "la fiche : active d'abord, archivée de 3 jours en fin de niveau avec badge et menu « Restaurer », effectif hors du total" do
    populate(@classroom)
    archive_at(@classroom, ago: 3.days)
    sign_in_as @member

    get school_path(@school.public_id)

    assert_response :success
    assert_select "section#level_6eme li[id^=classroom_]:first-child", text: including("6ème 2")
    assert_select "section#level_6eme li#classroom_#{@classroom.public_id}", text: including("Archivée")
    assert_select "li#classroom_#{@classroom.public_id} a[href=?]", restore_path
    assert_select "li#classroom_#{@classroom.public_id} dd.text-mute", text: "3"
    assert_select "li#classroom_#{@other.public_id} #classroom-menu-#{@other.public_id}"
    assert_select "form#archive-classroom-#{@other.public_id}-form[action=?]", archive_path(@other)
    assert_select "section#level_6eme h3 + div span", text: "1 classe"
    assert_select "#school_classrooms_title", text: including("1")
    assert_select "#level-menu-6eme"
    assert_select "form#archive-level-6eme-form[action=?]", school_level_archivals_path(@school.public_id)
    assert_select "a[href=?]", school_path(@school.public_id, archives: 1), false
  end

  test "ADR-0088 : la carte d'une classe archivée n'est plus un lien, et son niveau dit combien d'archivées il montre" do
    archive_at(@classroom, ago: 2.days)
    sign_in_as @member

    get school_path(@school.public_id)

    assert_select "li#classroom_#{@classroom.public_id}", text: including("Archivée")
    assert_select "li#classroom_#{@classroom.public_id} a[href=?]", classroom_path(@classroom.public_id), 0
    assert_select "section#level_#{@classroom.level.slug}", text: including("1 archivée")
  end

  test "la fiche : archivée de 8 jours masquée derrière « Afficher les archives (1) » de son niveau, visible avec ?archives=1" do
    archive_at(@classroom, ago: 8.days)
    sign_in_as @member

    get school_path(@school.public_id)

    assert_select "li#classroom_#{@classroom.public_id}", false
    level = "level_#{@classroom.level.slug}"
    assert_select "section##{level} a[href=?][aria-expanded=false]", school_path(@school.public_id, archives: 1, anchor: level),
                  text: including("Afficher les archives (1)")

    get school_path(@school.public_id, archives: 1)

    assert_select "li#classroom_#{@classroom.public_id}", text: including("Archivée")
    assert_select "section##{level} a[href=?][aria-expanded=true]", school_path(@school.public_id, anchor: level),
                  text: including("Masquer les archives")
  end

  test "la fiche : un niveau sans classe active visible affiche « Aucune classe » et n'a pas de menu" do
    archive_at(@classroom, ago: 9.days)
    archive_at(@other, ago: 9.days)
    sign_in_as @member

    get school_path(@school.public_id)

    assert_select "section#level_6eme", text: including(I18n.t("teams.schools.classroom_group.empty"))
    assert_select "#level-menu-6eme", false
    assert_select "a[aria-expanded=false]", text: including("(2)")
  end

  test "la fiche : sans archive, ni bouton ni état vide" do
    sign_in_as @member

    get school_path(@school.public_id)

    assert_select "a[aria-expanded]", false
    assert_select "section#level_6eme", text: /#{Regexp.escape(I18n.t("teams.schools.classroom_group.empty"))}/, count: 0
  end
end

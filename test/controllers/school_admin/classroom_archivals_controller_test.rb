require "test_helper"

# ADR-0088, UDR-0083 (PRD §4) : la direction archive et restaure une classe de son seul établissement actif, depuis la page
# de son niveau ; rien n'est supprimé, tout est tracé. L'établissement vient du compte, jamais d'un paramètre : la classe
# d'un autre établissement est introuvable, un établissement inactif est refusé.
class SchoolAdmin::ClassroomArchivalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Collège Moderne de Bouaké")
    @admin = create_school_admin(school: @school)
    @level = create_level(name: "3ème", position: 4)
    @teacher = create_teacher(school: @school)
    @classroom = create_classroom(school: @school, level: @level, name: "3ème 1")
    @students = Array.new(3) { create_student(classroom: @classroom) }
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: @classroom)
    @assignments = Array.new(2) { create_assignment(classroom: @classroom, by: @teacher) }
  end

  def archive_path(classroom = @classroom) = archive_school_admin_classroom_archival_path(classroom.public_id)
  def restore_path(classroom = @classroom) = restore_school_admin_classroom_archival_path(classroom.public_id)
  def ta(key, **) = I18n.t("school_admin.classroom_archivals.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def archived!(classroom = @classroom) = classroom.update!(status: "archived", archived_at: 2.days.ago)
  def stored(classroom = @classroom) = Orm::Classroom.where(id: classroom.id).pick(:status, :archived_at)

  def untouched
    [ Orm::ClassroomStudent.where(left_at: nil).count, Orm::TeacherClassroom.count, Orm::ClassroomAssignment.where(status: "active").count ]
  end

  test "archive: the classroom is archived with its date, members and assignments stay, the action is audited" do
    sign_in_as @admin
    before = untouched

    patch archive_path, as: :turbo_stream

    assert_response :success
    status, archived_at = stored
    assert_equal "archived", status
    assert_in_delta Time.current, archived_at, 5
    assert_equal [ 3, 1, 2 ], before
    assert_equal before, untouched
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", @admin.id, "School", @school.id ], [ event.action, event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "change" => "classroom_archived", "classroom_public_id" => @classroom.public_id, "name" => "3ème 1" }, event.metadata)
  end

  test "archive: the answer is a success toast with « Annuler » (restore), then the page is refreshed" do
    sign_in_as @admin

    patch archive_path, as: :turbo_stream

    assert_select "turbo-stream[action=append][target=toasts]", text: including(ta("archive.done", name: "3ème 1"))
    assert_select "turbo-stream[action=append] template form[action=?]", restore_path do
      assert_select "button", text: ta("archive.undo")
    end
    assert_select "turbo-stream[action=refresh]", count: 1
    assert_not_includes response.body, @school.public_id
  end

  test "archive without JavaScript: back to the page with a flash notice" do
    sign_in_as @admin

    patch archive_path, headers: { "HTTP_REFERER" => school_admin_level_url("3eme") }

    assert_redirected_to school_admin_level_url("3eme")
    assert_equal ta("archive.done", name: "3ème 1"), flash[:notice]
    assert_equal "archived", stored.first
  end

  test "archive without JavaScript and without referer: back to the home page" do
    sign_in_as @admin

    patch archive_path

    assert_redirected_to school_admin_classrooms_path
  end

  test "restore: the classroom is active again, same members and assignments, audited" do
    archived!
    sign_in_as @admin
    before = untouched

    patch restore_path, as: :turbo_stream

    assert_response :success
    assert_equal [ "active", nil ], stored
    assert_equal before, untouched
    assert_select "turbo-stream[action=append][target=toasts]", text: including(ta("restore.done", name: "3ème 1"))
    assert_select "turbo-stream[action=append] template form", count: 0
    assert_select "turbo-stream[action=refresh]", count: 1
    assert_equal "classroom_restored", Orm::AuditEvent.sole.metadata["change"]
  end

  test "restore without JavaScript: back to the page with a flash notice" do
    archived!
    sign_in_as @admin

    patch restore_path

    assert_redirected_to school_admin_classrooms_path
    assert_equal ta("restore.done", name: "3ème 1"), flash[:notice]
  end

  test "double archive: a neutral « already archived » toast, nothing changes, the page is refreshed" do
    archived!
    sign_in_as @admin
    before = stored

    patch archive_path, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal before, stored
    assert_select "turbo-stream[action=append][target=toasts]", text: including(ta("errors.already_archived"))
    assert_select "turbo-stream[action=refresh]", count: 1
    assert_equal 0, Orm::AuditEvent.count
  end

  test "double archive without JavaScript: a flash alert" do
    archived!
    sign_in_as @admin

    patch archive_path

    assert_redirected_to school_admin_classrooms_path
    assert_equal ta("errors.already_archived"), flash[:alert]
  end

  test "restoring an active classroom is a conflict, nothing changes" do
    sign_in_as @admin

    patch restore_path, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal "active", stored.first
    assert_select "turbo-stream[action=append][target=toasts]", text: including(ta("errors.not_archived"))
  end

  test "another school's classroom, a past year's one or an unknown one is not found, nothing is written" do
    other = create_classroom(school: create_school(name: "Lycée Classique d'Abidjan"), level: @level, name: "3ème 1")
    past = create_classroom(school: @school, level: @level, name: "3ème 9", school_year: "2020-2021")
    archived_other = create_classroom(school: other.school, level: @level, name: "3ème 2", status: "archived")
    sign_in_as @admin

    [ [ :patch, archive_path(other) ], [ :patch, archive_path(past) ], [ :patch, restore_path(archived_other) ],
      [ :patch, archive_school_admin_classroom_archival_path("unknown") ] ].each do |verb, path|
      send(verb, path, as: :turbo_stream)

      assert_response :not_found, path
      assert_select "turbo-stream[action=append][target=toasts]"
    end
    assert_equal [ "active", "active", "archived" ], [ other, past, archived_other ].map { stored(it).first }
    assert_equal 0, Orm::AuditEvent.count
  end

  test "an establishment id in the params changes nothing: the school is the one of the account" do
    other_school = create_school(name: "Lycée Classique d'Abidjan")
    other = create_classroom(school: other_school, level: @level, name: "3ème 1")
    sign_in_as @admin

    patch archive_path(other), params: { school_public_id: other_school.public_id }, as: :turbo_stream

    assert_response :not_found
    assert_equal "active", stored(other).first
  end

  test "a direction of an inactive school is refused, for archive and for restore, nothing is written" do
    @school.update!(status: "inactive")
    archived = create_classroom(school: @school, level: @level, name: "3ème 2", status: "archived")
    sign_in_as @admin

    patch archive_path, as: :turbo_stream
    assert_response :forbidden
    patch restore_path(archived), as: :turbo_stream
    assert_response :forbidden

    assert_equal [ "active", "archived" ], [ @classroom, archived ].map { stored(it).first }
    assert_equal 0, Orm::AuditEvent.count
  end

  test "a student, a teacher, a team member and a detached school admin receive 403; a visitor is sent to sign in" do
    [ create_student, create_teacher(school: @school), create_team_member, create_user(role: "school_admin") ].each do |outsider|
      sign_in_as outsider

      patch archive_path

      assert_response :forbidden, outsider.role
      sign_out
    end
    patch archive_path

    assert_redirected_to new_session_path
    assert_equal "active", stored.first
  end

  # La page du niveau (UDR-0083 §3) : menu ⋮ de chaque carte et de l'en-tête, archivées récentes visibles, anciennes derrière
  # « Afficher les archives », totaux sans les archivées.
  def level_page(**params)
    get(school_admin_level_path("3eme"), params:)
    assert_response :success
  end

  def sibling(name, **) = create_classroom(school: @school, level: @level, name:, **)
  def card(classroom) = "ul#level_classrooms > li#classroom_#{classroom.public_id}"

  test "page: each active card has a ⋮ menu, a stretched link and a confirmation that counts the impact" do
    sign_in_as @admin

    level_page

    assert_select card(@classroom) do
      assert_select "a[href=?]", school_admin_classroom_path(@classroom.public_id), count: 1
      assert_select "a a", count: 0
      assert_select "button[aria-label=?]", I18n.t("shared.classroom_archive_menu.actions", name: "3ème 1")
      assert_select "dialog#archive-classroom-#{@classroom.public_id}" do
        assert_select "h2", text: I18n.t("shared.classroom_archive_menu.title", name: "3ème 1")
        assert_select "p", text: /3 élèves et 1 enseignant ne la verront plus\. Rien n'est supprimé/
        assert_select "form[action=?]", archive_path
      end
    end
  end

  test "page: the header has a level menu counting the classrooms, students and teachers of the level" do
    sibling("3ème 2")
    sign_in_as @admin

    level_page

    assert_select "button[aria-label=?]", I18n.t("shared.level_archive_menu.actions", name: "3ème")
    assert_select "dialog#archive-level-3eme" do
      assert_select "h2", text: "Archiver les 2 classes de 3ème ?"
      assert_select "p", text: /3 élèves et 1 enseignant ne les verront plus/
      assert_select "form[action=?] input[name=level][value=?]", school_admin_level_archivals_path, "3eme"
    end
  end

  test "page: a classroom archived 3 days ago shows last with its badge and « Restaurer », 8 days ago it is hidden" do
    recent = sibling("3ème 2", status: "archived", archived_at: 3.days.ago)
    old = sibling("3ème 3", status: "archived", archived_at: 8.days.ago)
    create_student(classroom: recent)
    sign_in_as @admin

    level_page

    assert_select "ul#level_classrooms > li" do |cards|
      assert_equal [ @classroom, recent ].map { "classroom_#{it.public_id}" }, cards.map { it["id"] }
    end
    assert_select card(recent) do
      assert_select "span", text: I18n.t("school_admin.levels.classroom_card.archived")
      assert_select "a[href=?][data-turbo-method=patch]", restore_path(recent), text: I18n.t("shared.classroom_archive_menu.restore")
      assert_select "dialog", count: 0
      assert_select "a[href=?]", school_admin_classroom_path(recent.public_id), count: 0
    end
    assert_select card(old), count: 0
    assert_select "a[href=?][aria-expanded=false]", school_admin_level_path("3eme", archives: 1),
                  text: I18n.t("shared.archives_toggle.show", count: 1)
  end

  test "page: « Afficher les archives » (?archives=1) shows the old ones, « Masquer les archives » comes back" do
    old = sibling("3ème 3", status: "archived", archived_at: 8.days.ago)
    sign_in_as @admin

    level_page(archives: 1)

    assert_select card(old)
    assert_select "a[href=?][aria-expanded=true]", school_admin_level_path("3eme"), text: I18n.t("shared.archives_toggle.hide")
  end

  test "page: no archive button when nothing is hidden, and totals leave the archived classrooms out" do
    sibling("3ème 2", status: "archived", archived_at: 1.day.ago).tap { create_student(classroom: it) }
    sign_in_as @admin

    level_page

    assert_select "a[aria-expanded]", count: 0
    assert_select "p", text: "1 classe · 3 élèves"
  end

  test "page: a level whose classrooms are all archived long ago says so, offers the archives, and no level menu" do
    @classroom.update!(status: "archived", archived_at: 9.days.ago)
    sign_in_as @admin

    level_page

    assert_select "ul#level_classrooms > li", count: 0
    assert_select "p", text: I18n.t("school_admin.levels.show.empty")
    assert_select "a[aria-expanded=false]", text: I18n.t("shared.archives_toggle.show", count: 1)
    assert_select "dialog#archive-level-3eme", count: 0
    assert_select "[id^=level-menu]", count: 0
  end

  test "page: an inactive school is read, no menu is offered" do
    @school.update!(status: "inactive")
    sibling("3ème 2", status: "archived", archived_at: 1.day.ago)
    sign_in_as @admin

    level_page

    assert_select "ul#level_classrooms > li", count: 2
    assert_select "dialog", count: 0
    assert_select "[id^=classroom-menu], [id^=level-menu]", count: 0
    assert_select "[data-turbo-method=patch]", count: 0
  end
end

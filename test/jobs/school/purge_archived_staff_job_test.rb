require "test_helper"

# ADR-0077 §4.3, §4.5 (ID-22) : la tâche du jour supprime un compte direction archivé depuis 30 jours et 1 minute —
# anonymisé, numéro effacé, photo, tentatives de connexion, second facteur, codes de récupération et sessions effacés,
# rattachement supprimé, journal « school_staff.deleted » — et garde intact celui archivé depuis 29 jours, restaurable.
class School::PurgeArchivedStaffJobTest < ActiveJob::TestCase
  test "un compte archivé depuis 30 jours et 1 minute est supprimé ; un compte archivé depuis 29 jours est gardé" do
    due = create_school_admin(first_name: "Aya", last_name: "Traoré", archived_at: 30.days.ago - 1.minute)
    kept = create_school_admin(first_name: "Koffi", last_name: "Yao", archived_at: 29.days.ago)
    active = create_school_admin(joined_at: 60.days.ago)
    [ due, kept ].each { leave_traces(it) }
    due_contact = due.contact

    assert_equal 1, School::PurgeArchivedStaffJob.perform_now

    due.reload
    assert_equal [ "Compte", "supprimé" ], [ due.first_name, due.last_name ]
    assert_nil due.contact
    assert_not_nil due.anonymized_at
    assert_equal [ 0, 0, 0, 0, 0 ], traces_of(due, due_contact)
    assert_not due.photo.attached?
    assert_not Orm::SchoolStaff.exists?(user_id: due.id)
    event = Orm::AuditEvent.find_by!(action: "school_staff.deleted")
    assert_equal [ nil, "User", due.id ], [ event.actor_id, event.subject_type, event.subject_id ]

    assert_equal [ "Koffi", "Yao" ], [ kept.reload.first_name, kept.last_name ]
    assert_not_nil kept.contact
    assert_equal [ 1, 1, 1, 1, 2 ], traces_of(kept, kept.contact)
    assert kept.photo.attached?
    assert Orm::SchoolStaff.exists?(user_id: kept.id)
    assert Orm::SchoolStaff.exists?(user_id: active.id)
  end

  # Revue de sécurité, constat 4 : un compte en échec n'arrête pas la purge, et il est signalé sans donnée personnelle.
  class FailingPhotos
    def initialize(failing_id) = @failing_id = failing_id

    def remove(user_id:)
      raise IOError, "stockage indisponible" if user_id == @failing_id

      Repositories::Identity::ProfilePhotoStore.new.remove(user_id:)
    end
  end

  test "un compte en échec est signalé par son id, reste archivé, et les suivants sont supprimés" do
    failing = create_school_admin(first_name: "Aya", archived_at: 32.days.ago)
    other = create_school_admin(first_name: "Koffi", archived_at: 31.days.ago)
    job = School::PurgeArchivedStaffJob.new
    use_case = job.send(:use_case)
    use_case.instance_variable_set(:@photos, FailingPhotos.new(failing.id))

    log = capture_log { job.define_singleton_method(:use_case) { use_case }; assert_equal 1, job.perform_now }

    assert_includes log, "[School::PurgeArchivedStaffJob] 1 account(s) not deleted, user ids: #{failing.id}"
    assert_not_includes log, "Aya"
    assert_equal "Aya", failing.reload.first_name
    assert Orm::SchoolStaff.exists?(user_id: failing.id)
    assert_nil other.reload.contact
  end

  test "le nombre de comptes supprimés est journalisé, zéro compris" do
    create_school_admin(archived_at: 31.days.ago)

    logs = [ capture_log { School::PurgeArchivedStaffJob.perform_now },
             capture_log { School::PurgeArchivedStaffJob.perform_now } ]

    assert_includes logs.first, "[School::PurgeArchivedStaffJob] 1 archived school staff account(s) deleted"
    assert_includes logs.last, "[School::PurgeArchivedStaffJob] 0 archived school staff account(s) deleted"
  end

  private

  # Ce qu'un compte direction laisse derrière lui : session, tentative de connexion (avec son numéro), code de
  # récupération du PIN, second facteur et code de secours, photo.
  def leave_traces(admin)
    create_login_session(user: admin)
    create_login_attempt(user: admin)
    create_login_attempt(contact: admin.contact)
    create_pin_recovery_code(user: admin)
    Orm::TotpCredential.create!(user: admin, secret: ROTP::Base32.random, confirmed_at: Time.current)
    create_backup_code(user: admin)
    attach_photo(admin)
  end

  # Les tentatives se comptent aussi par le numéro, lu avant la suppression : une tentative sans compte le porte seul.
  def traces_of(admin, contact)
    [ Orm::Session, Orm::PinRecoveryCode, Orm::TotpCredential, Orm::BackupCode ].map { it.where(user_id: admin.id).count } +
      [ Orm::LoginAttempt.where(contact:).count ]
  end

  def capture_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end
end

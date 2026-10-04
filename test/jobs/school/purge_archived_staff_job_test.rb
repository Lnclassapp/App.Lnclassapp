require "test_helper"

# ADR-0077 §4.5 (ID-22) : la tâche du jour supprime un compte direction archivé depuis 30 jours et 1 minute — anonymisé,
# numéro effacé, sessions fermées, rattachement supprimé, journal « school_staff.deleted » — et garde celui archivé depuis
# 29 jours, restaurable.
class School::PurgeArchivedStaffJobTest < ActiveJob::TestCase
  test "un compte archivé depuis 30 jours et 1 minute est supprimé ; un compte archivé depuis 29 jours est gardé" do
    due = create_school_admin(first_name: "Aya", last_name: "Traoré", archived_at: 30.days.ago - 1.minute)
    kept = create_school_admin(first_name: "Koffi", last_name: "Yao", archived_at: 29.days.ago)
    active = create_school_admin(joined_at: 60.days.ago)
    create_login_session(user: due)
    create_login_session(user: kept)

    assert_equal 1, School::PurgeArchivedStaffJob.perform_now

    due.reload
    assert_equal [ "Compte", "supprimé" ], [ due.first_name, due.last_name ]
    assert_nil due.contact
    assert_not_nil due.anonymized_at
    assert_equal 0, Orm::Session.where(user: due).count
    assert_not Orm::SchoolStaff.exists?(user_id: due.id)
    event = Orm::AuditEvent.find_by!(action: "school_staff.deleted")
    assert_equal [ nil, "User", due.id ], [ event.actor_id, event.subject_type, event.subject_id ]

    assert_equal [ "Koffi", "Yao" ], [ kept.reload.first_name, kept.last_name ]
    assert_not_nil kept.contact
    assert_equal 1, Orm::Session.where(user: kept).count
    assert Orm::SchoolStaff.exists?(user_id: kept.id)
    assert Orm::SchoolStaff.exists?(user_id: active.id)
  end

  test "le nombre de comptes supprimés est journalisé, zéro compris" do
    create_school_admin(archived_at: 31.days.ago)

    logs = [ capture_log { School::PurgeArchivedStaffJob.perform_now },
             capture_log { School::PurgeArchivedStaffJob.perform_now } ]

    assert_includes logs.first, "[School::PurgeArchivedStaffJob] 1 archived school staff account(s) deleted"
    assert_includes logs.last, "[School::PurgeArchivedStaffJob] 0 archived school staff account(s) deleted"
  end

  private

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

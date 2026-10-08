# Accounts of every role and the identity technical rows (ADR-0031, ADR-0032, ADR-0037,
# ADR-0038, ADR-0050). Secrets are stored as the application stores them: PIN by bcrypt,
# codes and tokens by HMAC-SHA256 under the "lnclass-secrets" key, TOTP secret encrypted.
module Factories
  module Identity
    ActiveSupport::TestCase.include(self)

    CONTACT_PREFIXES = { "student" => "01", "teacher" => "05", "school_admin" => "07", "team" => "07" }.freeze

    def create_user(role:, contact: nil, pin: "2468", last_name: "Koné", first_name: "Awa", gender: "female",
                    team_role: (role == "team" ? "admin" : nil), **attributes)
      contact ||= format("%s%08d", CONTACT_PREFIXES.fetch(role), factory_sequence)
      Orm::User.create!(role:, contact:, pin:, last_name:, first_name:, gender:, team_role:, **attributes)
    end

    # ADR-0085 §4.4: joined_via, the arrival channel, has no default in the database.
    def create_student(classroom: nil, joined_via: "standard", joined_at: Time.current, **attributes)
      create_user(role: "student", **attributes).tap do |student|
        Orm::ClassroomStudent.create!(classroom:, student:, primary: true, joined_at:, joined_via:) if classroom
      end
    end

    # UDR-0013, amendement du 2026-10-01 : un élève ne lit que les cours de son niveau. Élève d'une classe de l'année du
    # niveau (et de la série) du cours donné, un Orm::Course.
    def create_student_for(course, **attributes)
      create_student(classroom: create_classroom(level: course.level, series: course.series), **attributes)
    end

    # ADR-0082 §4.2: joined_via, the arrival channel, has no default in the database.
    def create_teacher(school: create_school, material: create_material, onboarded: true, classrooms: [], joined_via: "standard",
                       **attributes)
      create_user(role: "teacher", **attributes).tap do |teacher|
        Orm::TeacherProfile.create!(user: teacher, material:, joined_via:, onboarding_completed_at: (Time.current if onboarded))
        # school: nil — a teacher without a primary school: a pending account (ADR-0030, ADR-0063).
        Orm::TeacherSchool.create!(teacher:, school:, primary: true) if school
        classrooms.each { |classroom| Orm::TeacherClassroom.create!(teacher:, classroom:) }
      end
    end

    # ADR-0065: a direction account attached to its school, signing in by PIN alone. ADR-0077: joined by invitation or
    # by the school's code, on `joined_at`; archived by `archived_by` on `archived_at`.
    def create_school_admin(school: create_school, invited_by: nil, joined_via: "invitation", joined_at: Time.current,
                            archived_at: nil, archived_by: nil, **attributes)
      create_user(role: "school_admin", **attributes).tap do |admin|
        archived_by ||= create_team_member(second_factor: false) if archived_at
        Orm::SchoolStaff.create!(user: admin, school:, invited_by:, joined_via:, created_at: joined_at, archived_at:, archived_by:)
      end
    end

    # Returns the account; with a second factor, `member.totp_secret` is the clear secret
    # an authenticator app would hold, to compute the current code (ROTP::TOTP).
    def create_team_member(team_role: "admin", second_factor: true, **attributes)
      create_user(role: "team", team_role:, **attributes).tap do |member|
        next unless second_factor

        secret = ROTP::Base32.random
        Orm::TotpCredential.create!(user: member, secret:, confirmed_at: Time.current)
        member.define_singleton_method(:totp_secret) { secret }
      end
    end

    # Returns the invitation; `invitation.token` is the clear token of its URL.
    def create_invitation(kind: "team", contact: nil, team_role: ("content" if kind == "team"), school: nil,
                          position: ("principal" if kind == "school_staff"), invited_by: nil,
                          token: SecureRandom.base58(32), expires_at: 72.hours.from_now, **attributes)
      school ||= create_school if kind == "school_staff"
      contact ||= format("07%08d", factory_sequence)
      Orm::Invitation.create!(kind:, contact:, team_role:, school:, position:, invited_by:, expires_at:,
                              token_digest: secret_digest(token), **attributes)
                     .tap { |invitation| invitation.define_singleton_method(:token) { token } }
    end

    def create_pin_recovery_code(user: create_student, issued_by: create_teacher, code: "12345678",
                                 expires_at: 15.minutes.from_now, **attributes)
      Orm::PinRecoveryCode.create!(user:, issued_by:, code_digest: secret_digest(code), expires_at:, **attributes)
    end

    def create_backup_code(user: create_team_member, code: "abcd-efgh", **attributes)
      Orm::BackupCode.create!(user:, code_digest: secret_digest(code), **attributes)
    end

    def create_login_session(user: create_student, token: SecureRandom.base58(32), **attributes)
      Orm::Session.create!(user:, token_digest: secret_digest(token), created_at: Time.current, last_seen_at: Time.current,
                           **attributes)
    end

    def create_login_attempt(user: nil, contact: user&.contact || "0100000000", succeeded: false, kind: "pin", **attributes)
      Orm::LoginAttempt.create!(user:, contact:, succeeded:, kind:, **attributes)
    end

    def create_audit_event(actor: nil, action: "login.failed", **attributes)
      Orm::AuditEvent.create!(actor:, action:, **attributes)
    end

    # Entities::Identity::SecretDigest (ADR-0031, ADR-0032, ADR-0038), under the key the controllers inject.
    def secret_digest(value)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("lnclass-secrets"), value)
    end
  end
end

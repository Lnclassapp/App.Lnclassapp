# Accounts of every role and the identity technical rows (ADR-0031, ADR-0032, ADR-0037,
# ADR-0038, ADR-0050, ADR-0065, ADR-0066). Secrets are stored as the application stores them: PIN by bcrypt,
# codes and tokens by HMAC-SHA256 under the "lnclass-secrets" key, TOTP secret encrypted.
module Factories
  module Identity
    ActiveSupport::TestCase.include(self)

    CONTACT_PREFIXES = { "student" => "01", "teacher" => "05", "school_admin" => "07", "team" => "07" }.freeze

    # A school_admin gets a confirmed second factor by default, as the team does (ADR-0066 §4.2): a PIN-only session of
    # the direction is not an actor. `second_factor: false` leaves it to enroll.
    def create_user(role:, contact: nil, pin: "2468", last_name: "Koné", first_name: "Awa", gender: "female",
                    team_role: (role == "team" ? "admin" : nil), second_factor: role == "school_admin", **attributes)
      contact ||= format("%s%08d", CONTACT_PREFIXES.fetch(role), factory_sequence)
      Orm::User.create!(role:, contact:, pin:, last_name:, first_name:, gender:, team_role:, **attributes)
               .tap { |user| confirm_second_factor(user) if second_factor }
    end

    # Every student has a MENA number (ADR-0065), unique within a test; `student_number: nil` leaves it out.
    def create_student(classroom: nil, student_number: format("%08dA", factory_sequence), **attributes)
      create_user(role: "student", student_number:, **attributes).tap do |student|
        Orm::ClassroomStudent.create!(classroom:, student:, primary: true, joined_at: Time.current) if classroom
      end
    end

    def create_teacher(school: create_school, material: create_material, onboarded: true, classrooms: [], **attributes)
      create_user(role: "teacher", **attributes).tap do |teacher|
        Orm::TeacherProfile.create!(user: teacher, material:, onboarding_completed_at: (Time.current if onboarded))
        # school: nil — a teacher without a primary school: a pending account (ADR-0030, ADR-0063).
        Orm::TeacherSchool.create!(teacher:, school:, primary: true) if school
        classrooms.each { |classroom| Orm::TeacherClassroom.create!(teacher:, classroom:) }
      end
    end

    # Returns the account; with a second factor, `member.totp_secret` is the clear secret
    # an authenticator app would hold, to compute the current code (ROTP::TOTP).
    def create_team_member(team_role: "admin", second_factor: true, **attributes)
      create_user(role: "team", team_role:, second_factor:, **attributes)
    end

    # A member of a school's direction (ADR-0044, ADR-0066): a school_admin account with its second factor, actively
    # attached to the school with its position. `member.totp_secret` as for the team.
    def create_school_admin(school: create_school, position: "principal", invited_by: nil, joined_at: Time.current, **attributes)
      create_user(role: "school_admin", **attributes).tap do |member|
        Orm::SchoolStaff.create!(user: member, school:, position:, invited_by:, joined_at:)
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

    # `user.totp_secret` is the clear secret an authenticator app would hold.
    def confirm_second_factor(user)
      secret = ROTP::Base32.random
      Orm::TotpCredential.create!(user:, secret:, confirmed_at: Time.current)
      user.define_singleton_method(:totp_secret) { secret }
    end

    # Entities::Identity::SecretDigest (ADR-0031, ADR-0032, ADR-0038), under the key the controllers inject.
    def secret_digest(value)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("lnclass-secrets"), value)
    end
  end
end

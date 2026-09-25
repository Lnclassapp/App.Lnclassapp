require "test_helper"

module Repositories
  module Identity
    class SecondFactorRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = SecondFactorRepository.new
        @member = create_team_member(second_factor: false)
        @now = Time.current.change(usec: 0)
      end

      def code_at(secret, time) = ROTP::TOTP.new(secret).at(time)

      test "without a secret there is no state and no code is accepted" do
        assert_nil @repository.state_for(user_id: @member.id)
        assert_nil @repository.verify_code(user_id: @member.id, code: "123456", now: @now)
      end

      test "begin_enrollment stores an encrypted secret and its provisioning URI" do
        enrollment = @repository.begin_enrollment(user_id: @member.id, label: "0701020304")

        credential = Orm::TotpCredential.find_by!(user_id: @member.id)
        assert_equal enrollment.secret, credential.secret
        assert_not_equal enrollment.secret, credential.ciphertext_for(:secret)
        assert_match %r{\Aotpauth://totp/Lnclass:0701020304\?secret=#{enrollment.secret}&issuer=Lnclass\z}, enrollment.provisioning_uri
        assert_equal Ports::Identity::SecondFactorRepositoryPort::State.new(confirmed: false, backup_codes_left: 0),
                     @repository.state_for(user_id: @member.id)
      end

      test "begin_enrollment replaces an unconfirmed secret" do
        first = @repository.begin_enrollment(user_id: @member.id, label: "x")
        second = @repository.begin_enrollment(user_id: @member.id, label: "x")

        assert_not_equal first.secret, second.secret
        assert_equal [ second.secret ], Orm::TotpCredential.where(user_id: @member.id).map(&:secret)
      end

      test "a confirmed secret is never replaced" do
        member = create_team_member

        assert_raises(ActiveRecord::RecordNotUnique) { @repository.begin_enrollment(user_id: member.id, label: "x") }
      end

      test "verify_code accepts one step of drift and refuses a replayed code" do
        secret = @repository.begin_enrollment(user_id: @member.id, label: "x").secret

        step = @repository.verify_code(user_id: @member.id, code: code_at(secret, @now - 30), now: @now)

        assert_equal (@now.to_i - 30) / 30, step
        assert_nil @repository.verify_code(user_id: @member.id, code: code_at(secret, @now - 30), now: @now)
        assert_equal step + 1, @repository.verify_code(user_id: @member.id, code: code_at(secret, @now), now: @now)
      end

      test "verify_code refuses an older step and a wrong code" do
        secret = @repository.begin_enrollment(user_id: @member.id, label: "x").secret
        @repository.verify_code(user_id: @member.id, code: code_at(secret, @now + 30), now: @now)

        assert_nil @repository.verify_code(user_id: @member.id, code: code_at(secret, @now), now: @now)
        assert_nil @repository.verify_code(user_id: @member.id, code: code_at(secret, @now - 120), now: @now)
      end

      test "confirm activates the factor and replaces the backup codes" do
        @repository.begin_enrollment(user_id: @member.id, label: "x")
        create_backup_code(user: @member, code: "ancien")

        assert @repository.confirm(user_id: @member.id, backup_code_digests: %w[a b c], at: @now)

        assert_equal Ports::Identity::SecondFactorRepositoryPort::State.new(confirmed: true, backup_codes_left: 3),
                     @repository.state_for(user_id: @member.id)
        assert_equal %w[a b c], Orm::BackupCode.where(user_id: @member.id).order(:code_digest).pluck(:code_digest)
      end

      test "a backup code is consumed once" do
        @repository.confirm(user_id: @member.id, backup_code_digests: %w[a b], at: @now)

        assert @repository.consume_backup_code(user_id: @member.id, code_digest: "a", at: @now)
        assert_not @repository.consume_backup_code(user_id: @member.id, code_digest: "a", at: @now)
        assert_not @repository.consume_backup_code(user_id: create_team_member.id, code_digest: "b", at: @now)
      end

      test "reset removes the secret and the codes" do
        member = create_team_member
        create_backup_code(user: member)

        assert @repository.reset(user_id: member.id)

        assert_nil @repository.state_for(user_id: member.id)
        assert_not Orm::BackupCode.exists?(user_id: member.id)
      end
    end
  end
end

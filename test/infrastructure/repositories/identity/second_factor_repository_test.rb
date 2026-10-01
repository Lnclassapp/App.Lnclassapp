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

      # Decoded issuer parameter and label of the QR code, with RAILWAY_ENVIRONMENT_NAME set as given, then restored.
      def issuer_and_label_in(railway_environment:)
        previous = ENV.fetch("RAILWAY_ENVIRONMENT_NAME", nil)
        ENV["RAILWAY_ENVIRONMENT_NAME"] = railway_environment
        uri = URI(@repository.begin_enrollment(user_id: @member.id, label: "0701020304").provisioning_uri)
        [ URI.decode_www_form(uri.query).to_h.fetch("issuer"), URI.decode_uri_component(uri.path.delete_prefix("/")) ]
      ensure
        ENV["RAILWAY_ENVIRONMENT_NAME"] = previous
      end

      test "without a secret there is no state and no code is accepted" do
        assert_nil @repository.state_for(user_id: @member.id)
        assert_nil @repository.verify_code(user_id: @member.id, code: "123456", now: @now)
      end

      test "begin_enrollment stores an encrypted secret and its provisioning URI" do
        enrollment = @repository.begin_enrollment(user_id: @member.id, label: "0701020304")

        credential = Orm::TotpCredential.find_by!(user_id: @member.id)
        assert_equal enrollment.secret, credential.secret
        assert_not_equal enrollment.secret, credential.ciphertext_for(:secret)
        # Outside Railway the test environment names the issuer: « Lnclass (test) », URL-encoded.
        assert_match %r{\Aotpauth://totp/Lnclass%20%28test%29:0701020304\?secret=#{enrollment.secret}&issuer=Lnclass%20%28test%29\z},
                     enrollment.provisioning_uri
        assert_equal Ports::Identity::SecondFactorRepositoryPort::State.new(confirmed: false, backup_codes_left: 0),
                     @repository.state_for(user_id: @member.id)
      end

      # Chantier totp-emetteur-par-environnement: one number enrolled in production and in Develop gave two QR codes
      # with the same issuer and label, so the authenticator app replaced one entry with the other.
      test "outside production the issuer names the Railway environment" do
        issuer, label = issuer_and_label_in(railway_environment: "Develop")

        assert_equal "Lnclass (Develop)", issuer
        assert_equal "Lnclass (Develop):0701020304", label
      end

      test "in the Railway production environment the issuer stays Lnclass" do
        issuer, label = issuer_and_label_in(railway_environment: "production")

        assert_equal "Lnclass", issuer
        assert_equal "Lnclass:0701020304", label
      end

      test "without a Railway environment the Rails environment names the issuer" do
        issuer, = issuer_and_label_in(railway_environment: nil)

        assert_equal "Lnclass (test)", issuer
      end

      test "a colon in the environment name cannot split the issuer from the label" do
        issuer, label = issuer_and_label_in(railway_environment: "pr:42")

        assert_equal "Lnclass (pr42)", issuer
        assert_equal "Lnclass (pr42):0701020304", label
      end

      # Chantier enrolement-secret-stable: reopening the page must not turn the QR code already shown into a wrong one.
      test "begin_enrollment keeps the unconfirmed secret" do
        first = @repository.begin_enrollment(user_id: @member.id, label: "x")
        second = @repository.begin_enrollment(user_id: @member.id, label: "x")

        assert_equal first, second
        assert_equal [ first.secret ], Orm::TotpCredential.where(user_id: @member.id).map(&:secret)
      end

      test "two enrollments begun at once share the secret written first" do
        written_first = Orm::TotpCredential.create!(user_id: @member.id, secret: ROTP::Base32.random)
        lookups = 0
        # The first lookup runs before the other request's insert: it misses the row, the insert then collides with it.
        @repository.define_singleton_method(:unconfirmed_secret) { |user_id| super(user_id) unless (lookups += 1) == 1 }

        enrollment = @repository.begin_enrollment(user_id: @member.id, label: "x")

        assert_equal written_first.secret, enrollment.secret
        assert_equal [ written_first.secret ], Orm::TotpCredential.where(user_id: @member.id).map(&:secret)
      end

      test "after a reset, the enrollment draws a new secret" do
        before = @repository.begin_enrollment(user_id: @member.id, label: "x")
        @repository.reset(user_id: @member.id)

        assert_not_equal before.secret, @repository.begin_enrollment(user_id: @member.id, label: "x").secret
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

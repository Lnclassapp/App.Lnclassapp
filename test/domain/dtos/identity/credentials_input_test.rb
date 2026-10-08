require "test_helper"

module Dtos
  module Identity
    class CredentialsInputTest < ActiveSupport::TestCase
      test "normalise le contact et valide le PIN" do
        input = CredentialsInput.new(contact: "+225 07 01 02 03 04", pin: "2468", ip: "1.2.3.4", user_agent: "UA")

        assert input.valid?
        assert_equal "0701020304", input.contact
        assert_equal "0701020304", input.attempt_key
        assert_equal "+225 07 01 02 03 04", input.raw_contact
      end

      test "un contact invalide devient absent, et garde sa forme brute pour le journal" do
        input = CredentialsInput.new(contact: "0801020304", pin: "2468")

        assert_not input.valid?
        assert input.errors.of_kind?(:contact, :blank)
        assert_equal "0801020304", input.attempt_key
      end

      test "tronque un contact brut à 20 caractères pour le journal" do
        assert_equal 20, CredentialsInput.new(contact: "x" * 40).attempt_key.length
      end

      test "exige un PIN à 4 chiffres" do
        blank = CredentialsInput.new(contact: "0701020304", pin: "")
        wrong = CredentialsInput.new(contact: "0701020304", pin: "12a4")

        assert blank.invalid?
        assert blank.errors.of_kind?(:pin, :blank)
        assert wrong.invalid?
        assert wrong.errors.of_kind?(:pin, :invalid)
      end

      test "ADR-0085 §4.5 : le client est le site par défaut, ou l'une des deux coques, rien d'autre" do
        web = CredentialsInput.new(contact: "0701020304", pin: "2468")
        other = CredentialsInput.new(contact: "0701020304", pin: "2468", client: "ios")

        assert_equal "web", web.client
        %w[web android_student android_teacher].each do |client|
          assert CredentialsInput.new(contact: "0701020304", pin: "2468", client:).valid?, client
        end
        assert other.invalid?
        assert other.errors.of_kind?(:client, :inclusion)
      end

      test "ADR-0085 §4.5 : le site admet tous les rôles, chaque coque n'en admet qu'un" do
        admitted = %w[web android_student android_teacher].index_with do |client|
          Entities::Identity::User::ROLES.select { CredentialsInput.new(client:).admits?(it) }
        end

        assert_equal({ "web" => %w[student teacher school_admin team], "android_student" => %w[student],
                       "android_teacher" => %w[teacher] }, admitted)
      end
    end
  end
end

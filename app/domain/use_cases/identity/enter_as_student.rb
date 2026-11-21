# 🧠 DOMAINE · UseCases::Identity::EnterAsStudent
# Rôle : l'entrée élève unique : un numéro inscrit se connecte (tout rôle, par Authenticate) ; un numéro inconnu confirme son code avant de créer son compte
# ADR  : 0028 (exempté de policy : l'acteur n'existe pas encore), 0050, XXXX-entree-eleve-revele-un-numero-inscrit
module UseCases
  module Identity
    class EnterAsStudent
      # outcome : :signed_in (user, token) · :new_number (contact) · :confirmed (contact)
      Entered = Data.define(:outcome, :contact, :user, :token)
      # ADR-XXXX-entree-eleve-revele-un-numero-inscrit : sur un numéro inscrit, le refus nomme le code, pas le couple.
      WRONG_PIN = { pin: [ :wrong_pin ] }.freeze

      def initialize(users:, login_attempts:, sessions:, audit_log:, digest_key:, clock:)
        @users = users
        @authenticate = Authenticate.new(users:, login_attempts:, sessions:, audit_log:, digest_key:, clock:)
      end

      # dto : Dtos::Identity::StudentEntryInput.
      # → success(Entered) | :invalid (formulaire, code faux : errors[:pin] = [:wrong_pin], confirmation différente)
      #   | :locked (errors[:retry_after]) | :conflict (coque Android d'un autre rôle, comme Authenticate)
      # Un numéro inscrit passe toujours par Authenticate, confirmation ou pas : jamais de second compte sur un numéro.
      def call(dto:)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?
        return sign_in(dto) if @users.find_by_contact(contact: dto.contact)
        return entered(:new_number, dto) unless dto.confirming?
        return Shared::Result.failure(:invalid, errors: { pin_confirmation: [ :confirmation ] }) unless dto.pin == dto.pin_confirmation

        entered(:confirmed, dto)
      end

      private

      def sign_in(dto)
        result = @authenticate.call(dto:)
        return Shared::Result.success(Entered.new(outcome: :signed_in, contact: dto.contact, user: result.value.user, token: result.value.token)) if result.success?
        return Shared::Result.failure(:invalid, errors: WRONG_PIN) if result.errors == Authenticate::INVALID

        result
      end

      def entered(outcome, dto) = Shared::Result.success(Entered.new(outcome:, contact: dto.contact, user: nil, token: nil))
    end
  end
end

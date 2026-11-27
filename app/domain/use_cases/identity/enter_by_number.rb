# 🧠 DOMAINE · UseCases::Identity::EnterByNumber
# Rôle : l'entrée « numéro d'abord » de /login et /student : le numéro seul dit s'il a un compte ; avec le code, un numéro inscrit se connecte
#        (tout rôle, par Authenticate), un numéro inconnu confirme son entrée (code tapé une fois) quand la page crée des comptes
# ADR  : 0028 (exempté de policy : l'acteur n'existe pas encore), 0050, 0141-entree-eleve-revele-un-numero-inscrit, 0148-connexion-revele-un-numero-inscrit
module UseCases
  module Identity
    class EnterByNumber
      # outcome : :known (contact) · :new_number (contact) · :signed_in (user, token) · :confirmed (contact)
      Entered = Data.define(:outcome, :contact, :user, :token)
      # ADR-0141 : sur un numéro inscrit, le refus nomme le code, pas le couple.
      WRONG_PIN = { pin: [ :wrong_pin ] }.freeze

      def initialize(users:, login_attempts:, sessions:, audit_log:, digest_key:, clock:)
        @users = users
        @authenticate = Authenticate.new(users:, login_attempts:, sessions:, audit_log:, digest_key:, clock:)
      end

      # dto : Dtos::Identity::NumberEntryInput (ou StudentEntryInput) ; creates : false à /login, qui ne crée pas de compte.
      # → success(Entered) | :invalid (formulaire, code faux : errors[:pin] = [:wrong_pin])
      #   | :locked (errors[:retry_after]) | :conflict (coque Android d'un autre rôle, comme Authenticate)
      # Rien n'est rendu du compte avant le code juste : ni nom, ni rôle. Un numéro inscrit passe toujours par Authenticate :
      # jamais de second compte sur un numéro.
      def call(dto:, creates: true)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        known = !@users.find_by_contact(contact: dto.contact).nil?
        return entered(known ? :known : :new_number, dto) if dto.lookup?
        return sign_in(dto) if known

        entered(creates ? :confirmed : :new_number, dto)
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

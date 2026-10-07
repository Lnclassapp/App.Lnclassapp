# 🧠 DOMAINE · UseCases::Identity::RecordAppOpen
# Rôle : date l'ouverture de Lnclass depuis l'icône de l'app installée, sur le compte de l'acteur ; une panne du stockage ne lève pas
# ADR  : 0026, 0028, 0082 (§4.3)
module UseCases
  module Identity
    class RecordAppOpen
      # reporter : répond à report(error, handled: true, context:) (Rails.error, injecté par le contrôleur).
      # recoverable : la ou les classes d'erreur du stockage que l'enregistrement avale (ActiveRecord::ActiveRecordError,
      # nommée par la delivery : le domaine ne connaît pas ActiveRecord). Toute autre erreur est un bogue et remonte.
      def initialize(users:, policy:, clock:, reporter:, recoverable:)
        @users = users
        @policy = policy
        @clock = clock
        @reporter = reporter
        @recoverable = Array(recoverable)
      end

      # L'acteur ne marque que son propre compte. → Result(true : ouverture datée | false : panne signalée)
      # | :forbidden (ni élève ni enseignant : rien n'est écrit ; un refus n'est pas une erreur, il n'est pas signalé)
      def call(actor:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        mark(actor)
      end

      private

      def mark(actor)
        Shared::Result.success(@users.mark_app_opened(user_id: actor.user_id, at: @clock.now))
      rescue *@recoverable => error
        # Une panne du stockage ne bloque jamais l'accueil (ADR-0082 §4.3) : elle est signalée, l'ouverture n'est pas datée.
        @reporter.report(error, handled: true, context: { user_id: actor.user_id })
        Shared::Result.success(false)
      end
    end
  end
end

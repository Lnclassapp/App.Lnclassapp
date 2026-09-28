# 🧠 DOMAINE · Policies::Identity::SecondFactorPolicy
# Rôle : enrôler ou vérifier le second facteur : compte de l'équipe ou de la direction, à la bonne étape de sa session
# ADR  : 0028, 0031, 0066
module Policies
  module Identity
    class SecondFactorPolicy
      STEPS = %i[enroll verify].freeze

      # session : Entities::Identity::SessionState ; step : :enroll ou :verify ; actor : nil avant vérification
      def call(actor:, session:, step:)
        raise ArgumentError, "étape inconnue : #{step.inspect}" unless STEPS.include?(step)
        return Shared::Result.failure(:forbidden) unless session&.privileged?
        return Shared::Result.failure(:forbidden) if actor && actor.user_id != session.user_id
        return refuse(:already_enrolled) if session.second_factor_confirmed && step == :enroll
        return refuse(:not_enrolled) if !session.second_factor_confirmed && step == :verify
        return refuse(:already_verified) if session.verified? && step == :verify

        Shared::Result.success
      end

      private

      def refuse(reason) = Shared::Result.failure(:forbidden, errors: { base: [ reason ] })
    end
  end
end

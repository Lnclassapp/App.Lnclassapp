# 🧠 DOMAINE · UseCases::Billing::ActivateCard
# Rôle : un élève active une carte avec son code ; la carte est verrouillée le temps de la décision, l'école est celle de sa classe
# ADR  : cartes-activation (contexte billing, §4.2, §4.3 et §4.10)
module UseCases
  module Billing
    class ActivateCard
      # schools : répond à #school_id_of_student(student_id:) → id de l'école de la classe principale active, ou nil.
      def initialize(cards:, schools:, audit_log:, transaction:, policy:, clock:)
        @cards = cards
        @schools = schools
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # raw_code : tel que saisi (minuscules, espaces, tirets). → Result(Entities::Billing::ActivationCard activée) | :forbidden
      # | :invalid code: [:unknown] | :invalid base: [:card_cancelled] | :conflict base: [:card_used]
      # | :conflict base: [:already_subscribed], subscribed_until: [Date]
      def call(actor:, raw_code:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        code = Entities::Billing::ActivationCode.normalize(raw_code)
        return unknown unless Entities::Billing::ActivationCode.well_formed?(code)

        @transaction.call { activate(actor, code) }
      end

      private

      def activate(actor, code)
        card = @cards.lock_by_code(code:)
        return unknown if card.nil?
        return Shared::Result.failure(:conflict, errors: { base: [ :card_used ] }) if card.activated?
        return Shared::Result.failure(:invalid, errors: { base: [ :card_cancelled ] }) if card.cancelled?

        subscribed_until = @cards.subscribed_until(student_id: actor.user_id)
        if subscribed_until && subscribed_until >= card.valid_until
          return Shared::Result.failure(:conflict, errors: { base: [ :already_subscribed ], subscribed_until: [ subscribed_until ] })
        end

        school_id = @schools.school_id_of_student(student_id: actor.user_id)
        activated = @cards.activate(card_id: card.id, student_id: actor.user_id, school_id:, at: @clock.now)
        return activated if activated.failure?

        @audit_log.record(action: "billing.card_activated", actor_id: actor.user_id, at: @clock.now, subject_type: "ActivationCard",
                          subject_id: card.id, metadata: { serial: card.serial, relay_point_id: card.relay_point_id, school_id: })
        activated
      end

      def unknown = Shared::Result.failure(:invalid, errors: { code: [ :unknown ] })
    end
  end
end

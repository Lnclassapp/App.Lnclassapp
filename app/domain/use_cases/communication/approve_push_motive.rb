# 🧠 DOMAINE · UseCases::Communication::ApprovePushMotive
# Rôle : l'équipe valide un motif du plan du jour : il reste ouvert jusqu'au soir, les élèves concernés maintenant sont comptés ; refus après la dernière fenêtre
# ADR  : XXXX envois de notifications (§3.2, §4.4) · UDR : XXXX écran notifications de l'équipe (§3.4)
module UseCases
  module Communication
    class ApprovePushMotive
      # Après la dernière fenêtre du jour (20 h 20 en semaine, 20 h le dimanche, à Abidjan = UTC), plus rien ne part : la validation serait sans effet.
      def self.closed?(now) = Entities::Communication::SendingWindow.next_open_at(now).to_date != now.utc.to_date

      # candidates : PushCandidatesPort ; deliveries, settings, approvals : les ports de dépôt ; clock : répond à `now`.
      def initialize(candidates:, deliveries:, settings:, approvals:, policy:, clock:)
        @candidates = candidates
        @deliveries = deliveries
        @settings = settings
        @approvals = approvals
        @policy = policy
        @clock = clock
      end

      # → Result(PushApproval) | :forbidden | :not_found (motif non validable) | :expired (après la dernière fenêtre)
      #   | :conflict (déjà validé aujourd'hui) | :invalid (motif automatique ou aucun élève concerné)
      def call(actor:, motive:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:not_found) unless Entities::Communication::PushMotive::PLANNABLE.include?(motive)

        now = @clock.now
        return Shared::Result.failure(:expired) if self.class.closed?(now)

        on_date = now.utc.to_date
        return Shared::Result.failure(:conflict) if @approvals.for_date(on_date:).any? { it.motive == motive }
        return Shared::Result.failure(:invalid) if @settings.automatic_motives.include?(motive)

        recipients = recipients(motive, now)
        return Shared::Result.failure(:invalid) if recipients.empty?

        record(actor, motive, on_date, now, recipients)
      end

      private

      def record(actor, motive, on_date, now, recipients)
        return Shared::Result.failure(:conflict) if @approvals.create(on_date:, motive:, by: actor.user_id, at: now, recipients:) == :already_approved

        Shared::Result.success(Entities::Communication::PushApproval.new(on_date:, motive:, approved_by_id: actor.user_id, approved_at: now,
                                                                         recipients_count: recipients.size))
      end

      # [[user_id, object_key]] des élèves concernés maintenant, ni expirés ni déjà prévenus de cet objet : leur nombre est affiché ;
      # ceux qui le deviennent plus tard dans la journée reçoivent aussi le motif.
      def recipients(motive, now)
        @candidates.for(now:).select { it.motive == motive && !it.expired?(now) && !sent?(it) }.map { [ it.user_id, it.object_key ] }.uniq
      end

      def sent?(candidate) = @deliveries.sent?(user_id: candidate.user_id, motive: candidate.motive, object_key: candidate.object_key)
    end
  end
end

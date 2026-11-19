# 🔌 INFRA · Queries::Communication::PushCandidates::Inactive
# Rôle : candidats du motif inactive : élève abonné sans activité depuis 3, 7 ou 14 jours (dates d'Abidjan), une relance par palier
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class Inactive
        STEPS = [ 3, 7, 14 ].freeze

        def initialize(last_activity: LastActivity.new) = @last_activity = last_activity

        # → [Entities::Communication::PushCandidate]. Le palier est atteint le jour même (valid_until : fin de ce jour) ;
        # passé le dernier palier, plus rien sans nouvelle activité. Abidjan est à UTC+0 : la date UTC est la date d'Abidjan.
        def for(now:, user_ids: nil)
          today = now.utc.to_date
          last_active = @last_activity.at(user_ids: subscribed_user_ids(user_ids))
          last_active.filter_map do |user_id, last|
            day = last.utc.to_date
            step = (today - day).to_i
            next unless STEPS.include?(step)

            Entities::Communication::PushCandidate.new(user_id:, motive: "inactive", object_key: "inactive:#{day}:#{step}", url: "/",
                                                       variables: {}, valid_until: today.in_time_zone("UTC").end_of_day)
          end
        end

        private

        # Abonnés, non coupés, non anonymisés (LastActivity écarte les comptes qui ne sont pas des élèves).
        def subscribed_user_ids(user_ids)
          Subscribers.scope(user_ids).distinct.pluck(:user_id)
        end
      end
    end
  end
end

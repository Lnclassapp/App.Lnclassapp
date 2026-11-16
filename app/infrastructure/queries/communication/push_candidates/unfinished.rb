# 🔌 INFRA · Queries::Communication::PushCandidates::Unfinished
# Rôle : candidats du motif unfinished : session d'exercice ouverte depuis plus de 24 h, sans réponse depuis 24 h, commencée il y a moins de 7 jours
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class Unfinished
        IDLE = 24.hours
        LIFETIME = 7.days

        # → [Entities::Communication::PushCandidate] ; une lecture des sessions (la matière jointe), une des abonnés.
        def for(now:)
          urls = Rails.application.routes.url_helpers
          sessions(now).map do |user_id, public_id, started_at, material|
            Entities::Communication::PushCandidate.new(user_id:, motive: "unfinished", object_key: "unfinished:#{public_id}",
                                                       url: urls.exercise_session_path(public_id), variables: { material: },
                                                       valid_until: started_at + LIFETIME)
          end
        end

        private

        def sessions(now)
          Orm::ExerciseSession
            .joins(exercise: { course: :material })
            .where(student_id: subscribed_user_ids, status: "started", started_at: (now - LIFETIME + 1.second)..(now - IDLE))
            .where.not(id: Orm::QuestionAttempt.where(answered_at: (now - IDLE)..).select(:exercise_session_id))
            .order(:id).pluck(:student_id, :public_id, :started_at, "materials.name")
        end

        # Abonnés, non coupés, non anonymisés.
        def subscribed_user_ids
          Orm::Communication::PushSubscription.joins(:user).where(users: { anonymized_at: nil })
                                              .where.not(user_id: Orm::Communication::PushPreference.where.not(turned_off_at: nil).select(:user_id))
                                              .select(:user_id)
        end
      end
    end
  end
end

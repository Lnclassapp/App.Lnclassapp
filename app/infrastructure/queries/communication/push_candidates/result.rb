# 🔌 INFRA · Queries::Communication::PushCandidates::Result
# Rôle : candidats du motif result : copie rendue hors ligne reçue depuis moins de 24 h, ou médaille obtenue depuis 2 h à 24 h, pour un élève non revenu depuis
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · 0033 (médailles) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class Result
        WINDOW = 24.hours
        MEDAL_DELAY = 2.hours
        # La fermeture écrit la dernière activité (completed_at) quelques instants avant ou après l'événement : ce n'est pas un retour.
        SAME_VISIT = 1.minute

        def initialize(last_activity: LastActivity.new) = @last_activity = last_activity

        # → [Entities::Communication::PushCandidate] ; la copie prime sur la médaille de la même session.
        def for(now:)
          user_ids = subscribed_user_ids
          events = copies(user_ids, now) + medals(user_ids, now)
          return [] if events.empty?

          last_active = @last_activity.at(user_ids: events.map(&:first).uniq)
          urls = Rails.application.routes.url_helpers
          events.uniq { it[1] }.filter_map do |user_id, public_id, at, material, kind|
            next if last_active.fetch(user_id, at) > at + SAME_VISIT

            Entities::Communication::PushCandidate.new(user_id:, motive: "result", object_key: "result:#{public_id}",
                                                       url: urls.exercise_session_result_path(public_id), variables: { kind:, material: },
                                                       valid_until: at + WINDOW)
          end
        end

        private

        # [user_id, public_id de la session, instant, matière, kind]
        def copies(user_ids, now)
          sessions(user_ids).where(received_at: (now - WINDOW)..now).pluck(:student_id, :public_id, :received_at, "materials.name")
                            .map { |*head, material| [ *head, material, "copy" ] }
        end

        def medals(user_ids, now)
          Orm::ExerciseBadge.joins(:exercise_session, exercise: { course: :material })
                            .where(student_id: user_ids, awarded_at: (now - WINDOW)..(now - MEDAL_DELAY))
                            .order(:id).pluck(:student_id, "exercise_sessions.public_id", :awarded_at, "materials.name")
                            .map { |*head, material| [ *head, material, "medal" ] }
        end

        def sessions(user_ids)
          Orm::ExerciseSession.joins(exercise: { course: :material }).where(student_id: user_ids, status: "completed").order(:id)
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

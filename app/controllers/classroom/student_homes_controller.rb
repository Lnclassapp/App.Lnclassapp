# 🌐 DELIVERY · Classroom::StudentHomesController
# Rôle : accueil élève (CL-23, TR-04, AS-36) et son carrousel d'annonces ; sans classe principale active, un seul saut vers l'écran de sortie
# ADR  : 0026, 0030, 0040, 0078 · UDR : 0006, 0010, 0071
module Classroom
  class StudentHomesController < AuthenticatedController
    RECENT_ACTIVITY_FRAME = "student_home_recent_activity".freeze

    allow_roles :student

    # Le frame différé de l'activité récente redemande cette page : il ne reçoit que son partial.
    def show
      return render_recent_activity if turbo_frame_request_id == RECENT_ACTIVITY_FRAME

      @home = query.call(student_id: current_actor.user_id)
      return redirect_to pending_account_path if @home.nil?

      @announcements = announcements
    end

    private

    def render_recent_activity
      render partial: "recent_activity", locals: { sessions: query.recent_sessions(student_id: current_actor.user_id) }
    end

    def query = Queries::Classroom::StudentHomeQuery.new

    # UDR-0071 §3.5 : les cartes du carrousel par la règle de lecture, en un nombre fixe de requêtes (ADR-0067).
    def announcements
      reader = Queries::Communication::ReadableMessages.new.reader_for(actor: current_actor)
      Queries::Communication::InboxQuery.new.carousel(reader:, now: Time.current)
    end
  end
end

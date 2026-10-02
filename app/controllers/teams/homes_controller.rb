# 🌐 DELIVERY · Teams::HomesController
# Rôle : accueil équipe (TR-09, CA-25) : compteurs, référentiel, raccourcis ; le contenu récent dans un frame différé
# ADR  : 0026, 0028, 0038 · UDR : 0006, 0018
module Teams
  class HomesController < BaseController
    RECENT_CONTENT_FRAME = "team_home_recent_content".freeze

    helper_method :import_status_tone

    # Le frame différé du contenu récent redemande cette page : il ne reçoit que son partial.
    def show
      return render_recent_content if turbo_frame_request_id == RECENT_CONTENT_FRAME

      @home = query.call
      # « Inviter un membre » ne s'affiche qu'à qui la policy de l'invitation laisse passer : un admin (ADR-0038).
      @can_invite = Policies::Identity::InviteTeamPolicy.new.call(actor: current_actor).success?
    end

    private

    def render_recent_content
      render partial: "recent_content",
             locals: { courses: query.recent_courses, exercises: query.recent_exercises, imports: query.recent_imports }
    end

    def import_status_tone(status) = Teams::ImportsController::STATUS_TONES.fetch(status)

    def query = Queries::Catalog::TeamHomeQuery.new
  end
end

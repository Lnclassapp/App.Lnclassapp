# 🌐 DELIVERY · Classroom::StudentHomesController
# Rôle : accueil élève (CL-23, TR-04, AS-36) et son carrousel d'annonces ; sans classe principale active, « Choisis ta classe » et, une fois, le retrait
# ADR  : 0026, 0030, 0040, 0078, 0085, 0089 (§4.1) · UDR : 0006, 0010, 0071, 0081 (§3.5), 0084 (§3.6)
module Classroom
  class StudentHomesController < AuthenticatedController
    RECENT_ACTIVITY_FRAME = "student_home_recent_activity".freeze
    # L'heure du dernier retrait déjà annoncé, gardée dans la session Rails : le bandeau ne le dit qu'une fois.
    REMOVAL_NOTICE = :removal_noticed_at

    allow_roles :student

    # Le frame différé de l'activité récente redemande cette page : il ne reçoit que son partial.
    def show
      return render_recent_activity if turbo_frame_request_id == RECENT_ACTIVITY_FRAME

      @home = query.call(student_id: current_actor.user_id)
      return no_classroom if @home.nil?

      @announcements = announcements
      # ADR-0089 §4.1 : l'exercice du jour n'est calculé que sans travail de l'enseignant (priorité stricte).
      @daily = daily_exercise if @home.assigned_exercises.empty?
    end

    private

    def render_recent_activity
      render partial: "recent_activity", locals: { sessions: query.recent_sessions(student_id: current_actor.user_id) }
    end

    def query = Queries::Classroom::StudentHomeQuery.new

    # IL-14 : sans classe, l'accueil propose d'en choisir une (_no_classroom), et l'historique s'il y en a un (lot R,
    # ADR-0036) ; un retrait récent (StudentHomeQuery) se dit dans le bandeau, une fois par retrait et par session.
    def no_classroom
      @archived = Queries::Classroom::StudentArchiveQuery.new.any?(student_id: current_actor.user_id)
      removed_at = query.last_classroom(student_id: current_actor.user_id).recent_removal_at&.to_i
      return if removed_at.nil? || session[REMOVAL_NOTICE] == removed_at

      session[REMOVAL_NOTICE] = removed_at
      flash.now[:warning] = t(".removed")
    end

    def daily_exercise = Queries::Assessment::DailyExerciseQuery.new.call(student_id: current_actor.user_id, today: Time.zone.today)

    # UDR-0071 §3.5 : les cartes du carrousel par la règle de lecture, en un nombre fixe de requêtes (ADR-0067).
    def announcements
      reader = Queries::Communication::ReadableMessages.new.reader_for(actor: current_actor)
      Queries::Communication::InboxQuery.new.carousel(reader:, now: Time.current)
    end
  end
end

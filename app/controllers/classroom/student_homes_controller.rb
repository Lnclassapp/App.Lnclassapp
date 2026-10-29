# 🌐 DELIVERY · Classroom::StudentHomesController
# Rôle : accueil élève (CL-23, TR-04, AS-36) : la carte du prochain exercice, la grille, le carrousel d'annonces, l'historique différé ; sans classe principale active, « Choisis ta classe » et, une fois, le retrait
# ADR  : 0026, 0030, 0040, 0078, 0085, 0089 (§4.1) · UDR : 0006, 0010, 0071, 0081 (§3.5), 0084 (§3.6), XXXX accueil élève (§3.3)
module Classroom
  class StudentHomesController < AuthenticatedController
    RECENT_ACTIVITY_FRAME = "student_home_recent_activity".freeze
    # L'heure du dernier retrait déjà annoncé, gardée dans la session Rails : le bandeau ne le dit qu'une fois.
    REMOVAL_NOTICE = :removal_noticed_at

    allow_roles :student

    # PRD CA-D1 : la grille a 7 cases, 6 matières au plus puis « Inviter ».
    MAX_SUBJECTS = 6
    # Les états de la carte qui proposent l'exercice du jour (UDR accueil élève §3.3, états 4 et 5).
    DAILY_STATES = %i[all_done unassigned].freeze

    # Le frame différé de l'historique redemande cette page : il ne reçoit que son partial.
    def show
      return render_history if turbo_frame_request_id == RECENT_ACTIVITY_FRAME

      @home = query.call(student_id: current_actor.user_id)
      return no_classroom if @home.nil?

      @announcements = announcements
      # ADR-0089 §4.1, UDR accueil élève §3.3 : l'exercice du jour n'est calculé que quand la carte le propose, sans travail
      # ouvert de l'enseignant (priorité stricte) : rien d'assigné, ou tout fait et aucune fiche à revoir.
      @daily = daily_exercise if DAILY_STATES.include?(@home.next_step.state)
    end

    private

    def render_history
      sessions = query.recent_sessions(student_id: current_actor.user_id)
      render partial: "history", locals: { sessions:, paused_exercise_ids: paused_exercise_ids(sessions.first(3)) }
    end

    # ADR-0115 : les exercices en pause de « Recommencer » parmi les lignes affichées ; les copies récentes de tous sont lues en
    # une requête, la règle reste Entities::Assessment::RestartPause.
    def paused_exercise_ids(sessions)
      completions = Repositories::Assessment::ExerciseSessionRepository.new
                                                                       .recent_completions_by_exercise(student_id: current_actor.user_id,
                                                                                                       exercise_ids: sessions.map(&:exercise_id).uniq)
      now = Time.zone.now
      completions.select { |_, times| Entities::Assessment::RestartPause.resume_at(completions: times, now:) }.keys.to_set
    end

    def query = Queries::Classroom::StudentHomeQuery.new

    # IL-14 : sans classe, la carte propose d'en choisir une (next_step/_no_classroom), et l'historique s'il y en a un (lot R,
    # ADR-0036) ; un retrait récent (StudentHomeQuery) se dit dans le bandeau, une fois par retrait et par session.
    def no_classroom
      @form = Dtos::Classroom::StudentRegistrationInput.new
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

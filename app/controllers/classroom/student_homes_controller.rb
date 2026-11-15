# 🌐 DELIVERY · Classroom::StudentHomesController
# Rôle : accueil élève (CL-23, TR-04, AS-36) : la carte de la classe, la grille, le carrousel d'annonces, « À faire » et l'historique différé (jamais vides) ; sans classe principale active, « Choisis ta classe », les matières du dernier niveau et, une fois, le retrait
# ADR  : 0026, 0030, 0040, 0078, 0085, 0089 (§4.1), hors-connexion (§4.1), 0126 (contexte billing, §4.5) · UDR : 0006, 0010, 0071, 0081 (§3.5), 0084 (§3.6), 0132 accueil élève (§3.3, amendement eleve-sans-prof), 0158 (§3 bandeau), 0173 §3
module Classroom
  class StudentHomesController < AuthenticatedController
    RECENT_ACTIVITY_FRAME = "student_home_recent_activity".freeze
    # L'heure du dernier retrait déjà annoncé, gardée dans la session Rails : le bandeau ne le dit qu'une fois.
    REMOVAL_NOTICE = :removal_noticed_at

    allow_roles :student
    keep_offline only: :show # hors-connexion §4.1 : l'accueil déjà ouvert reste lisible sans réseau

    # UDR-0173 écrans minimalistes style Wave §3 : la grille de « Mes matières » (4 colonnes), 8 matières au plus ; plus de case « Inviter ».
    MAX_SUBJECTS = 8
    # Le frame différé de l'historique redemande cette page : il ne reçoit que son partial.
    def show
      return render_history if turbo_frame_request_id == RECENT_ACTIVITY_FRAME

      @access = Queries::Billing::StudentAccessQuery.new.call(student_id: current_actor.user_id, at: Time.current)
      @home = query.call(student_id: current_actor.user_id)
      return no_classroom if @home.nil?

      # UDR-0173 écrans minimalistes style Wave §3 : plus d'« Exercice du jour » ni de carte du prochain exercice ; la carte de la classe, la grille, les annonces.
      @announcements = announcements
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
    # Chantier eleve-sans-prof : les matières de son dernier niveau connu, s'il en a un (plus d'exercice du jour, UDR-0173 §3).
    def no_classroom
      @form = Dtos::Classroom::StudentRegistrationInput.new
      @archived = Queries::Classroom::StudentArchiveQuery.new.any?(student_id: current_actor.user_id)
      @subjects = query.level_subjects(student_id: current_actor.user_id)
      @announcements = announcements
      removed_at = query.last_classroom(student_id: current_actor.user_id).recent_removal_at&.to_i
      return if removed_at.nil? || session[REMOVAL_NOTICE] == removed_at

      session[REMOVAL_NOTICE] = removed_at
      flash.now[:warning] = t(".removed")
    end

    # UDR-0071 §3.5 : les cartes du carrousel par la règle de lecture, en un nombre fixe de requêtes (ADR-0067).
    def announcements
      reader = Queries::Communication::ReadableMessages.new.reader_for(actor: current_actor)
      Queries::Communication::InboxQuery.new.carousel(reader:, now: Time.current)
    end
  end
end

# 🌐 DELIVERY · Classroom::StudentHomesController
# Rôle : accueil élève (CL-23, TR-04, AS-36) : la carte de la classe, « Ton premier exercice » tant qu'aucun n'est réussi, la grille, les annonces, « À faire » et l'historique différé ; une section vide est absente ; sans classe principale active, « Choisis ta classe », les matières du dernier niveau et, une fois, le retrait
# ADR  : 0026, 0030, 0040, 0078, 0085, 0089 (§4.1), hors-connexion (§4.1), 0126 (contexte billing, §4.5) · UDR : 0006, 0010, 0071, 0081 (§3.5), 0084 (§3.6), 0132 accueil élève (§3.3, amendement eleve-sans-prof), 0158 (§3 bandeau), 0173 §3, XXXX-activation-premier-exercice
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

      # UDR-0173 §3 : plus d'« Exercice du jour » ; la carte de la classe, la grille, les annonces. UDR-XXXX-activation-premier-exercice
      # §2 : tant que l'élève n'a réussi aucun exercice, la carte de son premier exercice ; l'exercice qu'elle propose sort de « À faire ».
      @first_exercise = Queries::Classroom::ActivationQuery.new.call(student_id: current_actor.user_id, home: @home)
      @to_do = @home.assigned_exercises.reject { it.public_id == @first_exercise&.exercise_public_id }
      @announcements = announcements
    end

    private

    # UDR-XXXX-activation-premier-exercice §2 : la copie en cours que la carte « Ton premier exercice » reprend n'y est pas une
    # seconde fois (une porte par action).
    def render_history
      on_card = Queries::Classroom::ActivationQuery.new.resume_session_public_id(student_id: current_actor.user_id)
      sessions = query.recent_sessions(student_id: current_actor.user_id).reject { it.public_id == on_card }
      completed = sessions.first(3).select { it.status == "completed" }
      render partial: "history", locals: { sessions:, paused_exercise_ids: paused_exercise_ids(completed) }
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

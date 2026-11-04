# 🌐 DELIVERY · Catalog::PrepareSheetsController
# Rôle : une feuille « Prépare interros » ou « Prépare devoirs » de la leçon : son sujet en lecture (show), puis la feuille à remplir (fill) ; mêmes refus que la leçon
# ADR  : 0121, 0028, 0035 · UDR : feuilles-en-cases-lues-avant-de-commencer §3, 0149 §3, XXXX refaire-ou-continuer §3 · :redo (fill) = l'exercice à refaire, vérifié parmi ceux de la feuille ; :sheet = l'ancre de la feuille (notion-<slug>, toute-la-lecon, sujet-<n>)
module Catalog
  class PrepareSheetsController < AuthenticatedController
    include ReadsOwnLevel

    # Le sujet complet, champs désactivés ; pour l'enseignant, ses bascules d'envoi et le bandeau (comme sur la leçon).
    def show
      open_sheet { render :show }
    end

    # La feuille d'aujourd'hui, pour l'élève ; l'enseignant et l'équipe ne remplissent pas : ils lisent.
    def fill
      open_sheet do
        next redirect_to course_sheet_path(params[:course_slug], params[:sheet]) unless fillable?

        @redo = redo_of(@sheet)
        render :fill
      end
    end

    private

    helper_method :sheet_mode

    # Mêmes refus que Catalog::CoursesController#show : leçon inconnue ou hors niveau (404), non publiée (404 hors équipe).
    def open_sheet(&)
      @detail = Queries::Catalog::CourseDetailQuery.new.call(slug: params[:course_slug], actor: current_actor)
      return render_not_found if @detail.nil?
      return if refuse_out_of_level(course_slug: params[:course_slug])

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: @detail.course),
                    success: ->(_) { load_sheet(&) }
    end

    # Une feuille retirée ou une ancre inconnue : la leçon, avec son message, jamais une erreur.
    def load_sheet
      @prepare = Queries::Catalog::PrepareSheetsQuery.new.call(course_slug: params[:course_slug], actor: current_actor)
      @sheet = @prepare.sheet(params[:sheet])
      return redirect_to course_path(params[:course_slug]), alert: t("catalog.courses.sheets.gone"), status: :see_other if @sheet.nil?

      yield
    end

    # refaire-ou-continuer (UDR §3) : l'exercice à remettre à blanc, seulement s'il est de la feuille ; toute autre valeur est ignorée.
    def redo_of(sheet)
      requested = params[:redo]
      requested if requested.is_a?(String) && sheet.exercises.any? { it.public_id == requested }
    end

    # AuthenticatedController : un acteur est toujours connecté ici.
    def fillable? = sheet_mode == :student

    def sheet_mode
      if current_actor.student? then :student
      elsif current_actor.team? then :team
      else :teacher
      end
    end
  end
end

# 🌐 DELIVERY · Classroom::StudentAssignedSheetsController
# Rôle : un devoir reçu de « Ma classe » : son sujet en lecture (show), puis la feuille à remplir avec « Rendre à l'enseignant » (fill) ; élève seulement
# ADR  : 0026, 0028, 0121 (§4), 0072 · UDR : feuilles-en-cases-lues-avant-de-commencer §3, 0149 §3, XXXX refaire-ou-continuer §3 · :redo (fill) = l'exercice à refaire, du devoir seulement ; :sheet = l'ancre du devoir (devoir-<envoi>) ; jamais celui d'une autre classe
module Classroom
  class StudentAssignedSheetsController < AuthenticatedController
    allow_roles :student

    def show = open_sheet { render :show }

    def fill
      open_sheet do
        @redo = redo_of(@sheet)
        render :fill
      end
    end

    private

    # refaire-ou-continuer (UDR §3) : l'exercice à remettre à blanc, seulement s'il est du devoir ; toute autre valeur est ignorée.
    def redo_of(sheet)
      requested = params[:redo]
      requested if requested.is_a?(String) && sheet.exercises.any? { it.public_id == requested }
    end

    # Le devoir se choisit parmi ceux de l'élève connecté (sa classe principale) : inconnu ou d'une autre classe, « Ma classe » et son message.
    def open_sheet
      @sheet = Queries::Classroom::StudentAssignedSheetsQuery.new.sheet(actor: current_actor, dom_id: params[:sheet])
      return redirect_to student_classroom_path, alert: t("catalog.courses.sheets.gone"), status: :see_other if @sheet.nil?

      yield
    end
  end
end

# 🌐 DELIVERY · Classroom::StudentAssignedSheetsController
# Rôle : un devoir reçu de « Ma classe » : son sujet en lecture (show), puis la feuille à remplir avec « Rendre à l'enseignant » (fill) ; élève seulement
# ADR  : 0026, 0028, 0121 (§4), 0072 · UDR : feuilles-en-cases-lues-avant-de-commencer §3, 0149 §3 · :sheet = l'ancre du devoir (devoir-<envoi>) ; jamais celui d'une autre classe
module Classroom
  class StudentAssignedSheetsController < AuthenticatedController
    allow_roles :student

    def show = open_sheet { render :show }

    def fill = open_sheet { render :fill }

    private

    # Le devoir se choisit parmi ceux de l'élève connecté (sa classe principale) : inconnu ou d'une autre classe, « Ma classe » et son message.
    def open_sheet
      @sheet = Queries::Classroom::StudentAssignedSheetsQuery.new.sheet(actor: current_actor, dom_id: params[:sheet])
      return redirect_to student_classroom_path, alert: t("catalog.courses.sheets.gone"), status: :see_other if @sheet.nil?

      yield
    end
  end
end

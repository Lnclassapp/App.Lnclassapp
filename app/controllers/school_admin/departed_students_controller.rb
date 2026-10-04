# 🌐 DELIVERY · SchoolAdmin::DepartedStudentsController
# Rôle : « Anciens élèves » de la direction, page sœur de « Travail des élèves » : leurs résultats obtenus dans l'établissement
# ADR  : 0036, 0065 · UDR : 0052, 0054 (§3.9) · l'établissement est celui du compte ; `q` cherche un nom, le frame seul revient
module SchoolAdmin
  class DepartedStudentsController < BaseController
    LIST_FRAME = "departed_students_list".freeze

    def index
      @search = params[:q].to_s.squish
      @overview = Queries::School::DepartedStudentsQuery.new.call(school_id: current_actor.school_id, search: @search)
    end
  end
end

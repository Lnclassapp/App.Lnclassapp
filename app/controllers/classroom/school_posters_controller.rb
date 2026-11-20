# 🌐 DELIVERY · Classroom::SchoolPostersController
# Rôle : le kit d'affiches d'un établissement : une feuille A4 par classe ouverte de l'année, page à imprimer sans navigation
# ADR  : partage-classe-k-factor · UDR : partage-de-classe (§3.2) · PrintSchoolPostersPolicy (autre établissement : 404, élève : 403)
module Classroom
  class SchoolPostersController < AuthenticatedController
    allow_roles :teacher, :school_admin, :team

    def show
      school = find_school
      return render_not_found if school.nil?

      render_result Policies::Classroom::PrintSchoolPostersPolicy.new.call(actor: current_actor, school:), success: lambda { |_|
        @school = school
        @posters = Queries::Classroom::PosterQuery.new.for_school(school_id: school.id)
        render layout: "print"
      }
    end

    private

    # Sans school_public_id (route de la direction), l'établissement est celui du compte connecté.
    def find_school
      schools = Repositories::School::SchoolRepository.new
      return schools.find_by_public_id(public_id: params[:school_public_id]) if params[:school_public_id]

      current_actor.school_id && schools.find_by_id(id: current_actor.school_id)
    end
  end
end

# 🌐 DELIVERY · Teams::ClassroomGenerationsController
# Rôle : l'équipe lance la génération des classes manquantes depuis l'écran Établissements, puis suit son rapport
# ADR  : 0026, 0028, 0056 · UDR : 0043
module Teams
  class ClassroomGenerationsController < BaseController
    # Succès : le rapport de la génération, rechargé tant qu'elle tourne ; déjà en cours : retour aux établissements.
    def create
      result = start.call(actor: current_actor)
      return redirect_to(schools_path, alert: t(".already_running"), status: :see_other) if result.code == :conflict

      render_result result, success: lambda { |report|
        redirect_to teams_import_path(report.public_id), notice: t(".started"), status: :see_other
      }
    end

    private

    def start
      UseCases::Classroom::StartClassroomGeneration.new(
        reports: Repositories::Catalog::ImportReportRepository.new, queue: Repositories::Catalog::ImportQueue.new,
        policy: Policies::School::ManageSchoolPolicy.new, clock: Time.zone
      )
    end
  end
end

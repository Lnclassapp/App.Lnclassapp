# 🌐 DELIVERY · Teams::ClassroomGenerationsController
# Rôle : l'équipe lance la génération des classes manquantes depuis l'écran Établissements, puis suit son rapport
# ADR  : 0026, 0028, 0056 · UDR : 0043
module Teams
  class ClassroomGenerationsController < BaseController
    # Succès : le rapport de la génération, rechargé tant qu'elle tourne. Déjà en cours : état attendu, pas une erreur ;
    # toast d'information et rapport de celle qui tourne.
    def create
      result = start.call(actor: current_actor)
      return redirect_to_running if result.code == :conflict

      render_result result, success: lambda { |report|
        redirect_to teams_import_path(report.public_id), notice: t(".started"), status: :see_other
      }
    end

    private

    # Une seule génération en cours par type (index partiel) : aucune ne peut naître après elle, c'est la plus récente.
    def redirect_to_running
      running = Queries::Catalog::ImportReportsQuery.new.call(kind: Entities::Catalog::ImportKind::CLASSROOM_GENERATION, limit: 1).first
      redirect_to teams_import_path(running.public_id), status: :see_other,
                                                        flash: { info: { "title" => t(".already_running_title"), "message" => t(".already_running") } }
    end

    def start
      UseCases::Classroom::StartClassroomGeneration.new(
        reports: Repositories::Catalog::ImportReportRepository.new, queue: Repositories::Catalog::ImportQueue.new,
        policy: Policies::School::ManageSchoolPolicy.new, clock: Time.zone
      )
    end
  end
end

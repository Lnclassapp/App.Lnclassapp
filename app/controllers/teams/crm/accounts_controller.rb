# 🌐 DELIVERY · Teams::Crm::AccountsController
# Rôle : coquille du bloc « Suivi » d'une fiche établissement : le frame `school_crm` et ses six sous-blocs paresseux
# ADR  : XXXX (contexte crm) · UDR : XXXX (bloc « Suivi » de la fiche établissement)
module Teams
  module Crm
    class AccountsController < BaseController
      def show
        @school = Queries::School::SchoolsQuery.new.find(public_id: params[:school_public_id])
        render_not_found if @school.nil?
      end
    end
  end
end

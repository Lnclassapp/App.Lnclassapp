# 🌐 DELIVERY · Teams::Crm::UsagesController
# Rôle : sous-bloc « Usage » de la fiche (frame school_crm_usage) : comptes rattachés, élèves actifs sur 14 jours, dernière activité
# ADR  : XXXX (contexte crm) · UDR : XXXX (bloc « Suivi » de la fiche établissement)
module Teams
  module Crm
    class UsagesController < BaseController
      def show
        @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
        return render_not_found if @school.nil?

        @usage = Queries::Crm::SchoolUsageQuery.new.call(school_ids: [ @school.id ]).fetch(@school.id)
      end
    end
  end
end

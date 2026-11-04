# 🔌 INFRA · Queries::Crm::FollowUpsQuery
# Rôle : relances ouvertes et responsable d'une école (lecture) : d'une école, « Mes relances » (échues d'abord), « Sans destinataire » ; 25 par page, requêtes constantes
# ADR  : XXXX (contexte crm) · UDR : XXXX (pipeline et relances)
module Queries
  module Crm
    class FollowUpsQuery
      PER_PAGE = 25
      Row = Data.define(:public_id, :school_id, :school_public_id, :school_name, :drena_name, :assignee_public_id, :assignee_name,
                        :assignee_available, :due_on, :reason, :owner_id)
      Page = Data.define(:rows, :total_count, :page, :pages)

      AVAILABLE = Orm::CrmFollowUp.sanitize_sql_array(
        [ "(users.anonymized_at IS NULL AND users.role = 'team' AND users.team_role IN (?))", Policies::Crm::ManageCrmPolicy::TEAM_ROLES ]
      ).freeze
      COLUMNS = [ "crm_follow_ups.public_id", "crm_follow_ups.school_id", "schools.public_id", "schools.name", "drenas.name",
                  "users.public_id", "users.first_name", "users.last_name", Arel.sql(AVAILABLE), "crm_follow_ups.due_on",
                  "crm_follow_ups.reason", "crm_accounts.owner_id" ].freeze

      # → [Row], par échéance
      def for_school(school_id:)
        pluck(base.where(school_id:).order(:due_on, :id))
      end

      # → Page : mes relances ouvertes, les échues d'abord (donc par échéance croissante)
      def mine(user_id:, page: 1)
        paginate(base.where(assignee_id: user_id), page)
      end

      # → Page : relances ouvertes dont le destinataire est anonymisé ou n'est plus admin ni field
      def orphans(page: 1)
        paginate(base.where("NOT #{AVAILABLE}"), page)
      end

      # → Row | nil : une relance ouverte
      def find(public_id:)
        pluck(joined(Orm::CrmFollowUp.open.where(public_id:))).first
      end

      # → Integer | nil : le responsable de l'école (aucune ligne de compte = aucun responsable)
      def owner_id(school_id:)
        Orm::CrmAccount.where(school_id:).pick(:owner_id)
      end

      private

      def base = joined(Orm::CrmFollowUp.open).order(:due_on, :id)

      def joined(scope)
        scope.joins(:assignee, school: :drena)
             .joins("LEFT JOIN crm_accounts ON crm_accounts.school_id = crm_follow_ups.school_id")
      end

      def paginate(scope, page)
        total_count = scope.count
        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages) # to_s : page[]=2 donne un tableau
        Page.new(rows: pluck(scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE)), total_count:, page:, pages:)
      end

      def pluck(scope)
        scope.pluck(*COLUMNS).map do |public_id, school_id, school_public_id, school_name, drena_name, assignee_public_id, first, last,
                                      available, due_on, reason, owner_id|
          Row.new(public_id:, school_id:, school_public_id:, school_name:, drena_name:, assignee_public_id:,
                  assignee_name: [ first, last ].compact_blank.join(" "), assignee_available: available, due_on:, reason:, owner_id:)
        end
      end
    end
  end
end

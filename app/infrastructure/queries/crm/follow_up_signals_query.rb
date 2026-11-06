# 🔌 INFRA · Queries::Crm::FollowUpSignalsQuery
# Rôle : écoles à relancer et leurs raisons (lecture) : les miennes, ou toute l'équipe ; l'usage vient de SchoolUsageQuery, 25 par page
# ADR  : XXXX (contexte crm) §4 · UDR : XXXX (pipeline et relances) · requêtes constantes : sept, quel que soit le nombre d'écoles
module Queries
  module Crm
    class FollowUpSignalsQuery
      PER_PAGE = 25
      Row = Data.define(:school_id, :school_public_id, :school_name, :drena_name, :owner_name, :reasons)
      Page = Data.define(:rows, :total_count, :page, :pages)

      # Les écoles qui ont un suivi, un rattachement ou une classe : les seules où un signal peut naître.
      CANDIDATES = <<~SQL.squish.freeze
        SELECT school_id FROM crm_accounts UNION SELECT school_id FROM crm_follow_ups WHERE status = 'open'
        UNION SELECT school_id FROM teacher_schools UNION SELECT school_id FROM school_staffs UNION SELECT school_id FROM classrooms
      SQL

      # → Page : les écoles dont je suis responsable, ou dont une relance échue m'est confiée, avec au moins un signal
      def mine(user_id:, page: 1, today: Date.current)
        owned = Orm::CrmAccount.where(owner_id: user_id).pluck(:school_id)
        mine = Orm::CrmFollowUp.open.where(assignee_id: user_id).where(due_on: ..today).pluck(:school_id)
        paginate(owned | mine, page, today)
      end

      # → Page : toute l'équipe, avec au moins un signal
      def all(page: 1, today: Date.current)
        paginate(Orm::School.connection.select_values(CANDIDATES), page, today)
      end

      private

      def paginate(school_ids, page, today)
        rows = rows_for(school_ids, today)
        pages = [ rows.size.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages) # to_s : page[]=2 donne un tableau
        Page.new(rows: rows.slice((page - 1) * PER_PAGE, PER_PAGE) || [], total_count: rows.size, page:, pages:)
      end

      def rows_for(school_ids, today)
        schools = Orm::School.where(id: school_ids.uniq).where.not(status: "inactive").includes(:drena).to_a
        ids = schools.map(&:id)
        return [] if ids.empty?

        accounts = Orm::CrmAccount.where(school_id: ids).includes(:owner).index_by(&:school_id)
        overdue = Orm::CrmFollowUp.open.where(school_id: ids, due_on: ..today).distinct.pluck(:school_id)
        interactions = Orm::CrmInteraction.where(school_id: ids).group(:school_id).maximum(:occurred_at)
        usages = SchoolUsageQuery.new.call(school_ids: ids, today:)

        schools.filter_map { |school| row(school, accounts[school.id], usages.fetch(school.id), overdue.include?(school.id), interactions[school.id], today) }
               .sort_by { [ -it.reasons.size, it.school_name ] }
      end

      def row(school, account, usage, overdue, last_interaction, today)
        reasons = Entities::Crm::FollowUpSignals.reasons(
          stage: usage.stage(saved: account&.stage, today:), last_activity_on: usage.last_activity_on, first_attached_on: usage.first_attached_on,
          last_interaction_on: last_interaction&.in_time_zone&.to_date, overdue:, deactivated: false, today:
        )
        return if reasons.empty?

        owner = account&.owner
        Row.new(school_id: school.id, school_public_id: school.public_id, school_name: school.name, drena_name: school.drena.name,
                owner_name: owner && [ owner.first_name, owner.last_name ].compact_blank.join(" "), reasons:)
      end
    end
  end
end

# 🔌 INFRA · Queries::School::SchoolsQuery
# Rôle : liste nationale des établissements (SC-04) : filtres DRENA, type, cycle, statut, nom ou sigle (IE-21), 50 par page ; pipeline : étape affichée et responsable (CA-21)
# ADR  : 0026, 0030, 0057, 0063, 0083, 0088, 0096, XXXX (contexte crm) · UDR : 0036, 0044, 0050, 0079, 0106, XXXX (pipeline et relances) · filtres : Orm::School.list_filtered
module Queries
  module School
    class SchoolsQuery
      PER_PAGE = 50
      Row = Data.define(:public_id, :name, :sigle, :drena_public_id, :drena_name, :school_type, :cycle, :status,
                        :classrooms_count, :teachers_count, :school_code, :national_code, :team_invite_token,
                        :school_code_rotated_at)
      # crm : { public_id d'école => CrmCell }, vide sans `with_crm` (la liste d'avant, pour l'équipe `content`).
      Page = Data.define(:rows, :total_count, :page, :pages, :crm)
      CrmCell = Data.define(:stage, :owner_name)
      NO_OWNER = "none".freeze
      # La recherche vit dans le scope partagé (ADR-0096 §4.5) ; ces noms restent lus par la recherche de comptes.
      ACCENTED = Orm::School::ACCENTED
      PLAIN = Orm::School::PLAIN
      SEARCHED = Orm::School::SEARCHED

      # stage : une étape affichée (Entities::Crm::Stage::DISPLAYED), calculée à la lecture, jamais stockée (ADR contexte crm).
      # owner : le public_id d'un membre, ou "none" pour « sans responsable ». Une valeur inconnue de stage est ignorée.
      # Requêtes constantes : l'usage de toutes les écoles filtrées (avec stage), sinon celui de la page seulement (CA-21).
      def call(drena: nil, school_type: nil, cycle: nil, status: nil, search: nil, stage: nil, owner: nil, with_crm: false,
               page: 1, school_year: current_school_year, today: Date.current)
        scope = Orm::School.list_filtered(drena:, school_type:, cycle:, status:, search:)
        scope = scope.where(id: owned_by(owner)) if owner.present?
        usages = nil
        if stage_filter?(stage)
          usages = usage_of(scope.pluck(:id), today)
          scope = scope.where(id: matching_ids(usages, stage, today))
        end
        total_count = scope.count
        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages) # to_s : page[]=2 ou page[a]=1 donnent un tableau ou un hash
        rows = scope.order(:name, :id).offset((page - 1) * PER_PAGE).limit(PER_PAGE).pluck(*columns(school_year))
        rows = rows.map { |values| Row.new(*values) }
        crm = with_crm || stage_filter?(stage) || owner.present? ? crm_cells(rows, usages, today) : {}
        Page.new(rows:, total_count:, page:, pages:, crm:)
      end

      # → Row | nil
      def find(public_id:, school_year: current_school_year)
        values = Orm::School.joins(:drena).where(public_id:).pick(*columns(school_year))
        values && Row.new(*values)
      end

      # → { public_id => CrmCell } : étape et responsable de lignes déjà lues (une ligne re-rendue après une modification)
      def crm_for(rows, today: Date.current) = crm_cells(rows, nil, today)

      private

      def stage_filter?(stage) = Entities::Crm::Stage::DISPLAYED.map(&:to_s).include?(stage)

      def owned_by(owner)
        accounts = Orm::CrmAccount.all
        if owner == NO_OWNER
          Orm::School.where.not(id: accounts.where.not(owner_id: nil).select(:school_id)).select(:id)
        else
          accounts.where(owner_id: Orm::User.where(public_id: owner.to_s).select(:id)).select(:school_id)
        end
      end

      def usage_of(ids, today) = Queries::Crm::SchoolUsageQuery.new.call(school_ids: ids, today:)

      def saved_stages(ids) = Orm::CrmAccount.where(school_id: ids).pluck(:school_id, :stage).to_h

      def matching_ids(usages, stage, today)
        saved = saved_stages(usages.keys)
        usages.filter_map { |id, usage| id if usage.stage(saved: saved[id], today:).to_s == stage }
      end

      # → { public_id => CrmCell } : étape affichée et nom du responsable des écoles de la page (usage lu une fois, comptes une fois)
      def crm_cells(rows, usages, today)
        ids = Orm::School.where(public_id: rows.map(&:public_id)).pluck(:public_id, :id).to_h
        return {} if ids.empty?

        usages ||= usage_of(ids.values, today)
        accounts = Orm::CrmAccount.where(school_id: ids.values).left_joins(:owner)
                                  .pluck(:school_id, :stage, "users.first_name", "users.last_name").to_h { |id, *rest| [ id, rest ] }
        ids.to_h do |public_id, id|
          saved, first, last = accounts[id]
          [ public_id, CrmCell.new(stage: usages.fetch(id).stage(saved:, today:), owner_name: [ first, last ].compact_blank.join(" ").presence) ]
        end
      end

      def columns(school_year)
        [ "schools.public_id", "schools.name", "schools.sigle", "drenas.public_id", "drenas.name", "schools.school_type",
          "schools.cycle", "schools.status",
          Arel.sql(Orm::School.sanitize_sql_array([ "(SELECT COUNT(*) FROM classrooms WHERE classrooms.school_id = schools.id " \
                                                    "AND classrooms.school_year = ? AND classrooms.status = 'active')", school_year ])),
          Arel.sql("(SELECT COUNT(*) FROM teacher_schools WHERE teacher_schools.school_id = schools.id)"), "schools.school_code",
          "schools.national_code", "schools.team_invite_token", "schools.school_code_rotated_at" ]
      end

      def current_school_year = Entities::Classroom::SchoolYear.current(Date.current)
    end
  end
end

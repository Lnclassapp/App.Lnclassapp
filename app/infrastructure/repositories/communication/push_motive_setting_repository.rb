# 🔌 INFRA · Repositories::Communication::PushMotiveSettingRepository
# Rôle : réglages « Automatique » des motifs en base (push_motive_settings) et leur historique (push_motive_setting_changes)
# ADR  : XXXX envois de notifications (§4.1, §4.2) · adaptateur de Ports::Communication::PushMotiveSettingRepositoryPort
module Repositories
  module Communication
    class PushMotiveSettingRepository
      include Ports::Communication::PushMotiveSettingRepositoryPort

      def automatic_motives = Orm::Communication::PushMotiveSetting.where(automatic: true).pluck(:motive).to_set

      def all = Orm::Communication::PushMotiveSetting.order(:motive).map { to_entity(it) }

      # Le réglage et sa ligne d'historique entrent ensemble ou pas du tout.
      def update(motive:, automatic:, by:, at:)
        Orm::Communication::PushMotiveSetting.transaction(requires_new: true) do
          Orm::Communication::PushMotiveSetting.upsert({ motive:, automatic:, updated_by_id: by, updated_at: at }, unique_by: :motive)
          Orm::Communication::PushMotiveSettingChange.create!(motive:, automatic:, changed_by_id: by, changed_at: at)
        end
        nil
      end

      def purge_changes_before(before:) = Orm::Communication::PushMotiveSettingChange.where(changed_at: ...before).delete_all

      private

      def to_entity(row)
        Entities::Communication::PushMotiveSetting.new(motive: row.motive, automatic: row.automatic, updated_by_id: row.updated_by_id, updated_at: row.updated_at)
      end
    end
  end
end

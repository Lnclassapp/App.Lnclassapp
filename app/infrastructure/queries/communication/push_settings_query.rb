# 🔌 INFRA · Queries::Communication::PushSettingsQuery
# Rôle : ce que la page « Notifications » de l'équipe lit : les réglages des motifs, leur texte d'exemple, l'historique des 14 jours, l'état de l'interrupteur et des clés
# ADR  : XXXX envois de notifications (§4.1) · UDR : XXXX écran notifications de l'équipe (§3.2, §3.3, §3.5) · aucun nom d'élève, jamais la valeur d'une clé
module Queries
  module Communication
    class PushSettingsQuery
      WINDOW = 14.days
      KEYS = %w[VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY VAPID_SUBJECT].freeze
      # Les exemples de l'UDR §3.3 : une matière et un nombre d'exemple, rendus par le gabarit de la notification elle-même.
      SAMPLE = { material: "Maths" }.freeze
      SAMPLE_COUNTS = { "quiz_prep" => 2, "assignment_new" => 3 }.freeze

      # motive : un des sept motifs ; automatic : la case ; by_name / at : qui l'a cochée et quand (nil si jamais réglé).
      Mode = Data.define(:motive, :automatic, :by_name, :at, :example)
      # kind : :approval, :setting_on ou :setting_off ; count : élèves d'une validation (nil pour un réglage).
      Entry = Data.define(:kind, :at, :by_name, :motive, :count)
      Page = Data.define(:modes, :history, :switch_on, :configured)

      def call(now: Time.current)
        Page.new(modes: modes, history: history(now), switch_on: switch_on?, configured: configured?)
      end

      private

      def modes
        settings = Orm::Communication::PushMotiveSetting.includes(:updated_by).index_by(&:motive)
        Entities::Communication::PushMotive::PRIORITY.map do |motive|
          row = settings[motive]
          Mode.new(motive:, automatic: row&.automatic || false, by_name: (short_name(row.updated_by) if row), at: row&.updated_at, example: example(motive))
        end
      end

      def example(motive)
        variables = SAMPLE.merge(count: SAMPLE_COUNTS[motive]).compact
        variables[:kind] = "copy" if motive == "result"
        candidate = Entities::Communication::PushCandidate.new(user_id: 0, motive:, object_key: "sample", url: "/", variables:)
        Entities::Communication::PushMessage.for(candidate).body
      end

      def history(now)
        since = now - WINDOW
        approvals = Orm::Communication::PushApproval.includes(:approved_by).where(approved_at: since..).map do |row|
          Entry.new(kind: :approval, at: row.approved_at, by_name: short_name(row.approved_by), motive: row.motive, count: row.recipients_count)
        end
        changes = Orm::Communication::PushMotiveSettingChange.includes(:changed_by).where(changed_at: since..).map do |row|
          Entry.new(kind: row.automatic ? :setting_on : :setting_off, at: row.changed_at, by_name: short_name(row.changed_by), motive: row.motive, count: nil)
        end
        (approvals + changes).sort_by(&:at).reverse
      end

      # « Awa K. » : le prénom et l'initiale du nom, comme les autres écrans de l'équipe.
      def short_name(user) = "#{user.first_name} #{user.last_name.to_s[0]}."

      def switch_on? = ActiveModel::Type::Boolean.new.cast(ENV["PUSH_DELIVERY_ENABLED"]) == true

      def configured? = KEYS.all? { ENV[it].present? }
    end
  end
end

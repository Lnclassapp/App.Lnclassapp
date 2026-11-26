# 🔌 INFRA · Queries::Communication::PushDailyPlanQuery
# Rôle : le plan du jour de l'équipe : par motif à valider, élèves distincts, établissements, texte et validation du jour ; aucun nom d'élève
# ADR  : XXXX envois de notifications (§3.2, §4.4) · UDR : XXXX écran notifications de l'équipe (§3.4)
module Queries
  module Communication
    class PushDailyPlanQuery
      # schools : [[nom d'établissement, nombre d'élèves]], le plus gros d'abord ; text : le texte le plus courant, more_texts : le nombre d'autres textes.
      Entry = Data.define(:motive, :students, :text, :more_texts, :schools, :approval)
      # by_name : « Awa K. » ; count : le nombre enregistré à la validation (pas celui d'aujourd'hui).
      Approval = Data.define(:by_name, :at, :count)

      NO_SCHOOL = "—".freeze

      def initialize(candidates: PushCandidates.new, settings: Repositories::Communication::PushMotiveSettingRepository.new,
                     approvals: Repositories::Communication::PushApprovalRepository.new)
        @candidates = candidates
        @settings = settings
        @approvals = approvals
      end

      # → [Entry] : un par motif non automatique (l'annonce se décide à la publication), dans l'ordre de priorité ; students 0 = aucun élève.
      # Abidjan est à UTC+0 : la date UTC est la date d'Abidjan.
      def call(now:)
        motives = Entities::Communication::PushMotive::PLANNABLE - @settings.automatic_motives.to_a
        pending = pending(now, motives)
        approvals = approvals(now.utc.to_date)
        schools = schools_by_student(pending.values.flatten.map(&:user_id).uniq)
        motives.map { entry(it, pending.fetch(it, []), schools, approvals[it]) }
      end

      private

      # { motif => [candidats non expirés, pas encore prévenus de leur objet] }
      def pending(now, motives)
        list = @candidates.for(now:).select { motives.include?(it.motive) && !it.expired?(now) }
        sent = sent_keys(list)
        list.reject { sent.include?([ it.user_id, it.motive, it.object_key ]) }.group_by(&:motive)
      end

      # Les statuts définitifs seulement : un motif noté `disabled` ou `not_configured` n'est pas « brûlé » (comme PushDeliveryRepository#sent?).
      def sent_keys(list)
        return Set.new if list.empty?

        Orm::Communication::PushDelivery.where(user_id: list.map(&:user_id).uniq, motive: list.map(&:motive).uniq, status: Repositories::Communication::PushDeliveryRepository::FINAL)
                                        .pluck(:user_id, :motive, :object_key).to_set
      end

      # { motif => Approval } des validations du jour.
      def approvals(on_date)
        list = @approvals.for_date(on_date:)
        names = names(list.map(&:approved_by_id))
        list.to_h { [ it.motive, Approval.new(by_name: names[it.approved_by_id], at: it.approved_at, count: it.recipients_count) ] }
      end

      def names(user_ids)
        Orm::User.where(id: user_ids).pluck(:id, :first_name, :last_name).to_h { |id, first, last| [ id, "#{first} #{last.to_s.first}.".squish ] }
      end

      # { élève => nom de l'établissement de sa classe principale }
      def schools_by_student(student_ids)
        return {} if student_ids.empty?

        Orm::ClassroomStudent.joins(classroom: :school).where(student_id: student_ids, primary: true, left_at: nil)
                             .pluck(:student_id, "schools.name").to_h
      end

      def entry(motive, candidates, schools, approval)
        students = candidates.map(&:user_id).uniq
        texts = candidates.map { Entities::Communication::PushMessage.for(it).body }.tally.sort_by { |text, count| [ -count, text ] }.map(&:first)
        Entry.new(motive:, students: students.size, text: texts.first, more_texts: [ texts.size - 1, 0 ].max,
                  schools: students.map { schools.fetch(it, NO_SCHOOL) }.tally.sort_by { |name, count| [ -count, name ] }, approval:)
      end
    end
  end
end

# 🔌 INFRA · Repositories::Billing::RelayPointRepository
# Rôle : traduit Orm::Billing::RelayPoint (et ses écoles) en entités ; lectures de l'écran : écoles à cocher, lots, école d'un élève
# ADR  : cartes-activation (contexte billing, §4.1), 0029
module Repositories
  module Billing
    class RelayPointRepository
      include Ports::Billing::RelayPointRepositoryPort

      def list
        Orm::Billing::RelayPoint.includes(:relay_point_schools).order(:name, :id).map { map(it) }
      end

      def find(public_id:)
        record = Orm::Billing::RelayPoint.includes(:relay_point_schools).find_by(public_id:)
        record && map(record)
      end

      def save(relay_point:, school_ids:)
        record = relay_point.id ? Orm::Billing::RelayPoint.find(relay_point.id) : Orm::Billing::RelayPoint.new
        Orm::Billing::RelayPoint.transaction(requires_new: true) do
          record.update!(name: relay_point.name, location: relay_point.location, phone: relay_point.phone, active: relay_point.active)
          replace_schools(record, school_ids)
        end
        ::Shared::Result.success(map(record.reload))
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::InvalidForeignKey, ActiveRecord::ValueTooLong
        ::Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
      end

      def for_school(school_id:)
        Orm::Billing::RelayPoint.joins(:relay_point_schools).where(active: true, relay_point_schools: { school_id: })
                                .includes(:relay_point_schools).order(:name, :id).map { map(it) }
      end

      # Lecture de l'écran, hors port : les lots d'un point relais, du plus récent au plus ancien (sans leurs cartes).
      # → [Entities::Billing::CardBatch]
      def batches_of(relay_point_id:)
        Orm::Billing::CardBatch.where(relay_point_id:).order(created_at: :desc, id: :desc).map do |batch|
          Entities::Billing::CardBatch.new(id: batch.id, public_id: batch.public_id, relay_point_id:, quantity: batch.quantity,
                                           unit_price_xof: batch.unit_price_xof, valid_until: batch.valid_until,
                                           created_by_id: batch.created_by_id, created_at: batch.created_at)
        end
      end

      # Lecture de l'écran, hors port : les écoles actives à cocher, [[« Nom (DRENA) », id]], par nom.
      def school_choices
        Orm::School.joins(:drena).where(status: "active").order("schools.name", "schools.id")
                   .pluck("schools.name", "drenas.name", "schools.id").map { |name, drena, id| [ "#{name} (#{drena})", id ] }
      end

      # Lecture de l'écran, hors port : { id => nom } des écoles données.
      def school_names(school_ids:) = Orm::School.where(id: school_ids).order(:name).pluck(:id, :name).to_h

      # Hors port : l'école de la classe principale active de l'élève à cet instant, ou nil (ADR §4.3).
      def school_id_of_student(student_id:)
        Orm::ClassroomStudent.joins(:classroom).where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                             .pick("classrooms.school_id")
      end

      private

      def replace_schools(record, school_ids)
        wanted = Orm::School.where(id: school_ids).pluck(:id)
        record.relay_point_schools.where.not(school_id: wanted).delete_all
        (wanted - record.relay_point_schools.pluck(:school_id)).each { record.relay_point_schools.create!(school_id: it) }
      end

      def map(record)
        Entities::Billing::RelayPoint.new(id: record.id, public_id: record.public_id, name: record.name, location: record.location,
                                          phone: record.phone, active: record.active, school_ids: record.relay_point_schools.map(&:school_id).sort)
      end
    end
  end
end

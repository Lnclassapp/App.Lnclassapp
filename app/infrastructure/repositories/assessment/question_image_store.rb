# 🔌 INFRA · Repositories::Assessment::QuestionImageStore
# Rôle : images de question en lignes question_images et fichiers sur le service Active Storage (bucket) : envoyer, servir, purger
# ADR  : 0047, 0060, 0105
module Repositories
  module Assessment
    class QuestionImageStore
      include Ports::Assessment::QuestionImageStorePort

      EXTENSIONS = { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp" }.freeze

      def store(data:, content_type:, width:, height:)
        image = Orm::QuestionImage.create!(content_type:, byte_size: data.bytesize, width:, height:,
                                           file: { io: StringIO.new(data), filename: "image.#{EXTENSIONS.fetch(content_type)}",
                                                   content_type:, identify: false, metadata: { analyzed: true } })
        StoredImage.new(public_id: image.public_id, width:, height:)
      end

      # L'exercice se lit dans la même requête que la ligne ; le fichier, jamais.
      def find(public_id:)
        image = Orm::QuestionImage.left_joins(question: :exercise)
                                  .select("question_images.content_type", "exercises.public_id AS exercise_public_id")
                                  .find_by(public_id:)
        image && ImageState.new(content_type: image.content_type, exercise_public_id: image.exercise_public_id)
      end

      def download(public_id:)
        ActiveStorage::Blob.joins(:attachments)
                           .find_by(active_storage_attachments: { name: "file", record_type: Orm::QuestionImage.name,
                                                                  record_id: Orm::QuestionImage.where(public_id:).select(:id) })
                           &.download
      rescue ActiveStorage::FileNotFoundError
        # La ligne du blob existe, pas son fichier (bucket vidé) : comme une ligne sans blob, le contrôleur répond 404 et le journalise.
        nil
      end

      # Chaque image est verrouillée (SKIP LOCKED : une image en cours de rattachement est laissée) puis relue sans question_id avant
      # destroy! : une image rattachée entre la lecture et la purge ne perd pas son fichier (menace.md, n° 11).
      def purge_orphans(before:)
        orphan_ids(before:).count do |id|
          Orm::QuestionImage.transaction do
            image = Orm::QuestionImage.lock("FOR UPDATE SKIP LOCKED").find_by(id:, question_id: nil)
            image&.destroy!
          end
        end
      end

      private

      def orphan_ids(before:) = Orm::QuestionImage.where(question_id: nil, created_at: ...before).ids
    end
  end
end

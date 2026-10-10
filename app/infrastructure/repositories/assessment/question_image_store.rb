# 🔌 INFRA · Repositories::Assessment::QuestionImageStore
# Rôle : images de question en lignes question_images et fichiers sur le service Active Storage (bucket) : envoyer, servir, purger
# ADR  : 0047, 0060, 0089
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
      end

      def purge_orphans(before:)
        Orm::QuestionImage.where(question_id: nil, created_at: ...before).each(&:destroy!).size
      end
    end
  end
end

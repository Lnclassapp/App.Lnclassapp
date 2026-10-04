# 🔌 INFRA · Repositories::Communication::AttachmentStore
# Rôle : image et audio d'une annonce en pièces jointes, sur le service Active Storage (bucket) ; lecture par plage d'octets
# ADR  : 0045, 0047, 0078
module Repositories
  module Communication
    class AttachmentStore
      include Ports::Communication::AttachmentStorePort

      # Liste blanche : le kind choisit une association, jamais une méthode quelconque de l'annonce.
      KINDS = { "image" => :image, "audio" => :audio }.freeze

      # Le domaine a déjà lu le format dans les octets : pas d'identification, et le blob naît analysé, sans quoi
      # AnalyzeJob chercherait libvips, absent en production. L'ancien fichier part par purge_later (remplacement).
      def attach(message_id:, kind:, io:, content_type:, filename:)
        attachment(message_id, kind).attach(io:, filename:, content_type:, identify: false, metadata: { analyzed: true })
        true
      end

      # purge, pas purge_later : le fichier disparaît du bucket avant la réponse.
      def remove(message_id:, kind:)
        file = attachment(message_id, kind)
        return false unless file.attached?

        file.purge
        true
      end

      def attached?(message_id:, kind:) = attachment(message_id, kind).attached?

      # Une plage ne télécharge que ses octets (download_chunk) : un audio de 10 Mo se lit et se reprend par morceaux.
      def read(message_id:, kind:, range: nil)
        file = attachment(message_id, kind)
        return unless file.attached?

        served = window(range, file.byte_size) if range
        data = served ? file.blob.download_chunk(served) : file.download
        StoredFile.new(content_type: file.content_type, data:, byte_size: file.byte_size, range: served)
      end

      private

      def attachment(message_id, kind)
        name = KINDS.fetch(kind.to_s) { raise ArgumentError, "pièce jointe d'annonce inconnue : #{kind.inspect}" }
        Orm::Message.find(message_id).public_send(name)
      end

      # La plage servie, incluse et bornée au fichier ; nil si elle est vide ou commence après sa fin.
      def window(range, size)
        first = range.begin.negative? ? [ size + range.begin, 0 ].max : range.begin
        last = range.end.nil? ? size - 1 : [ range.exclude_end? ? range.end - 1 : range.end, size - 1 ].min
        first..last if first <= last
      end
    end
  end
end

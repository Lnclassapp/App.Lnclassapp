# 🌐 DELIVERY · Communication::MessageFilesController
# Rôle : sert l'image ou l'audio d'une annonce après la règle de lecture, en cache privé no-store, par plage (206), ou en pièce jointe (download) ; sinon 404
# ADR  : 0047, 0078 (§4.4), annonces-audio-dix-secondes (§4.3) · UDR : 0071 (§3.2, §3.4)
module Communication
  class MessageFilesController < AuthenticatedController
    # Une seule plage d'octets : « bytes=500-999 », « bytes=500- » (jusqu'à la fin), « bytes=-500 » (les 500 derniers).
    RANGE = /\Abytes=(\d*)-(\d*)\z/
    # Le nom d'une pièce jointe vient du type enregistré, jamais de l'auteur (ADR-0045 §4, M10).
    EXTENSIONS = { "audio/mpeg" => "mp3", "audio/mp4" => "m4a", "image/png" => "png", "image/jpeg" => "jpg", "image/webp" => "webp" }.freeze

    def show
      result = read.call(actor: current_actor, public_id: params[:public_id], kind: params[:kind], range: requested_range)
      render_result result, success: ->(file) { serve(file) }
    end

    private

    # Jamais d'URL Active Storage partageable : l'application sert les octets, et aucun cache ne les garde (ADR-0078 §4.4).
    def serve(file)
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["Accept-Ranges"] = "bytes"
      response.headers["Content-Range"] = "bytes #{file.range.begin}-#{file.range.end}/#{file.byte_size}" if file.range
      send_data file.data, type: file.content_type, status: file.range ? :partial_content : :ok,
                           **(params[:download] ? { disposition: :attachment, filename: download_name(file) } : { disposition: :inline, filename: params[:kind] })
    end

    def download_name(file)
      [ "annonce-#{params[:public_id]}", EXTENSIONS[file.content_type] ].compact.join(".")
    end

    # Toute autre en-tête (absente, plusieurs plages, autre unité, suffixe nul) : le fichier entier. Une plage hors du
    # fichier est ignorée par le stockage (AttachmentStorePort#read), comme HTTP le permet.
    def requested_range
      first, last = request.headers["Range"].to_s.match(RANGE)&.captures
      return if first.nil? || (first.empty? && last.to_i.zero?)
      return (-last.to_i..) if first.empty?

      first.to_i..last.presence&.to_i
    end

    def read
      UseCases::Communication::ReadMessageFile.new(
        messages: Repositories::Communication::MessageRepository.new, readable: Queries::Communication::ReadableMessages.new,
        attachments: Repositories::Communication::AttachmentStore.new, policy: Policies::Communication::ReadFilePolicy.new,
        clock: Time.zone
      )
    end
  end
end

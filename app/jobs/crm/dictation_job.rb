# 🔌 INFRA · Crm::DictationJob
# Rôle : compte rendu dicté : envoie l'enregistrement et une consigne fixe au modèle audio, garde un brouillon sous schéma fermé (repli : la transcription) ; l'audio est purgé en fin de job
# ADR  : XXXX (modèles de langage, menace du compte rendu dicté) · UDR : XXXX (assistants du suivi) · base : Crm::GenerationJob
module Crm
  class DictationJob < GenerationJob
    MAX_TOKENS = 800
    EXTENSIONS = { "audio/webm" => "webm", "audio/ogg" => "ogg", "audio/mp4" => "mp4" }.freeze

    # Garde l'enregistrement (pièce privée de la génération, sous un nom fixe : jamais celui de l'utilisateur) puis met le job en file.
    # Faux, sans rien garder, si l'un ou l'autre échoue.
    def self.submit(public_id, upload)
      record = Orm::CrmGeneration.find_by!(public_id:)
      # `analyzed: true` : Active Storage n'analyse pas la pièce (ffprobe lirait un fichier de l'utilisateur) ; le type est celui lu par les octets.
      blob = ActiveStorage::Blob.create_and_upload!(io: upload.io, filename: "dictation.#{EXTENSIONS.fetch(upload.content_type)}",
                                                    content_type: upload.content_type, identify: false, metadata: { analyzed: true })
      record.audio.attach(blob)
      return true if perform_later(public_id) != false

      record.audio.purge
      false
    rescue StandardError => error
      Rails.logger.error("[crm.dictation] submit #{public_id} : #{error.class}")
      record.audio.purge if record
      false
    end

    private

    # Aucune donnée de l'école ne part : l'audio (voir GenerationJob) et la consigne fixe.
    def messages(_generation) = Entities::Crm::DictationPrompt.messages(today: Date.current)

    def model_name = Rails.configuration.x.language_models.model_audio

    def max_tokens = MAX_TOKENS

    def json? = true

    # Toute réponse non vide est gardée : un brouillon structuré, ou à défaut la transcription brute (CA-27).
    def content_for(text) = Entities::Crm::DictationDraft.parse(text).to_content
  end
end

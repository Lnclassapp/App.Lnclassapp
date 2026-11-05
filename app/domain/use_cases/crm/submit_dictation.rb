# 🧠 DOMAINE · UseCases::Crm::SubmitDictation
# Rôle : reçoit un enregistrement dicté : refuse sur la taille et le type réel (octets) AVANT toute génération et tout stockage, puis crée la génération et met le job en file avec la pièce
# ADR  : XXXX (modèles de langage, menace du compte rendu dicté) · UDR : XXXX (assistants du suivi) · CA-26
module UseCases
  module Crm
    class SubmitDictation
      KIND = "dictation".freeze
      MAX_BYTES = 10 * 1024 * 1024
      # Le type détecté par les octets → le type sous lequel la pièce est gardée (celui que lit Crm::GenerationJob).
      STORED_TYPES = {
        "audio/webm" => "audio/webm", "video/webm" => "audio/webm", "application/x-matroska" => "audio/webm",
        "audio/ogg" => "audio/ogg", "application/ogg" => "audio/ogg", "video/ogg" => "audio/ogg",
        "audio/mp4" => "audio/mp4", "video/mp4" => "audio/mp4", "audio/x-m4a" => "audio/mp4", "audio/m4a" => "audio/mp4"
      }.freeze

      # io : flux rembobinable ; byte_size : la taille réelle du fichier reçu ; content_type : posé par le use case (jamais celui du navigateur).
      Upload = Data.define(:io, :byte_size, :content_type)
      Submitted = Data.define(:generation)

      # schools : #find_by_public_id(public_id:) → objet avec #id | nil ; type_of : #call(io) → type MIME détecté par les octets | nil ;
      # enqueue : #call(public_id, upload) → false si la pièce ou la file refuse.
      def initialize(generations:, schools:, policy:, type_of:, enqueue:)
        @generations = generations
        @schools = schools
        @policy = policy
        @type_of = type_of
        @enqueue = enqueue
      end

      # → success(Submitted) | :forbidden | :not_found | :invalid (errors[:audio] ∈ :empty, :too_large, :unsupported_type) | :conflict
      def call(actor:, school_public_id:, audio:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        school = @schools.find_by_public_id(public_id: school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?

        problem = refusal(audio)
        return Shared::Result.failure(:invalid, errors: { audio: problem[0] }) if problem.is_a?(Array)

        start(actor, school, audio.with(content_type: problem))
      end

      private

      # → [raison] si refusé, sinon le type de la pièce gardée. Rien n'est lu au-delà de l'en-tête avant ce verdict.
      def refusal(audio)
        return [ :empty ] unless audio.byte_size.to_i.positive?
        return [ :too_large ] if audio.byte_size > MAX_BYTES

        audio.io.rewind
        detected = @type_of.call(audio.io)
        audio.io.rewind
        STORED_TYPES.fetch(detected) { [ :unsupported_type ] }
      end

      def start(actor, school, upload)
        created = @generations.create_pending(generation: Entities::Crm::Generation.new(
          public_id: nil, school_id: school.id, kind: KIND, status: "pending", requested_by_id: actor.user_id, follow_up_id: nil,
          input_fingerprint: nil, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
        ))
        # Une dictée est déjà en cours pour cette école : le nouvel enregistrement n'est ni gardé ni envoyé.
        return Shared::Result.failure(:conflict) if created.failure?

        generation = created.value
        return Shared::Result.success(Submitted.new(generation:)) if @enqueue.call(generation.public_id, upload) != false

        failed = @generations.mark_failed(public_id: generation.public_id, error_code: "provider_error", duration_ms: 0)
        Shared::Result.success(Submitted.new(generation: failed.success? ? failed.value : generation))
      end
    end
  end
end

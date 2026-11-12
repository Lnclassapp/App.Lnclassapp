# 🌐 DELIVERY · Assessment::OfflineCopySyncsController
# Rôle : reçoit les copies rendues hors ligne (JSON, 20 au plus, 256 Kio, 30 par minute) et rend, pour chacune, synced, already_synced ou rejected avec son motif
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.5 ; menace R1 à R3, R5, R7) · protection CSRF de Rails inchangée (X-CSRF-Token) · aucune note du client n'est lue
module Assessment
  class OfflineCopySyncsController < AuthenticatedController
    allow_roles :student

    MAX_COPIES = 20
    MAX_BYTES = 256.kilobytes
    FIELDS = %i[client_copy_id exercise_public_id pack_token started_at submitted_at answers].freeze
    # Le motif montré à l'appareil : le premier fait du refus, ramené aux motifs de la file (UDR hors-connexion §3.6).
    REASONS = { wrong_owner: "wrong_owner", expired: "expired", stale: "stale", paused: "paused", subscription_required: "locked", not_published: "forbidden" }.freeze

    # La taille est jugée avant que Rails lise le corps (et avant le jeton CSRF, qui le lit).
    prepend_before_action :refuse_large_body, only: :create
    rate_limit to: 30, within: 1.minute, only: :create, by: -> { current_actor.user_id },
               with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }

    def create
      copies = posted_copies
      return render json: { error: "invalid" }, status: :unprocessable_entity if copies.nil? || copies.size > MAX_COPIES

      render json: { results: copies.map { sync_isolated(it) } }
    end

    private

    def refuse_large_body
      return if [ request.content_length.to_i, request.body.size ].max <= MAX_BYTES

      render json: { error: "too_large" }, status: :content_too_large
    end

    # → [Hash] ou nil quand le corps n'est pas une liste de copies. Champ par champ : une clé de plus (score, status…) n'est jamais lue.
    def posted_copies
      raw = params[:copies]
      return unless raw.is_a?(Array) && raw.all?(ActionController::Parameters)

      raw.map { |copy| copy.to_unsafe_h.symbolize_keys.slice(*FIELDS) }
    end

    # Une exception sur une copie ne bloque pas le lot : elle est signalée, la copie est rendue rejected/error (l'appareil la retente).
    def sync_isolated(attributes)
      sync(attributes)
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { client_copy_id: attributes[:client_copy_id], exercise_public_id: attributes[:exercise_public_id] })
      { client_copy_id: attributes[:client_copy_id], status: "rejected", reason: "error" }
    end

    def sync(attributes)
      dto = Dtos::Assessment::OfflineCopyInput.new(**attributes)
      id = dto.client_copy_id
      result = sync_copy.call(actor: current_actor, dto:)
      return { client_copy_id: id, status: "rejected", reason: reason_for(result) } if result.failure?

      session = result.value.session
      { client_copy_id: id, status: (result.value.already_synced ? "already_synced" : "synced"), percent: session.score_percent,
        url: exercise_session_result_path(session.public_id) }
    end

    def reason_for(result)
      fact = result.errors.fetch(:base, []).first
      return REASONS.fetch(fact) if REASONS.key?(fact)

      { forbidden: "forbidden", not_found: "forbidden", locked: "locked" }.fetch(result.code, "invalid")
    end

    # L'empreinte que le paquet a signée : le calcul du Lot B, sur les mêmes questions que celles qu'il sert.
    def current_digest
      query = Queries::Assessment::OfflinePackQuery.new
      ->(exercise) { query.call(public_id: exercise.public_id).digest }
    end

    def sync_copy
      UseCases::Assessment::SyncOfflineCopy.new(
        signer: Repositories::Assessment::OfflinePackSigner.new, exercises: Repositories::Assessment::ExerciseRepository.new,
        sessions: Repositories::Assessment::ExerciseSessionRepository.new, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
        badges: Repositories::Assessment::BadgeRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        assignments: Repositories::Classroom::AssignmentRepository.new,
        policy: Policies::Assessment::StartSessionPolicy.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone, access: Queries::Billing::StudentAccessQuery.new,
        current_digest: current_digest
      )
    end
  end
end

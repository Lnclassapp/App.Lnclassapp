# 🧠 DOMAINE · UseCases::Identity::ChangeOwnPhoto
# Rôle : chacun ajoute ou remplace sa photo de profil, petite image vérifiée et sans métadonnées ; chaque changement est tracé
# ADR  : 0026, 0028, 0060
module UseCases
  module Identity
    class ChangeOwnPhoto
      def initialize(photos:, audit_log:, transaction:, policy:, clock:)
        @photos = photos
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # user : Entities::Identity::User, le compte de l'acteur ; dto : Dtos::Identity::ProfilePhotoInput.
      # → success | :forbidden | :invalid (erreurs du DTO)
      def call(actor:, user:, dto:, ip:)
        allowed = @policy.call(actor:, target: user)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call { store(user, dto, ip) }
      end

      private

      # L'audit ne garde que la forme de l'image, jamais ses octets.
      def store(user, dto, ip)
        replaced = @photos.attached?(user_id: user.id)
        @photos.attach(user_id: user.id, data: dto.data, content_type: dto.content_type)
        metadata = { content_type: dto.content_type, byte_size: dto.byte_size, width: dto.width, height: dto.height, replaced: }
        @audit_log.record(action: "profile.photo_changed", actor_id: user.id, at: @clock.now, subject_type: "User",
                          subject_id: user.id, metadata:, ip:)
        Shared::Result.success
      end
    end
  end
end

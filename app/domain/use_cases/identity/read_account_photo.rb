# 🧠 DOMAINE · UseCases::Identity::ReadAccountPhoto
# Rôle : lire la photo d'un compte sous la règle de lecture d'un compte : soi, l'équipe, l'enseignant pour un élève qu'il enseigne
# ADR  : 0028, 0060
module UseCases
  module Identity
    class ReadAccountPhoto
      def initialize(users:, memberships:, teachings:, photos:, policy:)
        @users = users
        @memberships = memberships
        @teachings = teachings
        @photos = photos
        @policy = policy
      end

      # → success(Ports::Identity::ProfilePhotoStorePort::StoredPhoto) | :forbidden | :not_found (compte inconnu ou sans photo)
      def call(actor:, target_public_id:)
        target = @users.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil?

        allowed = @policy.call(actor:, target:, teaches_target: teaches?(actor, target))
        return allowed if allowed.failure?

        photo = @photos.read(user_id: target.id)
        photo ? Shared::Result.success(photo) : Shared::Result.failure(:not_found)
      end

      private

      # Fait de la policy : la classe principale de l'élève, active ou archivée (comme la liste nominative), est déclarée
      # par l'enseignant.
      def teaches?(actor, target)
        return false unless actor&.teacher? && target.student?

        membership = @memberships.primary_for(student_id: target.id)
        return false if membership.nil?

        @teachings.classroom_ids_for(teacher_id: actor.user_id).include?(membership.classroom_id)
      end
    end
  end
end

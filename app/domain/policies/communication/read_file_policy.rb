# 🧠 DOMAINE · Policies::Communication::ReadFilePolicy
# Rôle : servir l'image ou l'audio d'une annonce à ses lecteurs, à son auteur, et à l'équipe ou la direction qui peut la retirer
# ADR  : 0028, 0078 (§4.4) · audit B-032 : les fichiers suivent les droits de l'annonce
module Policies
  module Communication
    class ReadFilePolicy
      LIVE = %w[scheduled published].freeze

      # readable : la règle de lecture (ReadableMessagesPort) pour cet acteur ; author_role : le rôle du compte auteur.
      # Un refus est not_found : pour qui n'a pas le droit, le fichier n'existe pas (ADR-0078 §4.4).
      def call(actor:, message:, readable:, author_role:)
        return Shared::Result.failure(:not_found) if actor.nil?
        return Shared::Result.success if readable || message.author_id == actor.user_id
        # Qui modère (l'équipe, une annonce d'un autre auteur ; la direction, celle d'un enseignant de son école), sur ce que
        # sa liste montre : programmée ou publiée (ADR-0078 §6) ; ni brouillon, ni archivée ou retirée (AN-19, audit B-032).
        return Shared::Result.success if message.moderatable_by?(actor, author_role:) && LIVE.include?(message.status)

        Shared::Result.failure(:not_found)
      end
    end
  end
end

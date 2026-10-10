# 🧠 DOMAINE · Dtos::Shared::ContentImageInput
# Rôle : l'image d'une fiche ou d'une question envoyée : la vérification de l'image d'article, aux plafonds d'un contenu (300 Ko, 1200 px)
# ADR  : 0060, 0074, 0089 · UDR : 0084
module Dtos
  module Shared
    # Même lecture des octets, même refus des formats animés ou vectoriels, mêmes métadonnées retirées : seuls les plafonds changent.
    class ContentImageInput < Dtos::Communication::ArticleImageInput
      IMAGE = Entities::Shared::ContentImage

      private

      def heavy_limit = IMAGE::MAX_KILOBYTES
    end
  end
end

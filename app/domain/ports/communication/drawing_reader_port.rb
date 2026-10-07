# 🧠 DOMAINE · Ports::Communication::DrawingReaderPort
# Rôle : contrat de la lecture d'un dessin SVG de l'équipe en formes reconstruites, ou de la raison de son refus
# ADR  : 0081 (§4.3, §6) · UDR : 0075
module Ports
  module Communication
    # Un SVG envoyé n'est jamais gardé ni rendu tel quel : seules les formes de Entities::Communication::Illustration
    # (ELEMENTS, ATTRIBUTES, PATTERNS) en sortent, au format de Illustration.valid_shape?.
    module DrawingReaderPort
      # bytes : String, les octets du fichier, MAX_BYTES au plus, déjà vérifiés.
      # → Shared::Result.success({ view_box:, shapes: })
      #   | Shared::Result.failure(:invalid, errors: { file: [ :unsafe | :not_svg | :empty ] })
      # Shared::Result n'admet que ses codes (ERROR_CODES) : la raison nommée de l'ADR-0081 §6 est la clé d'erreur du
      # fichier, que Dtos::Communication::IllustrationInput traduit sous « Dessin ».
      def read(bytes:)
        raise NotImplementedError, "#{self.class} doit implémenter #read"
      end
    end
  end
end

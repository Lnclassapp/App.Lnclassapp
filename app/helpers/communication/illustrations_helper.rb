# 🌐 UI · Communication::IllustrationsHelper — bibliothèque fermée des illustrations d'annonce
# Rôle : rend l'illustration d'une clé, SVG en ligne décoratif aux couleurs des tokens ; une clé inconnue lève ArgumentError
# ADR  : 0078 · UDR : 0005, 0071
module Communication
  module IllustrationsHelper
    # key : une clé de Entities::Communication::Message::ILLUSTRATIONS (chaîne ou symbole) ; class: celle du <svg>.
    def announcement_illustration(key, class: nil)
      name = key.to_s
      unless Entities::Communication::Message::ILLUSTRATIONS.include?(name)
        raise ArgumentError, "announcement_illustration : « #{key} » inconnue (#{Entities::Communication::Message::ILLUSTRATIONS.join(', ')})"
      end

      render "communication/messages/illustrations/#{name}", classes: binding.local_variable_get(:class)
    end
  end
end

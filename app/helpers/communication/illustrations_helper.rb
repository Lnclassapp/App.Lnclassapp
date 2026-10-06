# 🌐 UI · Communication::IllustrationsHelper — illustrations d'annonce : les 8 de base, et celles de l'équipe reconstruites
# Rôle : rend une clé de base (SVG aux tokens ; inconnue : ArgumentError) ou un dessin de l'équipe, d'une seule couleur
# ADR  : 0078, 0081 · UDR : 0005, 0071, 0075
module Communication
  module IllustrationsHelper
    TEAM_ILLUSTRATION = Entities::Communication::Illustration

    # ref : une clé de Entities::Communication::Message::ILLUSTRATIONS (chaîne ou symbole), ou une
    # Entities::Communication::Illustration de l'équipe, retirée ou non ; class: celle du <svg>.
    def announcement_illustration(ref, class: nil)
      classes = binding.local_variable_get(:class)
      return team_illustration_svg(ref, classes) if ref.is_a?(TEAM_ILLUSTRATION)

      name = ref.to_s
      unless Entities::Communication::Message::ILLUSTRATIONS.include?(name)
        raise ArgumentError, "announcement_illustration : « #{ref} » inconnue (#{Entities::Communication::Message::ILLUSTRATIONS.join(', ')})"
      end

      render "communication/messages/illustrations/#{name}", classes:
    end

    private

    # ADR-0081 §4.3, UDR-0075 §3.2 : rien de stocké n'est inséré tel quel. Chaque forme de premier niveau est revérifiée
    # avec tout son arbre (valid_shape?) ; ce qui ne passe pas est omis, une viewBox hors de son expression aussi. Le
    # dessin prend une seule couleur, celle de l'illustration forte du thème.
    def team_illustration_svg(illustration, classes)
      view_box = illustration.view_box if TEAM_ILLUSTRATION::VIEW_BOX.match?(illustration.view_box.to_s)
      shapes = Array(illustration.shapes).select { TEAM_ILLUSTRATION.valid_shape?(it, depth: 1) }
      tag.svg(viewBox: view_box, "aria-hidden": "true", focusable: "false", class: token_list(classes, "fill-brand-strong")) do
        safe_join(shapes.map { team_illustration_shape(it) })
      end
    end

    # Une forme déjà vérifiée : la balise est nommée depuis TEAM_ILLUSTRATION::ELEMENTS, et ses attributs sont relus dans
    # l'ordre de la liste blanche. Seul « g » a un contenu, ses enfants.
    def team_illustration_shape(shape)
      element = TEAM_ILLUSTRATION::ELEMENTS.find { it == shape["name"] }
      stored = shape["attributes"]
      attributes = TEAM_ILLUSTRATION::ATTRIBUTES.fetch(element).select { stored.key?(it) }.index_with { stored[it] }
      return tag.public_send(element, **attributes) unless element == "g"

      tag.g(**attributes) { safe_join(shape["children"].map { team_illustration_shape(it) }) }
    end
  end
end

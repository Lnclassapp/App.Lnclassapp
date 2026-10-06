# 🔌 INFRA · Communication::DrawingReader — adaptateur de Ports::Communication::DrawingReaderPort (Nokogiri)
# Rôle : lit un SVG de l'équipe en XML strict, sans réseau ni DTD ; refuse tout ce qui peut s'exécuter ou charger, rend ses formes permises
# ADR  : 0081 (§4.3, §6) · UDR : 0075 (§3.2, §3.5)
module Communication
  # Le fichier n'atteint jamais la page : seules les formes de la liste blanche sortent d'ici, attribut par attribut,
  # chacun conforme à son expression (Entities::Communication::Illustration). Les dessins seront rendus chez des élèves
  # mineurs, et un compte de l'équipe peut être compromis : au moindre doute, le fichier entier est refusé.
  class DrawingReader
    include Ports::Communication::DrawingReaderPort

    ILLUSTRATION = Entities::Communication::Illustration
    SVG_NAMESPACE = "http://www.w3.org/2000/svg".freeze
    # XML strict (aucune récupération d'erreur) et sans réseau. Ni NOENT (substitution des entités), ni DTDLOAD ni DTDATTR
    # (lecture d'une DTD externe), ni HUGE (les limites de libxml2 tiennent), ni XINCLUDE.
    PARSE_OPTIONS = Nokogiri::XML::ParseOptions.new.strict.nonet.to_i
    # Les octets sont lus comme de l'UTF-8, quoi qu'en dise la déclaration XML : un encodage déclaré autre (UTF-7…)
    # pourrait cacher des balises à l'examen des octets. Un tel fichier est refusé.
    ENCODING = "UTF-8".freeze
    FOREIGN_ENCODING = /\A(?:\xEF\xBB\xBF)?<\?xml[^>]*?\bencoding[ \t\r\n]*=[ \t\r\n]*["'](?!utf-8["'])/ni
    # Avant que libxml2 ne lise quoi que ce soit : toute déclaration de DTD (<!DOCTYPE, <!ENTITY, <!ELEMENT, <!ATTLIST,
    # <!NOTATION) et toute référence à une entité autre que les 5 prédéfinies ou un caractère. Un « billion laughs » ou
    # une entité externe (XXE) n'atteint donc jamais l'analyseur.
    RAW_UNSAFE = /<![A-Za-z]|&(?!(?:amp|lt|gt|quot|apos|#[0-9]+|#x[0-9A-Fa-f]+);)[^\s&;<>"'#]+;/n
    # Nœuds refusés où qu'ils soient : DTD, déclarations, entités, instructions de traitement (la déclaration XML n'en
    # est pas une), inclusions.
    UNSAFE_NODES = [
      Nokogiri::XML::Node::DTD_NODE, Nokogiri::XML::Node::ELEMENT_DECL, Nokogiri::XML::Node::ATTRIBUTE_DECL,
      Nokogiri::XML::Node::ENTITY_DECL, Nokogiri::XML::Node::ENTITY_NODE, Nokogiri::XML::Node::ENTITY_REF_NODE,
      Nokogiri::XML::Node::NOTATION_NODE, Nokogiri::XML::Node::PI_NODE, Nokogiri::XML::Node::XINCLUDE_START,
      Nokogiri::XML::Node::XINCLUDE_END
    ].freeze
    # Éléments refusés, quels que soient leur espace de noms et leur casse (un html:script s'exécute dans un document
    # XML), et toute animation (animate, animateMotion, animateTransform…). ADR-0081 §4.3, plus ce qui exécute
    # (handler et listener de SVG Tiny) ou embarque un document (embed, object, frame, frameset) au même titre qu'iframe.
    UNSAFE_ELEMENTS = %w[script foreignobject style iframe image use a set handler listener embed object frame frameset].freeze
    UNSAFE_ELEMENT_PREFIX = "animate".freeze
    # Attributs refusés, quels que soient leur espace de noms et leur casse : tout gestionnaire on*, tout lien (href,
    # xlink:href, et src, le lien d'un élément XHTML).
    UNSAFE_ATTRIBUTES = %w[href src].freeze
    UNSAFE_ATTRIBUTE_PREFIX = "on".freeze
    # Dans toute valeur, une fois défaits les échappements CSS et retirés barres obliques, espaces, caractères de
    # contrôle et de format, en minuscules.
    UNSAFE_VALUES = %w[url( javascript: vbscript:].freeze
    CSS_ESCAPE = /\\(\h{1,6})[ \t\r\n\f]?/
    INVISIBLE = /[\\[:space:]\p{Cc}\p{Cf}]/

    def read(bytes:)
      text = bytes.b
      return refused(:not_svg) unless utf8?(text)
      return refused(:unsafe) if RAW_UNSAFE.match?(text)

      document = Nokogiri::XML::Document.read_memory(text, nil, ENCODING, PARSE_OPTIONS)
      root = document.root
      return refused(:not_svg) unless svg?(root)
      return refused(:unsafe) if unsafe?(document)

      drawing(root)
    rescue Nokogiri::XML::SyntaxError
      refused(:not_svg)
    end

    private

    def refused(reason) = Shared::Result.failure(:invalid, errors: { file: [ reason ] })

    def utf8?(text) = text.dup.force_encoding(Encoding::UTF_8).valid_encoding? && !FOREIGN_ENCODING.match?(text)

    # La racine est un élément svg, de l'espace SVG ou sans espace de noms.
    def svg?(root) = root.name == "svg" && [ nil, SVG_NAMESPACE ].include?(Reconstruction.namespace(root))

    # Tout le document est examiné, ce que la reconstruction ignorera compris (defs, métadonnées, éléments d'éditeur).
    def unsafe?(document)
      document.traverse { |node| return true if unsafe_node?(node) }
      false
    end

    def unsafe_node?(node)
      UNSAFE_NODES.include?(node.type) ||
        (node.element? && (unsafe_element?(node.name) || node.attribute_nodes.any? { unsafe_attribute?(it) } ||
                           node.namespace_definitions.any? { unsafe_value?(it.href.to_s) }))
    end

    def unsafe_element?(name)
      name = local(name)
      UNSAFE_ELEMENTS.include?(name) || name.start_with?(UNSAFE_ELEMENT_PREFIX)
    end

    def unsafe_attribute?(attribute)
      name = local(attribute.name)
      name.start_with?(UNSAFE_ATTRIBUTE_PREFIX) || UNSAFE_ATTRIBUTES.include?(name) || unsafe_value?(attribute.value)
    end

    # Le nom local, en minuscules. Sous un préfixe non déclaré, libxml2 laisse le nom entier (« x:script », « x:onload ») :
    # seul ce qui suit le dernier « : » est comparé.
    def local(name) = name.downcase.split(":").last.to_s

    # \75 rl( se lit url( en CSS : un échappement est rendu à son caractère ASCII (au-delà, à un caractère de contrôle,
    # ensuite retiré).
    def unsafe_value?(value)
      plain = value.gsub(CSS_ESCAPE) { Regexp.last_match(1).hex.clamp(0, 0x7F).chr }.gsub(INVISIBLE, "").downcase
      UNSAFE_VALUES.any? { plain.include?(it) }
    end

    # Une viewBox valide et au moins une forme gardée, ou :empty ; trop de formes ou trop de niveaux : :unsafe.
    def drawing(root)
      shapes = catch(:unsafe) { Reconstruction.new(Reconstruction.namespace(root)).shapes(root, 1) }
      return refused(:unsafe) if shapes == :unsafe

      view_box = root["viewBox"].to_s
      # Ceinture et bretelles : la reconstruction ne produit que des formes conformes, revérifiées ici une à une.
      shapes = shapes.select { ILLUSTRATION.valid_shape?(it, depth: 1) }
      return refused(:empty) unless view_box?(view_box) && shapes.any?

      Shared::Result.success({ view_box:, shapes: })
    end

    # Quatre nombres (Illustration::VIEW_BOX), une largeur et une hauteur positives et finies.
    def view_box?(view_box)
      ILLUSTRATION::VIEW_BOX.match?(view_box) &&
        view_box.split(/[\s,]+/).reject(&:empty?).last(2).all? { it.to_f.positive? && it.to_f.finite? }
    end

    # Les formes permises de l'espace de noms de la racine, au format de Illustration.valid_shape? : leurs seuls attributs
    # géométriques sans espace de noms et conformes à PATTERNS ; des enfants pour « g » seulement. Le reste est ignoré,
    # contenu compris ; un groupe qui ne garde aucune forme disparaît. Au-delà de MAX_SHAPES formes (groupes compris) ou
    # de MAX_DEPTH niveaux, la lecture s'arrête : throw :unsafe.
    class Reconstruction
      def self.namespace(node) = node.namespace&.href

      def initialize(namespace)
        @namespace = namespace
        @count = 0
      end

      def shapes(parent, depth) = parent.element_children.filter_map { shape(it, depth) if kept?(it) }

      private

      def kept?(node) = Reconstruction.namespace(node) == @namespace && ILLUSTRATION::ELEMENTS.include?(node.name)

      def shape(node, depth)
        throw :unsafe, :unsafe if depth > ILLUSTRATION::MAX_DEPTH || (@count += 1) > ILLUSTRATION::MAX_SHAPES

        group = node.name == "g"
        children = group ? shapes(node, depth + 1) : []
        return if group && children.empty?

        { "name" => node.name, "attributes" => attributes(node), "children" => children }
      end

      def attributes(node)
        allowed = ILLUSTRATION::ATTRIBUTES.fetch(node.name)
        node.attribute_nodes.each_with_object({}) do |attribute, kept|
          name = attribute.name
          next unless attribute.namespace.nil? && allowed.include?(name) && ILLUSTRATION.valid_value?(name, attribute.value)

          kept[name] = attribute.value
        end
      end
    end
  end
end

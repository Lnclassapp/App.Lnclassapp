# 🧠 DOMAINE · Entities::Communication::Illustration
# Rôle : un dessin de l'équipe pour les annonces, gardé en formes reconstruites ; la liste blanche qui gèle leur format
# ADR  : 0081 · UDR : 0075
module Entities
  module Communication
    # Contrat gelé au Lot 0 d'annonces-v2 (ADR-0081 §4.3 et §6). Une forme, telle que shapes la stocke :
    #   { "name" => "path", "attributes" => { "d" => "M4 4h56v56H4z" }, "children" => [] }
    # Trois clés en chaînes, toujours ; seul « g » a des enfants. La lecture du SVG (Lot C) produit ce format, le rendu
    # (Communication::IllustrationsHelper) le consomme, et les deux le vérifient par Illustration.valid_shape?.
    Illustration = Data.define(:id, :public_id, :name, :view_box, :shapes, :created_by_id, :retired_at) do
      # Une illustration à créer n'a ni id ni public_id, et n'est pas retirée.
      def initialize(name:, view_box:, shapes:, created_by_id:, id: nil, public_id: nil, retired_at: nil)
        super
      end

      # Retirée : hors du choix des auteurs, mais toujours rendue sur les annonces qui la portent (ADR-0081 §4.3).
      def retired? = !retired_at.nil?

      # shape : une forme (Hash) ; depth : sa profondeur, 1 au premier niveau de shapes. Vraie si la forme et tous ses
      # enfants respectent la liste blanche : élément permis, attributs permis pour cet élément, chaque valeur une chaîne
      # conforme à PATTERNS, enfants pour « g » seulement, MAX_DEPTH niveaux au plus. Rien d'autre n'est toléré.
      def self.valid_shape?(shape, depth:)
        keys = Illustration::SHAPE_KEYS
        return false unless shape.is_a?(Hash) && shape.size == keys.size && (shape.keys - keys).empty?
        return false unless depth.is_a?(Integer) && depth.between?(1, Illustration::MAX_DEPTH)

        name, attributes, children = shape.values_at(*keys)
        allowed = Illustration::ATTRIBUTES[name]
        return false unless allowed && attributes.is_a?(Hash) && children.is_a?(Array)
        return false unless attributes.all? { |key, value| allowed.include?(key) && Illustration.valid_value?(key, value) }
        return children.empty? unless name == "g"

        children.all? { valid_shape?(it, depth: depth + 1) }
      end

      # Une valeur d'attribut : une chaîne conforme à l'expression de son attribut.
      def self.valid_value?(key, value) = value.is_a?(String) && Illustration::PATTERNS.fetch(key).match?(value)
    end

    Illustration::NAME_MAX = 30
    # Illustrations de l'équipe encore proposées, au plus : la 51ᵉ attend qu'une autre soit retirée (revue de sécurité
    # du Lot C d'annonces-v2, constat B1 ; seule constante ajoutée par le Lot C à ce contrat du Lot 0).
    Illustration::LIBRARY_CAP = 50
    # Poids du fichier SVG envoyé, vérifié avant toute lecture (ADR-0081 §4.3).
    Illustration::MAX_BYTES = 50 * 1024
    # Formes d'un dessin, tous niveaux confondus ; la base borne aussi le premier niveau.
    Illustration::MAX_SHAPES = 500
    Illustration::MAX_DEPTH = 8
    Illustration::SHAPE_KEYS = %w[name attributes children].freeze
    Illustration::ELEMENTS = %w[g path rect circle ellipse line polyline polygon].freeze
    # Les seuls attributs géométriques, chacun sur les éléments où il a un sens (ADR-0081 §4.3). Aucune couleur : le
    # dessin prend celle du thème.
    Illustration::ATTRIBUTES = {
      "g" => %w[transform fill-rule],
      "path" => %w[d transform fill-rule],
      "rect" => %w[x y width height rx ry transform],
      "circle" => %w[cx cy r transform],
      "ellipse" => %w[cx cy rx ry transform],
      "line" => %w[x1 y1 x2 y2 transform],
      "polyline" => %w[points transform fill-rule],
      "polygon" => %w[points transform fill-rule]
    }.transform_values(&:freeze).freeze

    # Un nombre SVG : signe, partie entière ou décimale, exposant. Borné en longueur par construction.
    Illustration::NUMBER = /[-+]?(?:\d{1,20}(?:\.\d{0,20})?|\.\d{1,20})(?:[eE][-+]?\d{1,3})?/
    # Entre deux nombres : une virgule entourée d'espaces, ou des espaces.
    Illustration::SEPARATOR = /(?:[ \t\n\r]*,[ \t\n\r]*|[ \t\n\r]+)/
    # Une fonction de transformation et ses 1 à 6 nombres.
    Illustration::TRANSFORM_FUNCTION =
      /(?:matrix|translate|scale|rotate|skewX|skewY)[ \t\n\r]*\([ \t\n\r]*#{Illustration::NUMBER}(?:#{Illustration::SEPARATOR}#{Illustration::NUMBER}){0,5}[ \t\n\r]*\)/
    Illustration::COORDINATE = /\A#{Illustration::NUMBER}\z/
    # Quatre nombres, 200 caractères au plus.
    Illustration::VIEW_BOX =
      /\A(?=[\s\S]{1,200}\z)[ \t\n\r]*#{Illustration::NUMBER}(?:#{Illustration::SEPARATOR}#{Illustration::NUMBER}){3}[ \t\n\r]*\z/

    # Attribut → expression stricte, ancrée au début et à la fin, bornée en longueur. Pour d et points, une classe de
    # caractères : aucun retour en arrière possible, et ni guillemet, ni chevron, ni parenthèse.
    Illustration::PATTERNS = {
      "d" => /\A[MmLlHhVvCcSsQqTtAaZz0-9eE.+\-, \t\n\r]{1,20000}\z/,
      "points" => /\A[0-9eE.+\-, \t\n\r]{1,20000}\z/,
      "transform" =>
        /\A(?=[\s\S]{1,2000}\z)[ \t\n\r]*#{Illustration::TRANSFORM_FUNCTION}(?:[ \t\n\r,]*#{Illustration::TRANSFORM_FUNCTION}){0,15}[ \t\n\r]*\z/,
      "fill-rule" => /\A(?:nonzero|evenodd)\z/,
      **%w[x y width height rx ry cx cy r x1 y1 x2 y2].to_h { [ it, Illustration::COORDINATE ] }
    }.freeze
  end
end

# 🌐 UI · Catalog::CourseSheetLensHelper — l'optique de la fiche Lentilles, calculée côté serveur pour la position de départ des figures
# Rôle : les trois rayons particuliers, l'image et l'application d'une lentille convergente (kinds/_lens_simulator, _lens_construction) ; mêmes formules que lib/course_sheet/lens_geometry.js
# ADR  : 0110-fiche-de-cours-en-donnees-importees (chantier contenu-en-blocs, 318) · formules de la maquette Fiche Lentilles.dc.html (rays) ; sans JavaScript, le serveur dessine la position de départ
module Catalog
  module CourseSheetLensHelper
    # x1..y2 : en unités du dessin ; ray : 1, 2 ou 3 ; virtual : le prolongement en pointillés d'un rayon
    Ray = Data.define(:x1, :y1, :x2, :y2, :ray, :virtual)
    # distance : OA′ en cm (négative : image virtuelle, du côté de l'objet) ; gain : A′B′ / AB (négatif : renversée) ; x, y : B′ dans le dessin
    Image = Data.define(:distance, :gain, :x, :y, :virtual)
    Scene = Data.define(:rays, :image)

    # À moins de 0,06 cm du foyer, les rayons ressortent parallèles : pas d'image nette.
    FOCUS_TOLERANCE = 0.06
    # Objet à plus de 40 cm de la lentille : l'image est trop loin pour le dessin, elle n'est pas tracée.
    IMAGE_MAX = 40
    SAME_SIZE = 0.03

    # o : abscisse de la lentille ; ax : ordonnée de l'axe ; s : pixels par cm ; w : largeur du dessin ;
    # d : OA, h : AB, f : distance focale, en cm. → Scene
    def lens_scene(o:, ax:, s:, w:, d:, h:, f:)
      o, ax, s, w, d, h, f = [ o, ax, s, w, d, h, f ].map(&:to_f)
      xb = o - d * s
      yb = ax - h * s
      rays = []
      add = ->(x1, y1, x2, y2, ray, virtual = false) { rays << Ray.new(x1: x1.round(2), y1: y1.round(2), x2: x2.round(2), y2: y2.round(2), ray:, virtual:) }
      add.(xb, yb, o, yb, 1)
      add.(o, yb, w, yb + (ax - yb) / (f * s) * (w - o), 1)
      add.(xb, yb, w, yb + (ax - yb) / (d * s) * (w - xb), 2)
      return Scene.new(rays:, image: nil) if (d - f).abs <= FOCUS_TOLERANCE

      y3 = ax + (yb - ax) * (f / (f - d))
      add.(o - f * s, ax, xb, yb, 3, true) if d < f
      add.(xb, yb, o, y3, 3)
      add.(o, y3, w, y3, 3)
      distance = d * f / (d - f)
      gain = -distance / d
      image = Image.new(distance:, gain:, x: (o + distance * s).round(2), y: (ax - gain * h * s).round(2), virtual: distance.negative?)
      if image.virtual
        add.(o, yb, image.x, image.y, 1, true)
        add.(xb, yb, image.x, image.y, 2, true)
        add.(o, y3, image.x, image.y, 3, true)
      end
      Scene.new(rays:, image:)
    end

    # :magnifier (objet entre la lentille et le foyer), :projector (entre F et 2F), :photo (au-delà de 2F), nil (au foyer)
    def lens_application(d, f)
      return if (d - f).abs <= FOCUS_TOLERANCE

      if d < f then :magnifier
      elsif d < 2 * f then :projector
      else :photo
      end
    end

    # :bigger, :smaller ou :same, d'après le gain d'une image réelle
    def lens_size(gain)
      size = gain.abs
      if size > 1 + SAME_SIZE then :bigger
      elsif size < 1 - SAME_SIZE then :smaller
      else :same
      end
    end

    # Un nombre à la française, au dixième : « 2 », « 2,5 »
    def lens_number(value) = format("%g", (value * 10).round / 10.0).tr(".", ",")

    # La pointe d'une flèche de 10 unités sur 5 de demi-largeur, du côté de l'axe : « x,y x−5,y+10 x+5,y+10 »
    def lens_head(x, y, ax)
      sign = y < ax ? 1 : -1
      [ [ x, y ], [ x - 5, y + 10 * sign ], [ x + 5, y + 10 * sign ] ].map { |px, py| "#{px.round(2)},#{py.round(2)}" }.join(" ")
    end

    # Une valeur de params hors de [min, max], absente ou illisible revient dans les bornes ou à sa valeur de départ ; arrondie au dixième.
    def lens_param(value, default, range)
      number = value.is_a?(Numeric) ? value : default
      ((number.clamp(range.begin, range.end) * 10).round / 10.0)
    end
  end
end

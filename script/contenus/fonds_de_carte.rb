# frozen_string_literal: true

# Fabrique les trois modules de fonds de carte de la figure `map` : app/javascript/lib/figures/maps/{cote_d_ivoire,africa,world}.js
# (ADR figures-des-matieres-de-3eme §4.3). Hors application, une fois : projection, simplification (Douglas-Peucker) et arrondi
# à une décimale se font ici ; le navigateur ne reçoit que des chemins SVG déjà projetés.
#
# Usage : ruby script/contenus/fonds_de_carte.rb [cote_d_ivoire] [africa] [world]   (sans argument : les trois)
#
# Sources, téléchargées dans tmp/fonds/ (jamais versionnées) :
#   - monde : Natural Earth 1:110m, pays (domaine public), projection Equal Earth, viewBox 640×360
#   - Afrique : Natural Earth 1:50m, pays (domaine public), projection Equal Earth, viewBox 640×640
#   - Côte d'Ivoire : geoBoundaries CIV ADM1 (CC BY 4.0), 14 districts, projection équirectangulaire corrigée, viewBox 640×640
#   - villes : Natural Earth 1:10m, lieux peuplés ; à défaut, les coordonnées écrites ci-dessous
# Les zones naturelles de la Côte d'Ivoire sont schématiques : des cellules convexes en longitude-latitude, découpées sur le contour
# du pays (Sutherland-Hodgman), sans chevauchement, puis fusionnées en un seul contour par zone.
# Ruby pur : ni Rails ni bundler.
require "json"
require "net/http"
require "uri"
require "fileutils"
require_relative "../../app/domain/entities/catalog/figure_catalogs"

module FondsDeCarte
  ROOT = File.expand_path("../..", __dir__)
  TMP = File.join(ROOT, "tmp", "fonds")
  OUT = File.join(ROOT, "app", "javascript", "lib", "figures", "maps")
  CATALOGS = Entities::Catalog::FigureCatalogs
  BUDGET = 150 * 1024
  TARGET = 120 * 1024

  NE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"
  SOURCES = {
    "world" => [ "ne_110m_admin_0_countries.geojson", "#{NE}/ne_110m_admin_0_countries.geojson" ],
    "africa" => [ "ne_50m_admin_0_countries.geojson", "#{NE}/ne_50m_admin_0_countries.geojson" ],
    "places" => [ "ne_10m_populated_places_simple.geojson", "#{NE}/ne_10m_populated_places_simple.geojson" ],
    "districts" => [ "geoboundaries_civ_adm1.geojson",
                     "https://media.githubusercontent.com/media/wmgeolab/geoBoundaries/9469f09/releaseData/gbOpen/CIV/ADM1/geoBoundaries-CIV-ADM1_simplified.geojson" ]
  }.freeze

  ATTRIBUTIONS = { "cote_d_ivoire" => "Districts : geoBoundaries, CC BY 4.0" }.freeze

  # ---------------------------------------------------------------------------------------------------------------- noms

  DISTRICTS = {
    "Bas-Sassandra" => [ "bas_sassandra", "Bas-Sassandra" ],
    "Denguele" => [ "denguele", "Denguélé" ],
    "District Autonome D'Abidjan" => [ "abidjan", "Abidjan" ],
    "District Autonome De Yamoussoukro" => [ "yamoussoukro", "Yamoussoukro" ],
    "Goh-Djiboua" => [ "goh_djiboua", "Gôh-Djiboua" ],
    "Lacs" => [ "lacs", "Lacs" ],
    "Montagnes" => [ "montagnes", "Montagnes" ],
    "Sassandra-Marahoue" => [ "sassandra_marahoue", "Sassandra-Marahoué" ],
    "Savanes" => [ "savanes", "Savanes" ],
    "Valle Du Bandama" => [ "vallee_du_bandama", "Vallée du Bandama" ],
    "Woroba" => [ "woroba", "Woroba" ],
    "Zanzan" => [ "zanzan", "Zanzan" ],
    "Lagunes" => [ "lagunes", "Lagunes" ],
    "Comoe" => [ "comoe", "Comoé" ]
  }.freeze
  ZONES = { "dense_forest" => "Forêt dense", "savanna" => "Savane", "coastal_strip" => "Littoral", "mountain_west" => "Montagnes de l'Ouest" }.freeze
  CONTINENTS = {
    "Africa" => [ "africa", "Afrique" ], "Asia" => [ "asia", "Asie" ], "Europe" => [ "europe", "Europe" ],
    "North America" => [ "north_america", "Amérique du Nord" ], "South America" => [ "south_america", "Amérique du Sud" ],
    "Oceania" => [ "oceania", "Océanie" ]
  }.freeze
  # Les noms français de Natural Earth trop longs ou abrégés, remplacés à la main.
  NAME_FIXES = {
    "cod" => "République démocratique du Congo", "cog" => "Congo", "caf" => "République centrafricaine", "dom" => "République dominicaine",
    "gnq" => "Guinée équatoriale", "bih" => "Bosnie-Herzégovine", "mkd" => "Macédoine du Nord", "atf" => "Terres australes françaises",
    "flk" => "Îles Malouines", "slb" => "Îles Salomon", "ssd" => "Soudan du Sud", "swz" => "Eswatini", "cyp" => "Chypre", "kos" => "Kosovo",
    "civ" => "Côte d'Ivoire", "tls" => "Timor oriental", "prk" => "Corée du Nord", "kor" => "Corée du Sud", "ncl" => "Nouvelle-Calédonie",
    "pse" => "Palestine", "esh" => "Sahara occidental", "stp" => "Sao Tomé-et-Principe", "cpv" => "Cap-Vert", "usa" => "États-Unis",
    "gbr" => "Royaume-Uni", "are" => "Émirats arabes unis", "tto" => "Trinité-et-Tobago", "png" => "Papouasie-Nouvelle-Guinée"
  }.freeze

  # ------------------------------------------------------------------------------------------------------------- lieux
  # [id, nom français, nom ASCII dans Natural Earth, ISO alpha-3 Natural Earth, latitude, longitude de repli]
  # Natural Earth d'abord ; les coordonnées de repli servent quand la ville n'y figure pas (nom ASCII nil).
  CI_PLACES = [
    [ "abidjan", "Abidjan", "Abidjan", "CIV", 5.32, -4.02 ], [ "yamoussoukro", "Yamoussoukro", "Yamoussoukro", "CIV", 6.82, -5.28 ],
    [ "bouake", "Bouaké", "Bouake", "CIV", 7.69, -5.03 ], [ "daloa", "Daloa", "Daloa", "CIV", 6.88, -6.45 ],
    [ "korhogo", "Korhogo", "Korhogo", "CIV", 9.46, -5.63 ], [ "san_pedro", "San-Pédro", "San-Pedro", "CIV", 4.75, -6.64 ],
    [ "man", "Man", "Man", "CIV", 7.41, -7.55 ], [ "gagnoa", "Gagnoa", "Gagnoa", "CIV", 6.13, -5.95 ],
    [ "abengourou", "Abengourou", "Abengourou", "CIV", 6.73, -3.49 ], [ "bondoukou", "Bondoukou", "Bondoukou", "CIV", 8.04, -2.80 ],
    [ "odienne", "Odienné", "Odienne", "CIV", 9.51, -7.56 ], [ "divo", "Divo", "Divo", "CIV", 5.84, -5.36 ],
    [ "sassandra", "Sassandra", "Sassandra", "CIV", 4.95, -6.08 ], [ "grand_bassam", "Grand-Bassam", "Grand-Bassam", "CIV", 5.21, -3.74 ],
    [ "bingerville", "Bingerville", nil, nil, 5.36, -3.89 ], [ "assinie", "Assinie", nil, nil, 5.13, -3.28 ],
    [ "grand_lahou", "Grand-Lahou", "Grand-Lahou", "CIV", 5.14, -5.02 ], [ "dabou", "Dabou", "Dabou", "CIV", 5.33, -4.38 ],
    [ "agboville", "Agboville", "Agboville", "CIV", 5.93, -4.22 ], [ "kong", "Kong", nil, nil, 9.15, -4.61 ],
    [ "seguela", "Séguéla", "Seguela", "CIV", 7.96, -6.67 ], [ "ferkessedougou", "Ferkessédougou", "Ferkessedougou", "CIV", 9.59, -5.20 ],
    [ "katiola", "Katiola", "Katiola", "CIV", 8.14, -5.10 ], [ "dimbokro", "Dimbokro", "Dimbokro", "CIV", 6.65, -4.71 ],
    [ "aboisso", "Aboisso", "Aboisso", "CIV", 5.47, -3.21 ], [ "tabou", "Tabou", "Tabou", "CIV", 4.42, -7.35 ],
    [ "soubre", "Soubré", "Soubre", "CIV", 5.79, -6.61 ], [ "toumodi", "Toumodi", "Toumodi", "CIV", 6.56, -5.02 ],
    [ "tiassale", "Tiassalé", "Tiassale", "CIV", 5.90, -4.82 ], [ "danane", "Danané", "Danane", "CIV", 7.26, -8.15 ],
    [ "boundiali", "Boundiali", "Boundiali", "CIV", 9.52, -6.49 ], [ "touba", "Touba", "Touba", "CIV", 8.28, -7.68 ],
    [ "guiglo", "Guiglo", "Guiglo", "CIV", 6.54, -7.49 ], [ "duekoue", "Duékoué", "Duekoue", "CIV", 6.74, -7.35 ],
    [ "bouafle", "Bouaflé", "Bouafle", "CIV", 6.99, -5.74 ], [ "adzope", "Adzopé", "Adzope", "CIV", 6.11, -3.86 ],
    [ "issia", "Issia", "Issia", "CIV", 6.49, -6.59 ],
    [ "kossou", "Barrage de Kossou", nil, nil, 7.03, -5.47 ], [ "taabo", "Barrage de Taabo", nil, nil, 6.22, -5.10 ],
    [ "buyo", "Barrage de Buyo", nil, nil, 6.25, -7.03 ], [ "ayame", "Barrage d'Ayamé", nil, nil, 5.60, -3.16 ]
  ].freeze

  AFRICA_PLACES = [
    [ "algiers", "Alger", "Algiers", "DZA" ], [ "luanda", "Luanda", "Luanda", "AGO" ], [ "porto_novo", "Porto-Novo", "Porto-Novo", "BEN" ],
    [ "gaborone", "Gaborone", "Gaborone", "BWA" ], [ "ouagadougou", "Ouagadougou", "Ouagadougou", "BFA" ],
    [ "gitega", "Gitega", "Gitega", "BDI", -3.43, 29.93 ], [ "yaounde", "Yaoundé", "Yaounde", "CMR" ], [ "praia", "Praia", "Praia", "CPV" ],
    [ "bangui", "Bangui", "Bangui", "CAF" ], [ "ndjamena", "N'Djamena", "Ndjamena", "TCD" ], [ "moroni", "Moroni", "Moroni", "COM" ],
    [ "kinshasa", "Kinshasa", "Kinshasa", "COD" ], [ "brazzaville", "Brazzaville", "Brazzaville", "COG" ],
    [ "yamoussoukro", "Yamoussoukro", "Yamoussoukro", "CIV" ], [ "djibouti", "Djibouti", "Djibouti", "DJI" ], [ "cairo", "Le Caire", "Cairo", "EGY" ],
    [ "malabo", "Malabo", "Malabo", "GNQ" ], [ "asmara", "Asmara", "Asmara", "ERI" ], [ "mbabane", "Mbabane", "Mbabane", "SWZ" ],
    [ "addis_ababa", "Addis-Abeba", "Addis Ababa", "ETH" ], [ "libreville", "Libreville", "Libreville", "GAB" ],
    [ "banjul", "Banjul", "Banjul", "GMB" ], [ "accra", "Accra", "Accra", "GHA" ], [ "conakry", "Conakry", "Conakry", "GIN" ],
    [ "bissau", "Bissau", "Bissau", "GNB" ], [ "nairobi", "Nairobi", "Nairobi", "KEN" ], [ "maseru", "Maseru", "Maseru", "LSO" ],
    [ "monrovia", "Monrovia", "Monrovia", "LBR" ], [ "tripoli", "Tripoli", "Tripoli", "LBY" ], [ "antananarivo", "Antananarivo", "Antananarivo", "MDG" ],
    [ "lilongwe", "Lilongwe", "Lilongwe", "MWI" ], [ "bamako", "Bamako", "Bamako", "MLI" ], [ "nouakchott", "Nouakchott", "Nouakchott", "MRT" ],
    [ "port_louis", "Port-Louis", "Port Louis", "MUS" ], [ "rabat", "Rabat", "Rabat", "MAR" ], [ "maputo", "Maputo", "Maputo", "MOZ" ],
    [ "windhoek", "Windhoek", "Windhoek", "NAM" ], [ "niamey", "Niamey", "Niamey", "NER" ], [ "abuja", "Abuja", "Abuja", "NGA" ],
    [ "kigali", "Kigali", "Kigali", "RWA" ], [ "sao_tome", "São Tomé", "Sao Tome", "STP" ], [ "dakar", "Dakar", "Dakar", "SEN" ],
    [ "victoria", "Victoria", "Victoria", "SYC" ], [ "freetown", "Freetown", "Freetown", "SLE" ], [ "mogadishu", "Mogadiscio", "Mogadishu", "SOM" ],
    [ "pretoria", "Pretoria", "Pretoria", "ZAF" ], [ "juba", "Juba", "Juba", "SSD" ], [ "khartoum", "Khartoum", "Khartoum", "SDN" ],
    [ "dodoma", "Dodoma", "Dodoma", "TZA" ], [ "lome", "Lomé", "Lome", "TGO" ], [ "tunis", "Tunis", "Tunis", "TUN" ],
    [ "kampala", "Kampala", "Kampala", "UGA" ], [ "lusaka", "Lusaka", "Lusaka", "ZMB" ], [ "harare", "Harare", "Harare", "ZWE" ],
    [ "abidjan", "Abidjan", "Abidjan", "CIV" ], [ "lagos", "Lagos", "Lagos", "NGA" ], [ "johannesburg", "Johannesburg", "Johannesburg", "ZAF" ],
    [ "casablanca", "Casablanca", "Casablanca", "MAR" ], [ "alexandria", "Alexandrie", "Alexandria", "EGY" ], [ "mombasa", "Mombasa", "Mombasa", "KEN" ],
    [ "douala", "Douala", "Douala", "CMR" ], [ "suez", "Suez", "Suez", "EGY" ]
  ].freeze

  WORLD_PLACES = [
    [ "pearl_harbor", "Pearl Harbor", nil, nil, 21.35, -157.95 ], [ "hiroshima", "Hiroshima", "Hiroshima", "JPN" ], [ "nagasaki", "Nagasaki", "Nagasaki", "JPN" ],
    [ "stalingrad", "Stalingrad", "Volgograd", "RUS" ], [ "normandy", "Normandie", nil, nil, 49.35, -0.85 ], [ "berlin", "Berlin", "Berlin", "DEU" ],
    [ "london", "Londres", "London", "GBR" ], [ "paris", "Paris", "Paris", "FRA" ], [ "moscow", "Moscou", "Moscow", "RUS" ],
    [ "washington", "Washington", "Washington, D.C.", "USA", 38.90, -77.04 ], [ "tokyo", "Tokyo", "Tokyo", "JPN" ], [ "rome", "Rome", "Rome", "ITA" ],
    [ "el_alamein", "El-Alamein", nil, nil, 30.83, 28.95 ], [ "midway", "Midway", nil, nil, 28.21, -177.38 ], [ "warsaw", "Varsovie", "Warsaw", "POL" ],
    [ "yalta", "Yalta", "Yalta", "RUS" ], [ "brazzaville", "Brazzaville", "Brazzaville", "COG" ], [ "new_york", "New York", "New York", "USA" ],
    [ "san_francisco", "San Francisco", "San Francisco", "USA" ], [ "geneva", "Genève", "Geneva", "CHE" ], [ "the_hague", "La Haye", nil, nil, 52.08, 4.30 ],
    [ "abidjan", "Abidjan", "Abidjan", "CIV" ]
  ].freeze

  # ------------------------------------------------------------------------------------------------------------ géométrie

  EARTH_A = [ 1.340264, -0.081106, 0.000893, 0.003796 ].freeze

  # Equal Earth (Šavrič, Patterson, Jenny 2018) : x vers l'est, y vers le nord, en unités arbitraires.
  def self.equal_earth(lon, lat)
    a1, a2, a3, a4 = EARTH_A
    lam = lon * Math::PI / 180
    theta = Math.asin(Math.sqrt(3) / 2 * Math.sin(lat * Math::PI / 180))
    t2 = theta * theta
    t6 = t2**3
    x = 2 * Math.sqrt(3) * lam * Math.cos(theta) / (3 * (a1 + 3 * a2 * t2 + t6 * (7 * a3 + 9 * a4 * t2)))
    y = theta * (a1 + a2 * t2 + t6 * (a3 + 3 * a4 * t2))
    [ x, y ]
  end

  # Projection équirectangulaire dont l'échelle est corrigée à la latitude centrale (petite étendue : la Côte d'Ivoire).
  def self.plate_carree(lat0)
    k = Math.cos(lat0 * Math::PI / 180)
    ->(lon, lat) { [ lon * k, lat ] }
  end

  def self.area(ring)
    sum = 0.0
    ring.each_with_index { |(x1, y1), i| x2, y2 = ring[(i + 1) % ring.size]; sum += x1 * y2 - x2 * y1 }
    sum / 2
  end

  # Douglas-Peucker sur une ligne ouverte (itératif) ; renvoie les points conservés.
  def self.douglas_peucker(points, tolerance)
    return points if points.size < 3

    keep = Array.new(points.size, false)
    keep[0] = keep[-1] = true
    stack = [ [ 0, points.size - 1 ] ]
    until stack.empty?
      first, last = stack.pop
      next if last <= first + 1

      ax, ay = points[first]
      bx, by = points[last]
      dx = bx - ax
      dy = by - ay
      length = Math.hypot(dx, dy)
      worst = -1
      worst_index = nil
      ((first + 1)...last).each do |i|
        px, py = points[i]
        distance = length.zero? ? Math.hypot(px - ax, py - ay) : ((px - ax) * dy - (py - ay) * dx).abs / length
        next unless distance > worst

        worst = distance
        worst_index = i
      end
      next unless worst > tolerance

      keep[worst_index] = true
      stack << [ first, worst_index ] << [ worst_index, last ]
    end
    points.each_index.select { |i| keep[i] }.map { |i| points[i] }
  end

  # Un anneau fermé : coupé en deux au point le plus éloigné du premier, chaque moitié simplifiée.
  def self.simplify_ring(ring, tolerance)
    return ring if ring.size < 4

    far = (1...ring.size).max_by { |i| Math.hypot(ring[i][0] - ring[0][0], ring[i][1] - ring[0][1]) }
    left = douglas_peucker(ring[0..far], tolerance)
    right = douglas_peucker(ring[far..] + [ ring[0] ], tolerance)
    left[0...-1] + right[0...-1]
  end

  # --- Découpe de polygones (convexe contre quelconque) -----------------------------------------------------------------

  def self.side(p, q, r) = (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])

  def self.snap(point) = point.map { |v| v.round(6) }

  # Garde la partie du polygone à gauche de l'arête p→q (Sutherland-Hodgman, une arête).
  def self.clip_edge(poly, p, q)
    out = []
    poly.each_with_index do |cur, i|
      prev = poly[i - 1]
      s_cur = side(p, q, cur)
      s_prev = side(p, q, prev)
      if s_cur >= 0
        out << cross(prev, cur, s_prev, s_cur) if s_prev < 0
        out << cur
      elsif s_prev >= 0
        out << cross(prev, cur, s_prev, s_cur)
      end
    end
    out
  end

  def self.cross(prev, cur, s_prev, s_cur)
    t = s_prev / (s_prev - s_cur)
    snap([ prev[0] + t * (cur[0] - prev[0]), prev[1] + t * (cur[1] - prev[1]) ])
  end

  def self.ccw(poly) = area(poly).negative? ? poly.reverse : poly

  # Intersection d'un polygone quelconque avec un polygone convexe.
  def self.intersect_convex(poly, clip)
    clip = ccw(clip)
    clip.each_with_index.reduce(poly) do |current, (p, i)|
      current.empty? ? current : clip_edge(current, p, clip[(i + 1) % clip.size])
    end
  end

  # Différence : le polygone moins un polygone convexe, en morceaux disjoints.
  def self.difference_convex(poly, clip)
    clip = ccw(clip)
    pieces = []
    rest = poly
    clip.each_with_index do |p, i|
      q = clip[(i + 1) % clip.size]
      outside = clip_edge(rest, q, p)
      pieces << outside if outside.size >= 3 && area(outside).abs > 1e-9
      rest = clip_edge(rest, p, q)
      break if rest.empty?
    end
    pieces
  end

  # Enveloppe convexe (chaîne monotone), sens trigonométrique.
  def self.hull(points)
    pts = points.uniq.sort
    return pts if pts.size < 3

    build = lambda do |list|
      chain = []
      list.each do |pt|
        chain.pop while chain.size >= 2 && side(chain[-2], chain[-1], pt) <= 0
        chain << pt
      end
      chain
    end
    lower = build.call(pts)
    upper = build.call(pts.reverse)
    lower[0...-1] + upper[0...-1]
  end

  # Réunit des polygones jointifs en contours : les arêtes parcourues dans les deux sens (frontières internes, ponts dégénérés de
  # Sutherland-Hodgman) s'annulent ; ce qui reste est rechaîné en anneaux.
  def self.merge(polys)
    snapped = polys.map { |poly| ccw(poly.map { |pt| canon(pt) }).chunk_while { |a, b| a == b }.map(&:first) }.select { |poly| poly.size >= 3 }
    vertices = snapped.flatten(1).uniq
    bag = Hash.new(0)
    snapped.each do |poly|
      poly.each_with_index do |a, i|
        b = poly[(i + 1) % poly.size]
        next if a == b

        chain = [ a ] + on_segment(a, b, vertices).sort_by { |v| (v[0] - a[0])**2 + (v[1] - a[1])**2 } + [ b ]
        chain.each_cons(2) do |s, e|
          if bag[[ e, s ]].positive? then bag[[ e, s ]] -= 1
          else bag[[ s, e ]] += 1
          end
        end
      end
    end
    outgoing = Hash.new { |h, k| h[k] = [] }
    bag.each { |(s, e), n| n.times { outgoing[s] << e } }
    rings = []
    until outgoing.empty?
      start = outgoing.keys.first
      ring = [ start ]
      current = start
      loop do
        nxt = outgoing[current].shift
        outgoing.delete(current) if outgoing[current].empty?
        break if nxt.nil? || nxt == start

        ring << nxt
        current = nxt
        break unless outgoing.key?(current)
      end
      rings << ring if ring.size >= 3 && area(ring).abs > 1e-5
    end
    rings
  end

  CANON = {} # rubocop:disable Style/MutableConstant
  # Deux points à moins de 2e-5 degré l'un de l'autre sont le même sommet.
  def self.canon(point)
    cell = [ (point[0] * 5e4).round, (point[1] * 5e4).round ]
    (-1..1).each { |dx| (-1..1).each { |dy| found = CANON[[ cell[0] + dx, cell[1] + dy ]]; return found if found && (found[0] - point[0]).abs < 2e-5 && (found[1] - point[1]).abs < 2e-5 } }
    CANON[cell] = point
  end

  # Les sommets posés sur l'arête a→b, hors extrémités.
  def self.on_segment(a, b, vertices)
    lo_x, hi_x = [ a[0], b[0] ].minmax
    lo_y, hi_y = [ a[1], b[1] ].minmax
    length = Math.hypot(b[0] - a[0], b[1] - a[1])
    vertices.select do |v|
      next false if v == a || v == b || v[0] < lo_x - 3e-5 || v[0] > hi_x + 3e-5 || v[1] < lo_y - 3e-5 || v[1] > hi_y + 3e-5
      next false unless (side(a, b, v) / length).abs < 3e-5

      t = ((v[0] - a[0]) * (b[0] - a[0]) + (v[1] - a[1]) * (b[1] - a[1])) / (length * length)
      t > 0 && t < 1
    end
  end

  # --- Chemins SVG -----------------------------------------------------------------------------------------------------

  # 10 → "1", 12 → "1.2", 3 → ".3", -3 → "-.3" (dixièmes d'unité, sans zéro inutile).
  def self.tenths(n)
    return "0" if n.zero?

    whole, frac = n.abs.divmod(10)
    text = frac.zero? ? whole.to_s : "#{whole.zero? ? '' : whole}.#{frac}"
    n.negative? ? "-#{text}" : text
  end

  def self.join_numbers(numbers)
    out = +""
    numbers.each_with_index do |n, i|
      text = tenths(n)
      out << " " unless i.zero? || text.start_with?("-")
      out << text
    end
    out
  end

  # Un anneau (points en unités du dessin) → "Mx yl dx dy … z", ou nil s'il s'effondre.
  def self.ring_path(ring, tolerance)
    pts = simplify_ring(ring, tolerance).map { |x, y| [ (x * 10).round, (y * 10).round ] }.chunk_while { |a, b| a == b }.map(&:first)
    pts.pop if pts.size > 1 && pts.first == pts.last
    return nil if pts.size < 3 || area(pts).abs < 3

    deltas = pts.each_cons(2).flat_map { |(x1, y1), (x2, y2)| [ x2 - x1, y2 - y1 ] }
    "M#{join_numbers(pts.first)}l#{join_numbers(deltas)}z"
  end

  # Un pays (liste de polygones, chacun une liste d'anneaux) → un seul `d`. Les petits anneaux disparaissent, sauf le plus grand.
  def self.shape_path(polygons, tolerance, min_area)
    rings = polygons.flatten(1)
    biggest = rings.max_by { |r| area(r).abs }
    parts = rings.filter_map do |ring|
      next if ring != biggest && area(ring).abs < min_area

      ring_path(ring, tolerance) || (ring.equal?(biggest) ? ring_path(ring, tolerance / 4) : nil)
    end
    parts.join
  end

  # --- Sources -------------------------------------------------------------------------------------------------------------

  def self.fetch(url, limit = 5)
    response = Net::HTTP.get_response(URI(url))
    return fetch(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection) && limit.positive?
    raise "#{response.code} pour #{url}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  def self.source(name)
    file, url = SOURCES.fetch(name)
    path = File.join(TMP, file)
    unless File.exist?(path)
      FileUtils.mkdir_p(TMP)
      warn "téléchargement de #{file}"
      File.binwrite("#{path}.part", fetch(url)) # jamais de fichier à moitié écrit sous le vrai nom
      File.rename("#{path}.part", path)
    end
    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    raise "#{path} n'est pas un JSON lisible (#{e.message[0, 80]}) : le supprimer pour le retélécharger"
  end

  # Les anneaux d'une géométrie GeoJSON : [[anneau, trous…], …] en [longitude, latitude].
  def self.polygons(geometry)
    list = geometry["type"] == "Polygon" ? [ geometry["coordinates"] ] : geometry["coordinates"]
    list.map { |rings| rings.map { |ring| ring.map { |lon, lat| [ lon.to_f, lat.to_f ] }.then { |r| r.first == r.last ? r[0...-1] : r } } }
  end

  def self.iso(properties)
    code = properties["ISO_A3"]
    (code == "-99" ? properties["ADM0_A3"] : code).downcase
  end

  # Natural Earth : lieux peuplés par (ISO, nom ASCII).
  def self.populated
    @populated ||= source("places")["features"].each_with_object({}) do |feature, found|
      p = feature["properties"]
      found[[ p["adm0_a3"], p["nameascii"] ]] ||= feature["geometry"]["coordinates"]
    end
  end

  # [[id, nom, lon, lat], …] pour une table de lieux, dans l'ordre du catalogue.
  def self.locate(table)
    missing = []
    located = table.map do |id, name, ascii, code, lat, lon|
      found = populated[[ code, ascii ]] if ascii
      missing << id if found.nil? && lat.nil?
      found ? [ id, name, found[0], found[1] ] : [ id, name, lon, lat ]
    end
    raise "lieux introuvables dans Natural Earth et sans repli : #{missing.join(' ')}" unless missing.empty?

    located
  end

  # --- Mise à l'échelle ------------------------------------------------------------------------------------------------

  # Calcule l'échelle qui fait entrer les points projetés dans width×height (marge incluse), nord en haut, centrée.
  class Fit
    def initialize(points, width, height, margin)
      xs = points.map(&:first)
      ys = points.map(&:last)
      @min_x = xs.min
      @max_y = ys.max
      span_x = xs.max - @min_x
      span_y = @max_y - ys.min
      @scale = [ (width - 2 * margin) / span_x, (height - 2 * margin) / span_y ].min
      @dx = (width - span_x * @scale) / 2
      @dy = (height - span_y * @scale) / 2
    end

    def call(x, y) = [ (x - @min_x) * @scale + @dx, (@max_y - y) * @scale + @dy ]
  end

  # --- Un fond ---------------------------------------------------------------------------------------------------------------

  # shapes : { id => { name:, polygons: [[anneaux]] } } en longitude-latitude ; renvoie le texte du module.
  Base = Struct.new(:key, :viewbox, :project, :margin, :shapes, :outline, :places, :continents, :tolerance, :min_area, keyword_init: true)

  def self.projected(polygons, fit, project)
    polygons.map { |rings| rings.map { |ring| ring.map { |lon, lat| fit.call(*project.call(lon, lat)) } } }
  end

  # Un rectangle (le cadre) découpe un anneau projeté : les voisins qui débordent ne sortent pas du viewBox.
  def self.clip_to_frame(polygons, width, height)
    frame = [ [ 0.0, 0.0 ], [ width.to_f, 0.0 ], [ width.to_f, height.to_f ], [ 0.0, height.to_f ] ]
    polygons.filter_map do |rings|
      clipped = rings.filter_map { |ring| (c = intersect_convex(ring, frame)).size >= 3 ? c : nil }
      clipped unless clipped.empty?
    end
  end

  def self.build(base)
    width, height = base.viewbox
    all = base.shapes.values.flat_map { |shape| shape[:polygons].flatten(2) }
    fit = Fit.new(all.map { |lon, lat| base.project.call(lon, lat) }, width, height, base.margin)
    tolerance = base.tolerance
    key = base.key
    20.times do
      text = module_text(base, fit, tolerance)
      size = text.bytesize
      warn format("%-14s tolérance %.2f : %6.1f Ko", key, tolerance, size / 1024.0)
      return text if size <= TARGET

      tolerance *= 1.2
    end
    raise "#{key} : impossible de tenir dans #{TARGET} octets"
  end

  def self.module_text(base, fit, tolerance)
    width, height = base.viewbox
    project = base.project
    areas = base.shapes.map do |id, shape|
      path = shape_path(projected(shape[:polygons], fit, project), tolerance, base.min_area)
      raise "aire vide : #{id}" if path.empty?

      "  #{id}: { name: #{shape[:name].to_json}, d: #{path.to_json} },"
    end
    outline = base.outline.map do |polygons|
      path = shape_path(clip_to_frame(projected(polygons, fit, project), width, height), tolerance, base.min_area)
      "  #{path.to_json}," unless path.empty?
    end.compact
    places = base.places.map do |id, name, lon, lat|
      x, y = fit.call(*project.call(lon, lat))
      "  #{id}: { name: #{name.to_json}, x: #{x.round(1)}, y: #{y.round(1)} },"
    end

    lines = header(base.key)
    lines << "export const VIEWBOX = [#{width}, #{height}]"
    lines << "export const ATTRIBUTION = #{ATTRIBUTIONS.fetch(base.key, '').to_json}"
    lines << (outline.empty? ? "export const OUTLINE = []" : "export const OUTLINE = [\n#{outline.join("\n")}\n]")
    lines << "export const AREAS = {\n#{areas.join("\n")}\n}"
    if base.continents
      names = base.continents.keys.to_h { |id| [ id, CONTINENTS.values.to_h.fetch(id) ] }
      lines << "export const CONTINENT_NAMES = #{names.to_json}"
      lines << "export const CONTINENTS = {\n#{base.continents.map { |id, members| "  #{id}: #{members.to_json}," }.join("\n")}\n}"
    end
    lines << "export const PLACES = {\n#{places.join("\n")}\n}"
    "#{lines.join("\n")}\n"
  end

  def self.header(key)
    [ "// ⚡ FRONT · lib/figures/maps/#{key} — fond de carte « #{key} » de la figure `map` : chemins SVG déjà projetés, noms français",
      "// Rôle : AREAS (aires nommées), PLACES (lieux), OUTLINE (tracés sans identifiant) ; généré par script/contenus/fonds_de_carte.rb, ne pas modifier à la main",
      "// ADR  : 0117-figures-des-matieres-de-3eme (§4.3) · UDR : 0142-dessin-des-figures-de-3eme (§3) · chargé par import() depuis lib/figures/map",
      "" ]
  end

  # --- Les trois fonds ---------------------------------------------------------------------------------------------------

  def self.world_like(source_name, ids, drawn_without_id: [], merge_into: {})
    countries = {}
    outline = []
    source(source_name)["features"].each do |feature|
      p = feature["properties"]
      id = iso(p)
      next if id == "ata"

      geometry = polygons(feature["geometry"])
      host = merge_into.fetch(id, id)
      if ids.include?(host)
        entry = countries[host] ||= { name: NAME_FIXES.fetch(host) { p["NAME_FR"] }, polygons: [], continent: p["CONTINENT"] }
        entry[:polygons].concat(geometry)
        entry[:name] = NAME_FIXES.fetch(host) { p["NAME_FR"] } if host == id
      elsif drawn_without_id.include?(id)
        outline << geometry
      end
    end
    [ countries, outline ]
  end

  def self.world
    ids = CATALOGS.areas("world") - CONTINENTS.values.map(&:first)
    countries, = world_like("world", ids, merge_into: { "cyn" => "cyp", "sol" => "som" })
    continents = CONTINENTS.to_h { |_, (id, _)| [ id, [] ] }
    countries.each { |id, shape| (c = CONTINENTS[shape[:continent]]) && continents[c[0]] << id }
    shapes = ids.to_h { |id| [ id, countries.fetch(id).slice(:name, :polygons) ] }
    Base.new(key: "world", viewbox: [ 640, 360 ], project: method(:equal_earth), margin: 6, shapes:, outline: [], places: locate(WORLD_PLACES),
             continents: continents.transform_values(&:sort), tolerance: 0.07, min_area: 0.9)
  end

  def self.africa
    ids = CATALOGS.areas("africa")
    countries, outline = world_like("africa", ids, drawn_without_id: %w[esh sol])
    shapes = ids.to_h { |id| [ id, countries.fetch(id).slice(:name, :polygons) ] }
    Base.new(key: "africa", viewbox: [ 640, 640 ], project: method(:equal_earth), margin: 10, shapes:, outline:, places: locate(AFRICA_PLACES),
             continents: nil, tolerance: 0.1, min_area: 1.2)
  end

  # Les zones naturelles : cellules convexes (longitude, latitude), prioritaires dans l'ordre, découpées sur le contour du pays.
  def self.zones(country)
    coast = coast_top(country)
    cells = [
      [ "coastal_strip", [ coast ] ],
      [ "mountain_west", [ [ [ -9.0, 6.6 ], [ -7.6, 6.6 ], [ -6.9, 7.3 ], [ -6.9, 8.4 ], [ -9.0, 8.4 ] ] ] ],
      [ "savanna", [ [ [ -9.0, 8.0 ], [ -1.0, 8.0 ], [ -1.0, 11.5 ], [ -9.0, 11.5 ] ], [ [ -5.6, 8.0 ], [ -5.1, 6.8 ], [ -4.6, 8.0 ] ] ] ]
    ]
    remaining = [ ccw(country) ]
    found = Hash.new { |h, k| h[k] = [] }
    cells.each do |zone, polys|
      polys.each do |cell|
        next_remaining = []
        remaining.each do |poly|
          inside = intersect_convex(poly, cell)
          found[zone] << inside if inside.size >= 3 && area(inside).abs > 1e-9
          next_remaining.concat(difference_convex(poly, cell))
        end
        remaining = next_remaining
      end
    end
    found["dense_forest"] = remaining
    found.transform_values { |polys| merge(polys) }
  end

  # La bande littorale : tout ce qui est sous la côte relevée de 0,23° (≈ 25 km), en polygone convexe.
  def self.coast_top(country)
    tops = (-7.5..-3.0).step(0.25).filter_map do |lon|
      lats = country.each_with_index.filter_map do |(x1, y1), i|
        x2, y2 = country[(i + 1) % country.size]
        next unless (x1 - lon) * (x2 - lon) <= 0 && x1 != x2

        y1 + (y2 - y1) * (lon - x1) / (x2 - x1)
      end
      [ lon, lats.min + 0.23 ] if lats.any? && lats.min < 5.8
    end
    hull(tops + [ [ -9.5, tops.first[1] ], [ -1.5, tops.last[1] ], [ -9.5, 3.0 ], [ -1.5, 3.0 ] ])
  end

  def self.cote_d_ivoire
    districts = source("districts")["features"].to_h do |feature|
      id, name = DISTRICTS.fetch(feature["properties"]["shapeName"])
      [ id, { name:, polygons: polygons(feature["geometry"]) } ]
    end
    nature = source("africa")["features"]
    country = nature.find { |f| iso(f["properties"]) == "civ" }
    outer = polygons(country["geometry"]).map(&:first).max_by { |ring| area(ring).abs }
    zones = zones(outer).to_h { |id, rings| [ id, { name: ZONES.fetch(id), polygons: rings.map { |ring| [ ring ] } } ] }
    shapes = (CATALOGS.areas("cote_d_ivoire")).to_h { |id| [ id, districts[id] || zones.fetch(id) ] }
    neighbours = nature.filter_map { |f| polygons(f["geometry"]) if %w[mli bfa gha gin lbr].include?(iso(f["properties"])) }
    all = shapes.values.flat_map { |s| s[:polygons].flatten(2) }
    lat0 = (all.map(&:last).minmax.sum) / 2
    Base.new(key: "cote_d_ivoire", viewbox: [ 640, 640 ], project: plate_carree(lat0), margin: 14, shapes:, outline: neighbours,
             places: locate(CI_PLACES), continents: nil, tolerance: 0.12, min_area: 1.0)
  end

  def self.check_parity(base)
    expected_areas = CATALOGS.areas(base.key)
    got = base.shapes.keys + (base.continents&.keys || [])
    raise "#{base.key} : aires #{(expected_areas - got).inspect} manquantes, #{(got - expected_areas).inspect} en trop" unless expected_areas.sort == got.sort

    ids = base.places.map(&:first)
    expected = CATALOGS.places(base.key)
    raise "#{base.key} : lieux #{(expected - ids).inspect} manquants, #{(ids - expected).inspect} en trop" unless expected.sort == ids.sort
  end

  def self.run(keys)
    FileUtils.mkdir_p(OUT)
    keys = %w[cote_d_ivoire africa world] if keys.empty?
    keys.each do |key|
      base = public_send(key)
      check_parity(base)
      text = build(base)
      File.write(File.join(OUT, "#{key}.js"), text)
      raise "#{key} : #{text.bytesize} octets, plus que le budget de #{BUDGET}" if text.bytesize > BUDGET

      puts "#{key}.js : #{(text.bytesize / 1024.0).round(1)} Ko"
    end
  end
end

FondsDeCarte.run(ARGV) if $PROGRAM_NAME == __FILE__

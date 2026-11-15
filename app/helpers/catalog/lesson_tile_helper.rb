# 🌐 UI · Catalog::LessonTileHelper — la tuile d'une leçon sur la vue d'une matière de l'élève : numéro, libellé court, pictogramme calculé
# Rôle : l'icône d'une leçon n'est jamais saisie (aucune colonne) : un jeu fini de pictogrammes, des règles par mots-clés sur le titre, par matière, puis l'illustration de la matière en repli
# UDR  : XXXX écrans minimalistes style Wave §3 (matière : grille de tuiles, icône calculée)
module Catalog::LessonTileHelper
  # Pictogrammes (viewBox 28, trait) et teinte de leur pastille (tokens `tint-*`, qui ont leur valeur sombre).
  LESSON_ICONS = {
    "vector" => [ "bg-tint-indigo", '<path d="M5 22L22 7M22 7h-7M22 7v7"/>' ],
    "numbers" => [ "bg-tint-lilac", '<path d="M10 5l-2 18M18 5l-2 18M5 11h18M4 17h18"/>' ],
    "geometry" => [ "bg-tint-green", '<path d="M14 5L4 23h20z"/><path d="M14 5v18" opacity=".5"/>' ],
    "curve" => [ "bg-tint-yellow", '<path d="M4 4v20h20"/><path d="M7 20c4-1 5-12 9-12s3 6 7 7"/>' ],
    "equals" => [ "bg-tint-pink", '<path d="M5 10h18M5 18h18"/>' ],
    "dice" => [ "bg-tint-lavender", '<rect x="5" y="5" width="18" height="18" rx="4"/><path d="M10.5 10.5h.01M14 14h.01M17.5 17.5h.01"/>' ],
    "bolt" => [ "bg-tint-yellow", '<path d="M15 4L7 16h6l-1 8 9-13h-6z"/>' ],
    "motion" => [ "bg-tint-indigo", '<circle cx="14" cy="14" r="4"/><path d="M14 3v4M14 21v4M3 14h4M21 14h4M6 6l3 3M19 19l3 3M22 6l-3 3M9 19l-3 3"/>' ],
    "light" => [ "bg-tint-yellow", '<path d="M10 20h8M11 24h6M14 3a7 7 0 00-4 12.7V18h8v-2.3A7 7 0 0014 3z"/>' ],
    "flask" => [ "bg-tint-lilac", '<path d="M11 4h6M12 4v7L5 22a2 2 0 002 3h14a2 2 0 002-3l-7-11V4"/><path d="M8 18h12"/>' ],
    "leaf" => [ "bg-tint-green", '<path d="M5 23C5 12 11 5 23 5c0 12-6 18-18 18z"/><path d="M5 23L15 13"/>' ],
    "dna" => [ "bg-tint-pink", '<path d="M9 4c0 6 10 6 10 12s-10 6-10 8M19 4c0 6-10 6-10 12s10 6 10 8"/><path d="M10 9h8M10 19h8"/>' ],
    "body" => [ "bg-tint-red", '<path d="M14 24S4 18 4 11a5 5 0 0110-2 5 5 0 0110 2c0 7-10 13-10 13z"/>' ],
    "earth" => [ "bg-tint-green", '<circle cx="14" cy="14" r="10"/><path d="M4 14h20M14 4c-5 5-5 15 0 20M14 4c5 5 5 15 0 20"/>' ],
    "pen" => [ "bg-tint-lavender", '<path d="M5 23l1-5L19 5l4 4L10 22z"/><path d="M16 8l4 4"/>' ],
    "speech" => [ "bg-tint-indigo", '<path d="M5 6h18v12H12l-5 5v-5H5z"/>' ],
    "book" => [ "bg-tint-yellow", '<path d="M14 7C11 5 7 5 4 6v15c3-1 7-1 10 1 3-2 7-2 10-1V6c-3-1-7-1-10 1zM14 7v15"/>' ],
    "hourglass" => [ "bg-tint-pink", '<path d="M8 4h12M8 24h12M9 4c0 6 5 7 5 10s-5 4-5 10M19 4c0 6-5 7-5 10s5 4 5 10"/>' ],
    "map" => [ "bg-tint-lavender", '<path d="M4 8l6-3 8 3 6-3v15l-6 3-8-3-6 3zM10 5v15M18 8v15"/>' ],
    "scales" => [ "bg-tint-pink", '<path d="M14 5v18M8 23h12M5 9h18M5 9l-3 8a4 4 0 006 0zM23 9l-3 8a4 4 0 006 0z"/>' ],
    "shield" => [ "bg-tint-indigo", '<path d="M14 4l9 3v7c0 6-4 9-9 11-5-2-9-5-9-11V7z"/>' ],
    "thought" => [ "bg-tint-lilac", '<circle cx="14" cy="11" r="8"/><path d="M12 9a2 2 0 112.5 2c-.6.3-.5 1-.5 2M14 16v.5M10 19l-2 5 6-3"/>' ]
  }.freeze

  # Les règles, par matière, dans l'ordre : la première qui trouve un de ses mots dans le titre (sans accents, en minuscules,
  # ponctuation en espaces) donne le pictogramme. Un mot ou un pictogramme de plus : une ligne ici, un exemple au test.
  LESSON_ICON_RULES = {
    "mathematiques" => [
      [ "equals", /equation|inequation|calcul litteral|calcul numerique|racine/ ],
      [ "curve", /fonction|limite|deriv|primitive|integr|logarithm|continuite/ ],
      [ "dice", /probabilit|variable aleatoire|denombrement/ ],
      [ "vector", /vecteur|translation|barycentre/ ],
      [ "geometry", /triangle|thales|angle|droite|segment|point|symetri|geometr|trigonom/ ],
      [ "numbers", /nombre|reel|entier|decimal|rationnel|premier|divisib|relatif/ ]
    ],
    "physique-chimie" => [
      [ "bolt", /circuit|generateur|lampe|pile|dipole|resistor|electri|recepteur/ ],
      [ "light", /lumiere|lune|eclipse|source/ ],
      [ "flask", /alcane|alcene|alcool|organique|hydrocarbure|chimique|atome|compose/ ],
      [ "motion", /force|mouvement|cinemat|travail|puissance|equilibre|masse|poids|solide|inertie/ ]
    ],
    "svt" => [
      [ "leaf", /plante|sels mineraux|croissance|spermaphyte|fleur|absorption/ ],
      [ "dna", /gamet|meio|chromosom|heredit|caractere|cellule|origine de la vie|genetique/ ],
      [ "earth", /environnement|criquet|moustique|roche|degradation|ensembles/ ],
      [ "body", /sang|digestion|aliment|corps|organe|cerebr|nerveu|hormon|reflexe|emotion|drogue|cycle|gonade|sexuel|transformation/ ]
    ],
    "francais" => [
      [ "speech", /oral|expose|debat|dialogue|communication/ ],
      [ "book", /oeuvre|poetique|narrative|roman|lecture/ ],
      [ "pen", /dissertation|commentaire|texte|resume|lettre|portrait|phrase|groupe|redaction/ ]
    ],
    "histoire-geographie" => [
      [ "map", /geographie|milieu|demograph|deconcentration|atouts|fondements|developpement/ ],
      [ "hourglass", /histoire|independance|bipolarisation|onu|revolution|capitalisme|colonisation|imperialiste|siecle|peuples|migratoire|habitants|sources|methodes/ ]
    ],
    "edhc" => [
      [ "scales", /droit|humanitaire|discrimin|violence|protection|victime|devoir|enfant|soldat/ ],
      [ "shield", /organisation|principe|instrument|mecanisme/ ]
    ],
    "philosophie" => [
      [ "pen", /dissertation|redaction|commentaire|lecture|methode|texte/ ],
      [ "thought", /connaissance|homme/ ]
    ]
  }.freeze

  SHORT_TITLE_CUT = /\s+(?:et|ou)\s+|\s*[:—,]\s*|\s+-\s+/
  SHORT_TITLE_MIN = 4

  # → une clé de LESSON_ICONS, ou nil (la vue reprend alors l'illustration de la matière)
  def lesson_icon_key(material_slug:, name:)
    text = I18n.transliterate(name.to_s.downcase).gsub(/[^a-z0-9]+/, " ")
    LESSON_ICON_RULES.fetch(material_slug.to_s, []).find { |_, words| words.match?(text) }&.first
  end

  # La pastille et son pictogramme (trait, couleur du texte bleu) ; sans règle, l'illustration de la matière.
  def lesson_icon(material_slug:, name:)
    key = lesson_icon_key(material_slug:, name:)
    tint, paths = LESSON_ICONS[key]
    return image_tag(subject_illustration(material_slug).path, alt: "", class: "size-7") unless key

    tag.svg(paths.html_safe, viewBox: "0 0 28 28", class: "size-7", fill: "none", stroke: "currentColor", "stroke-width": 2, # rubocop:disable Rails/OutputSafety -- constante du dépôt, jamais une saisie
                             "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": "true", focusable: "false", data: { icon: key, tint: })
  end

  def lesson_icon_tint(material_slug:, name:)
    key = lesson_icon_key(material_slug:, name:)
    key ? LESSON_ICONS.fetch(key).first : subject_illustration(material_slug).tint
  end

  # « Vecteurs et points du plan » → « Vecteurs » ; le titre entier si la coupe laisse moins de 4 lettres.
  def lesson_short_title(name)
    first = name.to_s.split(SHORT_TITLE_CUT, 2).first.to_s.strip
    first.size >= SHORT_TITLE_MIN ? first : name.to_s
  end

  # « Leçon 3 — progression DPFC 2026-2027 » → 3 ; nil sans numéro.
  def lesson_number(subtitle) = subtitle.to_s[/le[cç]on\s+(\d+)/i, 1]&.to_i

  # « Progression DPFC 2026-2027 », la partie qui suit le numéro ; nil sans elle.
  def lesson_progression(subtitle) = subtitle.to_s.split(/\s+[—–-]\s+/, 2)[1].presence&.upcase_first
end

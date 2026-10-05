require "test_helper"

# ADR-0081 §4.3, AV-09 : un SVG de l'équipe n'atteint jamais la page tel qu'il a été envoyé. Le lecteur le lit en XML
# strict, sans réseau ni DTD, refuse tout ce qui peut s'exécuter ou charger quelque chose, et ne rend que les formes
# de la liste blanche avec leurs attributs géométriques. Chaque vecteur refusé a son fichier dans
# test/fixtures/files/illustrations, que le challenger téléverse aussi par la page de l'équipe.
module Communication
  class DrawingReaderTest < ActiveSupport::TestCase
    ILLUSTRATION = Entities::Communication::Illustration
    SQUARE = { "name" => "path", "attributes" => { "d" => "M8 8h48v48H8z" }, "children" => [] }.freeze

    # Fichier → vecteur. Chacun garde une forme valide et une viewBox : seul son vecteur le fait refuser.
    UNSAFE = {
      "script.svg" => "un élément script",
      "script_in_metadata.svg" => "un script caché dans les métadonnées, que la reconstruction ignorerait",
      "script_xhtml_namespace.svg" => "un script XHTML (html:script), qui s'exécute dans un document XML",
      "handler.svg" => "un gestionnaire SVG Tiny (handler)",
      "foreign_object.svg" => "un foreignObject",
      "style_element.svg" => "un élément style",
      "iframe.svg" => "une iframe XHTML (srcdoc)",
      "embed.svg" => "un embed XHTML",
      "image.svg" => "un élément image",
      "use.svg" => "un élément use",
      "anchor.svg" => "un lien a, même sans adresse",
      "animate.svg" => "une animation (animate)",
      "animate_transform.svg" => "une animation (animateTransform)",
      "set.svg" => "un set, qui pose un attribut à l'exécution",
      "onload.svg" => "un gestionnaire onload sur la racine",
      "onclick_shape.svg" => "un gestionnaire OnClick sur une forme gardée, en casse mêlée",
      "href.svg" => "un attribut href",
      "xlink_href.svg" => "un xlink:href (dégradé d'Inkscape)",
      "xinclude.svg" => "une inclusion XInclude d'un fichier local",
      "src_attribute.svg" => "une image XHTML qui charge une adresse externe (src)",
      "url_value.svg" => "url( dans une valeur",
      "url_in_style.svg" => "url( dans un style en attribut",
      "url_css_escape.svg" => "url( masqué par un échappement CSS (\\75 rl()",
      "javascript_value.svg" => "javascript: dans une valeur, en casse mêlée",
      "javascript_obfuscated.svg" => "javascript: masqué par des références de caractères (tabulation, saut de ligne, deux-points)",
      "doctype.svg" => "un DOCTYPE public (export d'Illustrator)",
      "billion_laughs.svg" => "un « billion laughs » (DOCTYPE et entités imbriquées)",
      "xxe.svg" => "une entité externe XXE (SYSTEM \"file:///etc/passwd\")",
      "xxe_parameter_entity.svg" => "une entité paramètre qui charge une DTD distante",
      "entity_reference.svg" => "une référence à une entité non déclarée (&nbsp;)",
      "processing_instruction.svg" => "une instruction de traitement xml-stylesheet",
      "too_many_shapes.svg" => "plus de 500 formes",
      "too_deep.svg" => "plus de 8 niveaux de groupes"
    }.freeze
    NOT_SVG = {
      "not_svg_root.svg" => "une page XHTML",
      "foreign_namespace.svg" => "une racine svg d'un autre espace de noms",
      "malformed.svg" => "un XML mal formé",
      "utf7.svg" => "un encodage déclaré autre qu'UTF-8 (UTF-7, qui cacherait des balises)"
    }.freeze
    EMPTY = {
      "empty_inkscape.svg" => "un document vierge d'Inkscape (calque vide)",
      "no_view_box.svg" => "des formes sans viewBox"
    }.freeze

    def read(bytes) = DrawingReader.new.read(bytes:)
    def read_fixture(name) = read(file_fixture("illustrations/#{name}").binread)
    def svg(body, root: %(xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64")) = "<svg #{root}>#{body}</svg>"
    def reason(result) = result.errors[:file]

    def assert_refused(expected, result, message = nil)
      assert result.failure?, message
      assert_equal :invalid, result.code, message
      assert_equal [ expected ], reason(result), message
    end

    def assert_all_shapes_valid(shapes)
      assert(shapes.all? { ILLUSTRATION.valid_shape?(it, depth: 1) }, shapes.inspect)
    end

    test "le lecteur est l'adaptateur du port" do
      assert_kind_of Ports::Communication::DrawingReaderPort, DrawingReader.new
    end

    test "AV-09 — XML strict, sans réseau : ni substitution d'entités, ni chargement de DTD, ni récupération d'erreur" do
      options = Nokogiri::XML::ParseOptions.new(DrawingReader::PARSE_OPTIONS)

      assert options.strict?
      assert options.nonet?
      assert_not options.noent?
      assert_not options.dtdload?
      assert_not options.dtdattr?
      assert_not options.huge?
      assert_not options.xinclude?
    end

    test "AV-09 — un dessin d'Inkscape est reconstruit sans ses métadonnées, sa vue d'éditeur, ses couleurs ni son texte" do
      result = read_fixture("inkscape_bus.svg")
      circle = ->(cx) { { "name" => "circle", "attributes" => { "cx" => cx, "cy" => "56", "r" => "5" }, "children" => [] } }
      ellipse = ->(cx) { { "name" => "ellipse", "attributes" => { "cx" => cx, "cy" => "45", "rx" => "3", "ry" => "2" }, "children" => [] } }
      body = "m 12,14 c 0,-2.2 1.8,-4 4,-4 h 40 c 2.2,0 4,1.8 4,4 v 38 c 0,1.1 -0.9,2 -2,2 H 14 c -1.1,0 -2,-0.9 -2,-2 z " \
             "m 4,4 v 14 h 40 V 18 Z"

      assert result.success?
      assert_equal "0 0 64 64", result.value[:view_box]
      assert_equal [ {
        "name" => "g", "attributes" => { "transform" => "translate(-4,-6)" }, "children" => [
          { "name" => "path", "attributes" => { "d" => body, "fill-rule" => "evenodd" }, "children" => [] },
          { "name" => "rect", "attributes" => { "width" => "12", "height" => "6", "x" => "26", "y" => "38", "ry" => "1" },
            "children" => [] },
          { "name" => "g", "attributes" => {}, "children" => [ circle.call("20"), circle.call("48") ] },
          ellipse.call("18"), ellipse.call("46")
        ]
      } ], result.value[:shapes]
      assert_all_shapes_valid result.value[:shapes]
      assert_no_match(/inkscape|sodipodi|rdf|metadata|title|style|fill:|#1a1a1a|class|ÉCOLE|text/i, result.value.to_s)
    end

    test "AV-09 — un pictogramme d'une seule couleur garde ses formes ; fill, aria-hidden et les autres attributs partent" do
      result = read_fixture("pictogram.svg")

      assert result.success?
      assert_equal "0 0 24 24", result.value[:view_box]
      assert_equal [
        { "name" => "polygon", "attributes" => { "points" => "12,2 15,9 22,9 16.5,13.5 18.5,21 12,16.5 5.5,21 7.5,13.5 2,9 9,9" },
          "children" => [] },
        { "name" => "polyline", "attributes" => { "points" => "2,23 22,23", "fill-rule" => "nonzero" }, "children" => [] },
        { "name" => "line", "attributes" => { "x1" => "12", "y1" => "16.5", "x2" => "12", "y2" => "23" }, "children" => [] }
      ], result.value[:shapes]
      assert_all_shapes_valid result.value[:shapes]
    end

    UNSAFE.each do |file, vector|
      test "AV-09 — #{file} est refusé (:unsafe) : #{vector}" do
        assert_refused :unsafe, read_fixture(file), vector
      end
    end

    NOT_SVG.each do |file, vector|
      test "AV-09 — #{file} n'est pas un dessin SVG (:not_svg) : #{vector}" do
        assert_refused :not_svg, read_fixture(file), vector
      end
    end

    EMPTY.each do |file, vector|
      test "#{file} est vide (:empty) : #{vector}" do
        assert_refused :empty, read_fixture(file), vector
      end
    end

    test "chaque fichier piégé de test/fixtures/files/illustrations a son test de refus" do
      fixtures = file_fixture_path.then { Pathname(it).join("illustrations").glob("*.svg").map { it.basename.to_s } }
      accepted = %w[inkscape_bus.svg pictogram.svg too_heavy.svg] # too_heavy : refusé au poids, avant le lecteur
      refused = fixtures - accepted

      assert_equal refused.sort, (UNSAFE.keys + NOT_SVG.keys + EMPTY.keys).sort
    end

    test "AV-09 — une image PNG, des octets qui ne sont pas de l'UTF-8 ou un fichier vide ne sont pas des dessins SVG" do
      assert_refused :not_svg, read(file_fixture("photos/photo.png").binread)
      assert_refused :not_svg, read("<svg>\xE9</svg>".b)
      assert_refused :not_svg, read("")
      assert_refused :not_svg, read("Bus & co")
    end

    test "AV-09 — un encodage déclaré autre qu'UTF-8 est refusé ; UTF-8 déclaré, en majuscules ou non, ou un BOM UTF-8 passent" do
      assert_refused :not_svg, read(%(<?xml version="1.0" encoding="ISO-8859-1"?>#{svg('<path d="M0 0h1v1z"/>')}))
      assert_refused :not_svg, read(%(<?xml version='1.0' encoding='utf-16'?>#{svg('<path d="M0 0h1v1z"/>')}))
      [ %(<?xml version="1.0" encoding="utf-8"?>), %(<?xml version='1.0' encoding='UTF-8'?>), "\xEF\xBB\xBF".b ].each do |head|
        assert read(head + svg('<path d="M0 0h1v1z"/>')).success?, head
      end
    end

    test "AV-09 — un document UTF-16 n'est pas lu comme un dessin, même avec un DOCTYPE qu'un examen octet par octet ne verrait pas" do
      utf16 = "﻿<!DOCTYPE svg [<!ENTITY a \"b\">]>#{svg('<title>&a;</title><path d="M0 0h1v1z"/>')}".encode("UTF-16LE")

      assert_refused :not_svg, read(utf16.b)
    end

    test "AV-09 — toute déclaration de DTD ou référence d'entité est refusée avant que libxml2 ne la lise ; &amp; et &#65; passent" do
      [ "<!ELEMENT svg ANY>", "<!ATTLIST svg a CDATA #FIXED 'x'>", "<!NOTATION n SYSTEM 'x'>", "&ent;", "&ampx;" ].each do |trap|
        assert_refused :unsafe, read(svg("<title>#{trap}</title><path d=\"M0 0h1v1z\"/>")), trap
      end
      assert read(svg('<title>A &amp; B &lt; &gt; &quot; &apos; &#65; &#x41;</title><path d="M0 0h1v1z"/>')).success?
    end

    test "AV-09 — une instruction de traitement est refusée où qu'elle soit, la déclaration XML seule est permise" do
      assert_refused :unsafe, read(svg('<?php echo 1 ?><path d="M0 0h1v1z"/>'))
      assert read(%(<?xml version="1.0"?>#{svg('<path d="M0 0h1v1z"/>')})).success?
    end

    test "AV-09 — un élément interdit est refusé quels que soient son espace de noms et sa casse" do
      %w[svg:script SCRIPT foreignobject html:object html:frame listener html:frameset animateMotion].each do |name|
        head = %(xmlns="http://www.w3.org/2000/svg" xmlns:svg="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml" viewBox="0 0 64 64")

        assert_refused :unsafe, read(svg("<#{name}/><path d=\"M0 0h1v1z\"/>", root: head)), name
      end
    end

    test "AV-09 — un attribut on*, href ou src est refusé quels que soient son espace de noms et sa casse" do
      %w[ONLOAD onfocusin x:onclick HREF x:href SRC].each do |name|
        head = %(xmlns="http://www.w3.org/2000/svg" xmlns:x="urn:x" viewBox="0 0 64 64")

        assert_refused :unsafe, read(svg("<path #{name}=\"a\" d=\"M0 0h1v1z\"/>", root: head)), name
      end
    end

    # Un préfixe non déclaré laisse le nom entier (« x:script ») à l'élément ou à l'attribut : le nom local, après « : »,
    # est comparé aussi.
    test "AV-09 — <x:script/> est refusé, que son préfixe soit déclaré ou non" do
      [ "", ' xmlns:x="urn:x"' ].each do |declaration|
        assert_refused :unsafe, read(svg('<x:script/><path d="M0 0h1v1z"/>', root: %(viewBox="0 0 64 64"#{declaration}))), declaration
      end
    end

    test "AV-09 — x:onload est refusé, que son préfixe soit déclaré ou non" do
      [ "", ' xmlns:x="urn:x"' ].each do |declaration|
        assert_refused :unsafe, read(svg('<path x:onload="a" d="M0 0h1v1z"/>', root: %(viewBox="0 0 64 64"#{declaration}))), declaration
      end
    end

    test "AV-09 — x:href et x:foreignObject sont refusés sous un préfixe non déclaré" do
      assert_refused :unsafe, read(svg('<path x:href="a" d="M0 0h1v1z"/>', root: 'viewBox="0 0 64 64"'))
      assert_refused :unsafe, read(svg('<x:foreignObject/><path d="M0 0h1v1z"/>', root: 'viewBox="0 0 64 64"'))
    end

    test "AV-09 — une valeur refusée l'est sur tout élément, même ignoré, et dans une déclaration d'espace de noms" do
      [ '<desc class="vbscript:msgbox(1)"/>', '<metadata id="u r l (x)"/>', '<title lang="&#x6A;avascript&#x3A;x"/>',
        '<g xmlns:x="javascript:alert(1)"/>', '<path d="M0 0h1v1z" style="fill:\\55\\52\\4C(#a)"/>',
        "<path d=\"M0 0h1v1z\" style=\"fill:u\\rl(#a)\"/>", "<path d=\"M0 0h1v1z\" data-x=\"java​script:\"/>" ].each do |trap|
        assert_refused :unsafe, read(svg("#{trap}<path d=\"M0 0h1v1z\"/>")), trap
      end
    end

    test "AV-09 — un attribut hors liste blanche, d'un autre espace de noms ou hors de son expression n'est pas gardé" do
      head = %(xmlns="http://www.w3.org/2000/svg" xmlns:f="urn:f" viewBox="0 0 64 64")
      result = read(svg('<rect f:x="9" x="1" y="1e2" width="2" height="2" fill="red" id="r" cx="3" rx="bad"/>' \
                        '<path d="M0 0 L 1 1 &quot;" transform="translate(1,2) scale(2)"/>', root: head))

      assert_equal [ { "name" => "rect", "attributes" => { "x" => "1", "y" => "1e2", "width" => "2", "height" => "2" }, "children" => [] },
                     { "name" => "path", "attributes" => { "transform" => "translate(1,2) scale(2)" }, "children" => [] } ],
                   result.value[:shapes]
    end

    test "AV-09 — seules les formes de l'espace SVG sont gardées ; une racine sans espace de noms garde les siennes" do
      head = %(xmlns="http://www.w3.org/2000/svg" xmlns:f="urn:f" viewBox="0 0 64 64")

      assert_equal [ SQUARE ], read(svg('<f:path d="M0 0h1v1z"/><path d="M8 8h48v48H8z"/>', root: head)).value[:shapes]
      assert_equal [ SQUARE ], read(svg('<path d="M8 8h48v48H8z"/>', root: 'viewBox="0 0 64 64"')).value[:shapes]
      assert_equal [ SQUARE ], read(%(<s:svg xmlns:s="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><s:path d="M8 8h48v48H8z"/></s:svg>))
        .value[:shapes]
    end

    test "les enfants d'une forme qui n'est pas un groupe, et le contenu d'un élément ignoré, ne sont pas gardés" do
      body = '<path d="M8 8h48v48H8z"><rect width="1" height="1"/></path><defs><circle r="2"/></defs>' \
             '<switch><circle r="3"/></switch><svg><circle r="4"/></svg>'

      assert_equal [ SQUARE ], read(svg(body)).value[:shapes]
    end

    test "un groupe sans forme gardée disparaît ; un groupe qui en garde une reste, avec ses attributs" do
      body = '<g transform="rotate(45)"><g><title>vide</title></g><path d="M8 8h48v48H8z"/></g><g/>'

      assert_equal [ { "name" => "g", "attributes" => { "transform" => "rotate(45)" }, "children" => [ SQUARE ] } ],
                   read(svg(body)).value[:shapes]
    end

    test "500 formes et 8 niveaux sont permis : la limite est comprise" do
      flat = read(svg(Array.new(500) { '<rect width="1" height="1"/>' }.join))
      deep = read(svg("#{'<g>' * 7}<path d=\"M8 8h48v48H8z\"/>#{'</g>' * 7}"))

      assert_equal 500, flat.value[:shapes].size
      assert deep.success?
      assert_all_shapes_valid deep.value[:shapes]
    end

    test "les groupes comptent parmi les 500 formes, et un groupe vide trop profond est refusé avant d'être écarté" do
      assert_refused :unsafe, read(svg("<g>#{Array.new(500) { '<rect width="1" height="1"/>' }.join}</g>"))
      assert_refused :unsafe, read(svg("#{'<g>' * 9}#{'</g>' * 9}<path d=\"M8 8h48v48H8z\"/>"))
    end

    test "une viewBox est exigée, conforme à son expression, de largeur et de hauteur positives et finies" do
      [ "0 0 64", "0 0 64 64 64", "0 0 0 64", "0 0 64 -1", "0 0 1e999 64", "a b c d", "" ].each do |view_box|
        assert_refused :empty, read(svg('<path d="M0 0h1v1z"/>', root: %(xmlns="http://www.w3.org/2000/svg" viewBox="#{view_box}"))), view_box
      end
      [ "0,0,64,64", "-10 -10 20.5 .5", " 0 0 1. 1e2 " ].each do |view_box|
        assert_equal view_box, read(svg('<path d="M0 0h1v1z"/>', root: %(viewBox="#{view_box}"))).value[:view_box], view_box
      end
    end

    test "une viewBox d'un autre espace de noms ne compte pas" do
      root = %(xmlns="http://www.w3.org/2000/svg" xmlns:f="urn:f" f:viewBox="0 0 64 64")

      assert_refused :empty, read(svg('<path d="M0 0h1v1z"/>', root:))
    end

    test "une racine qui n'est pas svg, ou sans forme permise, est refusée" do
      assert_refused :not_svg, read('<path xmlns="http://www.w3.org/2000/svg" d="M0 0h1v1z"/>')
      assert_refused :empty, read(svg("<text>Bus</text>"))
    end
  end
end

require "test_helper"

module Entities
  module Catalog
    # ADR-0110 (contenu-en-blocs) : le document d'une fiche de cours se lit comme un fichier hostile.
    class SheetDocumentTest < ActiveSupport::TestCase
      REFERENCE = Rails.root.join("test/fixtures/files/course_sheets/reference.json")

      def reference = JSON.parse(REFERENCE.read)

      # Le document de référence, modifié à un endroit : le bloc `n` de la section `s` de la page `p` (0 pour le premier).
      def with_block(page: 0, section: 0, position: 0, &)
        document = reference
        block = document.dig("pages", page, "sections", section, "blocks", position)
        yield block
        document
      end

      def errors_of(document) = SheetDocument.new(document).errors

      def reasons(document) = errors_of(document).map(&:reason)

      test "le document de référence est valide" do
        sheet = SheetDocument.new(reference)

        assert_predicate sheet, :valid?
        assert_empty sheet.errors
        assert_equal 3, sheet.pages.size
        assert_equal %w[hypothese paralleles secantes], sheet.glossary.keys.sort
      end

      test "tous les types et tous les kinds de la liste fermée sont portés par la référence" do
        types = reference["pages"].flat_map { it["sections"] }.flat_map { it["blocks"] }
        assert_equal SheetDocument::BLOCK_TYPES.sort, types.map { it["type"] }.uniq.sort
        assert_equal (SheetDocument::MEDIA_KINDS + SheetDocument::FIGURE_KINDS + SheetDocument::GENERATOR_KINDS).sort,
                     types.filter_map { it["kind"] }.sort
      end

      test "les listes fermées" do
        assert_equal %w[paragraph box simple steps table figure media exercise practice writing], SheetDocument::BLOCK_TYPES
        assert_equal %w[thales_figure lens_simulator lens_construction argument_highlighter], SheetDocument::MEDIA_KINDS
        assert_equal %w[lens_diagrams], SheetDocument::FIGURE_KINDS
        assert_equal %w[thales_ratio bank], SheetDocument::GENERATOR_KINDS
      end

      test "accepte des clés symboles" do
        assert_predicate SheetDocument.new(reference.deep_symbolize_keys), :valid?
      end

      test "refuse du HTML dans n'importe quelle chaîne, et dit où" do
        document = with_block(page: 0, section: 1, position: 0) { it["caption"] = "<script>alert(1)</script>" }
        error = errors_of(document).first

        assert_equal :html_forbidden, error.reason
        assert_equal [ 1, 2, 1 ], [ error.page, error.section, error.position ]
      end

      test "refuse du HTML dans le lexique, l'en-tête et un champ d'exercice" do
        glossary = reference.merge("glossary" => reference["glossary"].merge("x" => [ "<b>", "d", "" ]))
        assert_includes reasons(glossary), :html_forbidden

        header = reference.tap { it["pages"][0]["header"]["title"] = "<i>" }
        assert_includes reasons(header), :html_forbidden

        field = with_block(page: 2, section: 0, position: 0) { it["fields"][0]["label"] = "a<b" }
        assert_includes reasons(field), :html_forbidden
      end

      test "refuse toute URL" do
        [ "https://exemple.org/x", "http://a.b", "ftp://a", "www.exemple.org", "WWW.exemple.org", "mailto:a@b.c", "javascript:alert(1)", "data:text/html,x" ].each do |url|
          document = with_block { it["text"] = "Voir #{url}" }
          assert_includes reasons(document), :url_forbidden, url
        end
      end

      test "refuse un kind inconnu et un type inconnu" do
        assert_includes reasons(with_block(page: 0, section: 1, position: 0) { it["kind"] = "inconnu" }), :unknown_kind
        assert_includes reasons(with_block { it["type"] = "iframe" }), :unknown_type
        assert_includes reasons(with_block(page: 1, section: 0, position: 2) { it["kind"] = "thales_figure" }), :unknown_kind
        assert_includes reasons(with_block(page: 2, section: 1, position: 0) { it["kind"] = "lens_diagrams" }), :unknown_kind
      end

      test "refuse un mot du lexique absent, et un balisage mal formé" do
        error = errors_of(with_block { it["text"] = "Voir [[absent|mot]]." }).first
        assert_equal :unknown_glossary_key, error.reason
        assert_equal [ 1, 1, 1 ], [ error.page, error.section, error.position ]

        assert_includes reasons(with_block { it["text"] = "Voir [[secantes mot]]." }), :malformed_mark
        assert_includes reasons(with_block { it["text"] = "Voir [[secantes|]]." }), :malformed_mark
        assert_includes reasons(with_block { it["text"] = "Un $ seul." }), :unbalanced_math
      end

      test "refuse un lexique mal formé" do
        bad_key = reference.merge("glossary" => { "Mot Clé" => [ "t", "d", "" ] })
        assert_includes reasons(bad_key), :invalid_glossary_key

        bad_entry = reference.merge("glossary" => reference["glossary"].merge("x" => [ "t", "d" ]))
        assert_includes reasons(bad_entry), :wrong_type

        assert_includes reasons(reference.merge("glossary" => [])), :wrong_type
        assert_includes reasons(reference.except("glossary")), :missing_key
      end

      test "refuse une clé inconnue, un type de valeur faux, une clé manquante" do
        assert_includes reasons(with_block { it["onclick"] = "x" }), :unknown_key
        assert_includes reasons(with_block { it["text"] = 12 }), :wrong_type
        assert_includes reasons(with_block { it.delete("text") }), :missing_key
        assert_includes reasons(with_block { it["text"] = "" }), :blank
        assert_includes reasons(reference.merge("extra" => 1)), :unknown_key
        assert_equal [ :wrong_type ], reasons([])
        assert_equal [ :wrong_type ], reasons(nil)
      end

      test "refuse une structure qui n'est pas pages, sections, blocs" do
        assert_includes reasons(reference.merge("pages" => [])), :blank
        assert_includes reasons(reference.merge("pages" => "x")), :wrong_type
        assert_includes reasons(reference.tap { it["pages"][0]["sections"] = [] }), :blank
        assert_includes reasons(reference.tap { it["pages"][0]["sections"][0]["blocks"] = [] }), :blank
        assert_includes reasons(reference.tap { it["pages"][0] = "x" }), :wrong_type
        assert_includes reasons(reference.tap { it["pages"][0]["sections"][0] = 3 }), :wrong_type
        assert_includes reasons(reference.tap { it["pages"][0]["sections"][0]["blocks"][0] = 3 }), :wrong_type
        assert_includes reasons(reference.tap { it["pages"][0]["sections"][0].delete("title") }), :missing_key
      end

      test "borne le nombre de pages, de sections, de blocs et de champs" do
        page = reference["pages"][0]
        assert_includes reasons(reference.merge("pages" => [ page ] * (SheetDocument::PAGES_MAX + 1))), :too_many

        sections = reference.tap { it["pages"][0]["sections"] = [ page["sections"][0] ] * (SheetDocument::SECTIONS_MAX + 1) }
        assert_includes reasons(sections), :too_many

        blocks = reference.tap { it["pages"][0]["sections"][0]["blocks"] = [ { "type" => "paragraph", "text" => "a" } ] * (SheetDocument::BLOCKS_MAX + 1) }
        assert_includes reasons(blocks), :too_many

        fields = with_block(page: 2, section: 0, position: 0) do
          it["fields"] = Array.new(SheetDocument::FIELDS_MAX + 1) { |i| { "id" => "f#{i}", "input" => "numeric", "label" => "x", "answer" => 1 } }
        end
        assert_includes reasons(fields), :too_many

        glossary = Array.new(SheetDocument::GLOSSARY_MAX + 1) { |i| [ "k#{i}", [ "t", "d", "" ] ] }.to_h
        assert_includes reasons(reference.merge("glossary" => glossary)), :too_many

        items = with_block(page: 1, section: 0, position: 0) { it["items"] = [ "a" ] * (SheetDocument::ITEMS_MAX + 1) }
        assert_includes reasons(items), :too_many
      end

      test "borne la longueur d'un texte et la taille du document" do
        assert_includes reasons(with_block { it["text"] = "a" * (SheetDocument::TEXT_MAX + 1) }), :too_long

        paragraph = { "type" => "paragraph", "text" => "a" * SheetDocument::TEXT_MAX }
        section = { "title" => "S", "blocks" => [ paragraph ] * SheetDocument::BLOCKS_MAX }
        page = { "sections" => [ section ] * SheetDocument::SECTIONS_MAX }
        big = reference.merge("pages" => [ page ] * SheetDocument::PAGES_MAX)
        errors = errors_of(big)

        assert_equal [ :too_large ], errors.map(&:reason)
        assert_nil errors.first.page
        assert_equal 1024 * 1024, SheetDocument::SIZE_MAX
      end

      test "un document volumineux mais sous la taille reste valide" do
        paragraph = { "type" => "paragraph", "text" => "a" * SheetDocument::TEXT_MAX }
        section = { "title" => "S", "blocks" => [ paragraph ] * 10 }

        assert_predicate SheetDocument.new(reference.merge("pages" => [ { "sections" => [ section ] * 3 } ])), :valid?
      end

      test "valide un exercice : identifiants uniques, réponse numérique, index de choix" do
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][1]["id"] = "e4an" }), :duplicate_id
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][0]["answer"] = "3,6" }), :wrong_type
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][2]["answer"] = 5 }), :out_of_range
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][2]["options"] = [ "seule" ] }), :too_few
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][0]["input"] = "essay" }), :invalid_value
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][0]["id"] = "E 4" }), :invalid_value
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][0]["answer"] = 10**9 }), :out_of_range
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][2]["frozen"] = "oui" }), :wrong_type
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][0]["options"] = [ "a", "b" ] }), :unknown_key
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"] = [] }), :blank
      end

      test "valide un entraînement : la banque va avec le kind bank" do
        assert_includes reasons(with_block(page: 2, section: 1, position: 0) { it["bank"] = [] }), :unknown_key
        assert_includes reasons(with_block(page: 2, section: 1, position: 1) { it.delete("bank") }), :missing_key
        assert_includes reasons(with_block(page: 2, section: 1, position: 1) { it["bank"] = [ { "prompt" => "x" } ] }), :missing_key
        assert_includes reasons(with_block(page: 2, section: 1, position: 1) { it["bank"] = [ "x" ] }), :wrong_type
        assert_includes reasons(with_block(page: 2, section: 1, position: 1) { it["bank"] = [ { "prompt" => "x", "answer" => 1, "solution" => "y" } ] * 51 }), :too_many
        assert_includes reasons(with_block(page: 2, section: 1, position: 0) { it["kind"] = "lens_simulator" }), :unknown_kind
      end

      test "valide la rédaction, le tableau et les étapes" do
        assert_includes reasons(with_block(page: 2, section: 1, position: 2) { it["min_words"] = 5000 }), :out_of_range
        assert_includes reasons(with_block(page: 2, section: 1, position: 2) { it["min_paragraphs"] = -1 }), :out_of_range
        assert_includes reasons(with_block(page: 2, section: 1, position: 2) { it["connectors"] = "car" }), :wrong_type
        assert_includes reasons(with_block(page: 1, section: 0, position: 1) { it["rows"][0] = [ "seule" ] }), :wrong_size
        assert_includes reasons(with_block(page: 1, section: 0, position: 1) { it["rows"] = "x" }), :wrong_type
        assert_includes reasons(with_block(page: 1, section: 0, position: 0) { it["items"] = [] }), :blank
      end

      test "valide les paramètres d'un kind : bornés, sans HTML ni URL" do
        assert_includes reasons(with_block(page: 0, section: 1, position: 0) { it["params"] = { "a" => 10**7 } }), :out_of_range
        assert_includes reasons(with_block(page: 0, section: 1, position: 0) { it["params"] = { "A B" => 1 } }), :invalid_value
        assert_includes reasons(with_block(page: 0, section: 1, position: 0) { it["params"] = { "a" => [ 1 ] } }), :wrong_type
        assert_includes reasons(with_block(page: 0, section: 1, position: 0) { it["params"] = { "a" => "http://x.y" } }), :url_forbidden
        assert_includes reasons(with_block(page: 0, section: 1, position: 0) { it["params"] = 5 }), :wrong_type
        assert_includes reasons(with_block(page: 0, section: 1, position: 0) do
          it["params"] = Array.new(SheetDocument::PARAMS_MAX + 1) { |i| [ "p#{i}", 1 ] }.to_h
        end), :too_many
        assert_includes reasons(with_block(page: 0, section: 1, position: 0) { it["params"] = { "ok" => true, "n" => 1.5, "s" => "texte" } }) + [ :ok ], :ok
        assert_empty errors_of(with_block(page: 0, section: 1, position: 0) { it["params"] = { "ok" => true, "n" => 1.5, "s" => "texte" } })
      end

      test "les champs facultatifs peuvent manquer" do
        document = reference
        document["pages"][0]["header"] = { "title" => "Titre seul" }
        document["pages"][0]["sections"][0]["blocks"][1].delete("tone")
        document["pages"][0]["sections"][1]["blocks"][0].except!("caption", "params")
        document["pages"][1]["sections"][0]["blocks"][0].delete("label")
        document["pages"][1]["sections"][0]["blocks"][1].delete("caption")
        exercise = document["pages"][2]["sections"][0]["blocks"][0]
        exercise.except!("hint", "correction")
        exercise["fields"][2].delete("frozen")
        document["pages"][2]["sections"][1]["blocks"][2].except!("connectors", "min_words", "min_paragraphs")
        document["pages"][1].delete("header")

        assert_empty errors_of(document)
        assert_includes reasons(document.merge("glossary" => {})), :unknown_glossary_key
      end

      test "refuse les formes qui ne sont pas des objets ou des listes, bloc par bloc" do
        assert_includes reasons(reference.tap { it["pages"][0]["header"] = "x" }), :wrong_type
        assert_includes reasons(with_block { it.delete("type") }), :missing_key
        assert_includes reasons(with_block(position: 1) { it["tone"] = "x" }), :invalid_value
        assert_includes reasons(with_block(position: 1) { it["paragraphs"] = "x" }), :wrong_type
        assert_includes reasons(with_block(page: 1, section: 0, position: 0) { it["items"] = "x" }), :wrong_type
        assert_includes reasons(with_block(page: 1, section: 0, position: 1) { it["headers"] = "x" }), :wrong_type
        assert_includes reasons(with_block(page: 1, section: 0, position: 1) { it["rows"][0] = "x" }), :wrong_type
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"] = [ "x" ] }), :wrong_type
        assert_includes reasons(with_block(page: 2, section: 0, position: 0) { it["fields"][2]["answer"] = "0" }), :wrong_type
        assert_includes reasons(with_block(page: 2, section: 1, position: 1) { it["bank"] = "x" }), :wrong_type
        assert_includes reasons(with_block(page: 2, section: 1, position: 2) { it["min_words"] = "40" }), :wrong_type
        assert_includes reasons(with_block { it["text"] = "Voir [[secantes" }), :malformed_mark
        assert_includes reasons(with_block { it["text"] = "Voir secantes]]" }), :malformed_mark
        assert_empty reasons(with_block { it["text"] = "Coût de 5 \\$ et $x$" })
        assert_empty reasons(with_block { it["text"] = "(MN) // (BC)" })
      end

      test "pages et lexique d'un document qui n'est pas un objet" do
        assert_empty SheetDocument.new(nil).pages
        assert_empty SheetDocument.new(nil).glossary
        assert_empty SheetDocument.new(reference.merge("pages" => "x")).pages
        assert_empty SheetDocument.new(reference.merge("glossary" => "x")).glossary
        assert_equal 3, SheetDocument.new(reference).pages.size
        assert_equal [ :wrong_type ], reasons(reference.tap { it["pages"][0]["sections"][0]["blocks"][0]["text"] = Float::NAN })
      end

      test "les erreurs portent page, section, position et raison, et se lisent en une ligne" do
        error = SheetDocument::Error.new(page: 2, section: 1, position: 3, reason: :unknown_kind, detail: "kind")

        assert_equal "page 2, section 1, bloc 3 : unknown_kind (kind)", error.to_s
        assert_equal "document : wrong_type", SheetDocument::Error.new(page: nil, section: nil, position: nil, reason: :wrong_type, detail: nil).to_s
        assert_equal "page 1, section 2 : blank (title)", SheetDocument::Error.new(page: 1, section: 2, position: nil, reason: :blank, detail: "title").to_s
        assert_equal "page 1 : blank", SheetDocument::Error.new(page: 1, section: nil, position: nil, reason: :blank, detail: nil).to_s
      end

      ENVELOPE = { "format" => "lnclass.course-sheet", "version" => 1, "course" => "la-propriete-de-thales", "theme" => "blue" }.freeze

      def envelope(document) = ENVELOPE.merge(document)

      def schema = JSONSchemer.schema(Rails.root.join("config/schemas/lnclass.course-sheet.v1.json").read)

      test "le schéma JSON et SheetDocument s'accordent sur le document de référence et sur les refus" do
        assert schema.valid?(envelope(reference)), schema.validate(envelope(reference)).first(3).map { it["error"] }.join("\n")

        refused = [
          with_block { it["onclick"] = "x" },
          with_block { it["type"] = "iframe" },
          with_block(page: 0, section: 1, position: 0) { it["kind"] = "inconnu" },
          with_block(page: 1, section: 0, position: 2) { it["kind"] = "thales_figure" },
          with_block { it.delete("text") },
          with_block { it["text"] = "<b>x</b>" },
          with_block { it["text"] = "Voir https://exemple.org" },
          with_block { it["text"] = "Ligne\nVoir WWW.exemple.org" },
          with_block { it["text"] = "a" * (SheetDocument::TEXT_MAX + 1) },
          with_block(page: 2, section: 0, position: 0) { it["fields"][0]["answer"] = "3,6" },
          with_block(page: 2, section: 0, position: 0) { it["fields"][2]["answer"] = -1 },
          with_block(page: 2, section: 0, position: 0) { it["fields"][0]["options"] = [ "a", "b" ] },
          with_block(page: 2, section: 1, position: 1) { it.delete("bank") },
          with_block(page: 2, section: 1, position: 0) { it["bank"] = [] },
          with_block(page: 0, section: 1, position: 0) { it["params"] = { "a" => [ 1 ] } },
          with_block(page: 0, section: 1, position: 0) { it["params"] = { "A B" => 1 } },
          with_block(page: 2, section: 1, position: 2) { it["min_words"] = 5000 },
          reference.tap { it["pages"] = [] },
          reference.tap { it["pages"] = [ it["pages"][0] ] * (SheetDocument::PAGES_MAX + 1) },
          reference.merge("glossary" => { "Mot Clé" => [ "t", "d", "" ] }),
          reference.merge("glossary" => reference["glossary"].merge("x" => [ "<b>", "d", "" ])),
          reference.merge("extra" => 1)
        ]
        refused.each_with_index do |document, index|
          assert_not schema.valid?(envelope(document)), "le schéma devrait refuser le cas #{index}"
          assert_not SheetDocument.new(document).valid?, "SheetDocument devrait refuser le cas #{index}"
        end
      end

      test "le schéma refuse une enveloppe fausse" do
        [ { "format" => "autre" }, { "version" => 2 }, { "theme" => "red" }, { "course" => "" } ].each do |change|
          assert_not schema.valid?(envelope(reference).merge(change)), change.inspect
        end
        assert_not schema.valid?(envelope(reference).except("course"))
      end

      test "les bornes du schéma sont celles de la classe" do
        json = JSON.parse(Rails.root.join("config/schemas/lnclass.course-sheet.v1.json").read)
        defs = json.fetch("$defs")

        assert_equal SheetDocument::PAGES_MAX, json.dig("properties", "pages", "maxItems")
        assert_equal SheetDocument::GLOSSARY_MAX, json.dig("properties", "glossary", "maxProperties")
        assert_equal SheetDocument::SECTIONS_MAX, defs.dig("page", "properties", "sections", "maxItems")
        assert_equal SheetDocument::BLOCKS_MAX, defs.dig("section", "properties", "blocks", "maxItems")
        assert_equal SheetDocument::FIELDS_MAX, defs.dig("block_exercise", "properties", "fields", "maxItems")
        assert_equal SheetDocument::TEXT_MAX, defs.dig("text", "maxLength")
        assert_equal SheetDocument::SHORT_MAX, defs.dig("short_text", "maxLength")
        assert_equal SheetDocument::ITEMS_MAX, defs.dig("block_steps", "properties", "items", "maxItems")
        assert_equal SheetDocument::BANK_MAX, defs.dig("practice_bank", "properties", "bank", "maxItems")
        assert_equal SheetDocument::PARAMS_MAX, defs.dig("params", "maxProperties")
        assert_equal SheetDocument::BLOCK_TYPES.sort, defs.dig("block", "oneOf").map { it["$ref"].split("/").last.delete_prefix("block_") }.sort
        assert_equal SheetDocument::MEDIA_KINDS, defs.dig("block_media", "properties", "kind", "enum")
        assert_equal SheetDocument::FIGURE_KINDS, defs.dig("block_figure", "properties", "kind", "enum")
        assert_equal CourseSheet::THEMES, json.dig("properties", "theme", "enum")
      end
    end
  end
end

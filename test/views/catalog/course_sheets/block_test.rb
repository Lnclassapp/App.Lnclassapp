require "test_helper"
require "action_view/testing/resolvers"

module Catalog
  # Contenu-en-blocs (#318), Lot 0 : l'aiguillage gelé de la fiche de cours. Les partials de type et de kind viennent des
  # lots suivants : ici, des partials de substitution disent lequel est rendu, avec quel `block`.
  class CourseSheetBlockTest < ActionView::TestCase
    PREFIX = "catalog/course_sheets".freeze
    Sheet = Entities::Catalog::SheetDocument
    KINDS = (Sheet::MEDIA_KINDS + Sheet::FIGURE_KINDS).freeze

    setup do
      templates = (Sheet::BLOCK_TYPES - %w[figure media]).to_h { |type| [ "#{PREFIX}/blocks/_#{type}.html.erb", "type=#{type} <%= block['marker'] %>" ] }
      templates.merge!(KINDS.to_h { |kind| [ "#{PREFIX}/kinds/_#{kind}.html.erb", "kind=#{kind} <%= block['marker'] %>" ] })
      view.lookup_context.prepend_view_paths([ ActionView::FixtureResolver.new(templates) ])
    end

    def block_html(block) = render(partial: "#{PREFIX}/block", locals: { block: })

    test "chaque type de la liste fermée, sauf figure et média, rend blocks/_<type> avec son bloc" do
      (Sheet::BLOCK_TYPES - %w[figure media]).each do |type|
        assert_includes block_html({ "type" => type, "marker" => "m-#{type}" }), "type=#{type} m-#{type}"
      end
    end

    test "chaque kind de figure fixe et de média rend kinds/_<kind> avec son bloc" do
      Sheet::FIGURE_KINDS.each { assert_includes block_html({ "type" => "figure", "kind" => it, "marker" => "m" }), "kind=#{it} m" }
      Sheet::MEDIA_KINDS.each { assert_includes block_html({ "type" => "media", "kind" => it, "marker" => "m" }), "kind=#{it} m" }
    end

    test "un type, un kind ou un mélange hors liste ne rend aucun partial, mais un message" do
      message = ERB::Util.html_escape(I18n.t("catalog.course_sheets.block.unavailable"))

      [ { "type" => "iframe" }, { "type" => "media", "kind" => "inconnu" }, { "type" => "media", "kind" => "lens_diagrams" },
        { "type" => "figure", "kind" => "thales_figure" }, { "type" => "../../x" }, { "type" => nil }, {} ].each do |block|
        html = block_html(block)

        assert_includes html, message, block.inspect
        assert_no_match(/type=|kind=/, html)
      end
    end
  end
end

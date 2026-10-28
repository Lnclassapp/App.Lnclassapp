require "test_helper"

module Queries
  module Catalog
    # UDR-0139 §3.2 : la fiche cahier de la leçon, sinon son texte puis celui de ses notions publiées, coupés après 150 mots.
    class RevisionSheetQueryTest < ActiveSupport::TestCase
      def words(count) = Array.new(count) { "mot" }.join(" ")
      def call(course) = RevisionSheetQuery.new.call(course_slug: course.slug, actor: nil)

      def document(*paragraphs)
        { "pages" => [ { "sections" => [ { "title" => "Titre", "blocks" => paragraphs.map { { "type" => "paragraph", "text" => words(it) } } } ] } ],
          "glossary" => {} }
      end

      test "le contrat porte kind, sheet, texts et cut" do
        assert_equal %i[kind sheet texts cut], RevisionSheetQuery::Revision.members
      end

      test "une leçon avec une fiche cahier rend la fiche et sa coupe" do
        course = create_course
        create_course_sheet(course:, document: document(100, 60, 10))

        revision = call(course)

        assert_equal :sheet, revision.kind
        assert_equal course.slug, revision.sheet.course.slug
        assert_equal [], revision.texts
        assert_predicate revision.cut, :cut?
        assert revision.cut.rest?(0, 0, 2)
        assert_not revision.cut.rest?(0, 0, 1)
      end

      test "une fiche cahier courte n'a pas de coupe" do
        course = create_course
        create_course_sheet(course:, document: document(50))

        assert_nil call(course).cut
      end

      test "sans fiche cahier : le texte de la leçon, puis celui de chaque notion publiée, dans l'ordre" do
        course = create_course(content: "<p>Intro de la leçon.</p>")
        create_essential(course:, name: "Seconde", position: 2, content: "<p>Texte de la seconde.</p>")
        create_essential(course:, name: "Première", position: 1, content: "<p>Premier paragraphe.</p><p>Second paragraphe.</p>")
        create_essential(course:, name: "Brouillon", position: 3, status: "draft", content: "<p>Pas encore.</p>")

        revision = call(course)

        assert_equal :texts, revision.kind
        assert_nil revision.sheet
        assert_equal [ nil, "Première", "Seconde" ], revision.texts.map { it[:title] }
        assert_equal 1, revision.texts[0][:blocks].size
        assert_equal 2, revision.texts[1][:blocks].size
        assert_includes revision.texts[1][:blocks][1], "Second paragraphe."
        assert_includes revision.texts[1][:html], "Premier paragraphe."
        assert_includes revision.texts[1][:html], "Second paragraphe."
        assert_not_includes revision.texts.to_s, "Pas encore"
        assert_nil revision.cut
      end

      test "le texte est coupé à la fin d'un paragraphe, une figure ne compte aucun mot" do
        course = create_course(content: "<p>#{words(100)}</p><p>#{words(60)}</p>")
        create_essential(course:, name: "Notion", content: "<p>suite</p><figure><img src='x'></figure>")

        cut = call(course).cut

        assert_predicate cut, :cut?
        assert_not cut.rest?(0, 1)
        assert cut.rest?(1, 0)
        assert cut.rest?(1, 1)
      end

      test "une notion sans texte n'a pas d'intertitre" do
        course = create_course(content: "")
        create_essential(course:, name: "Vide", content: "")
        create_essential(course:, name: "Rédigée", content: "<p>Du texte.</p>")

        assert_equal [ "Rédigée" ], call(course).texts.map { it[:title] }
      end

      test "du texte brut sans balise reste un paragraphe" do
        course = create_course(content: "Texte seul")

        assert_equal [ "Texte seul" ], call(course).texts.first[:blocks].map { Nokogiri::HTML5.fragment(it).text.strip }
      end

      test "une leçon sans fiche, sans texte et sans notion rédigée est vide" do
        course = create_course(content: "")

        revision = call(course)

        assert_equal [ :empty, nil, [], nil ], [ revision.kind, revision.sheet, revision.texts, revision.cut ]
      end

      test "une leçon inconnue est vide" do
        revision = RevisionSheetQuery.new.call(course_slug: "inconnue", actor: nil)

        assert_equal :empty, revision.kind
      end
    end
  end
end

require "test_helper"

module Queries
  module Catalog
    # UDR-0141 §3.1 : la fiche de révision d'une leçon v3 : ses notions publiées (toutes pour l'équipe) au gabarit des quatre blocs.
    class RevisionSheetQueryTest < ActiveSupport::TestCase
      def call(course, actor: nil) = RevisionSheetQuery.new.call(course_slug: course.slug, actor:)

      def words(count) = Array.new(count) { "mot" }.join(" ")

      def lesson(figures: [ revision_figure ], name: "Racines carrées", **attributes)
        create_course(name:, subtitle: "Calculer et simplifier", figures:, **attributes)
      end

      def add_notion(course, notion = revision_notion("Simplifier une racine carrée", figure: "triangle-thales"), **attributes)
        sheet = { "remember" => notion["remember"], "method" => notion["method"], "example" => notion["example"],
                  "pitfall" => notion["pitfall"], "figure_key" => notion["figure"] }
        create_essential(course:, name: notion["name"], sheet:, **attributes)
      end

      test "le contrat porte kind, sheet et cut" do
        assert_equal %i[kind sheet cut], RevisionSheetQuery::Revision.members
      end

      test "une leçon v3 rend ses notions publiées dans l'ordre, avec leur fiche, leur figure, le thème et l'en-tête" do
        course = lesson(sheet_theme: "teal")
        add_notion(course, revision_notion("Seconde"), position: 2)
        add_notion(course, revision_notion("Première", figure: "triangle-thales"), position: 1)
        add_notion(course, revision_notion("Brouillon"), position: 3, status: "draft")

        revision = call(course)

        assert_equal :sheet, revision.kind
        assert_equal "Racines carrées", revision.sheet.name
        assert_equal "Calculer et simplifier", revision.sheet.subtitle
        assert_equal "teal", revision.sheet.theme
        assert_equal course.material.name, revision.sheet.material
        assert_equal course.level.name, revision.sheet.level
        assert_equal %w[Première Seconde], revision.sheet.notions.map(&:name)
        first = revision.sheet.notions.first
        assert_equal "notion-#{first.slug}", first.anchor
        assert_kind_of Entities::Catalog::NotionSheet, first.sheet
        assert_equal 3, first.sheet.method_steps.size
        assert_equal "triangle-thales", first.figure.key
        assert_kind_of Entities::Catalog::Figure, first.figure
        assert_nil revision.sheet.notions.last.figure
        assert_nil revision.cut
      end

      test "l'équipe lit toutes les notions, brouillon compris, mais pas les archivées" do
        course = lesson(status: "draft")
        add_notion(course, revision_notion("Brouillon"), status: "draft")
        add_notion(course, revision_notion("Publiée"))
        add_notion(course, revision_notion("Archivée"), status: "archived")

        names = call(course, actor: Entities::Identity::Actor.new(user_id: 1, role: :team, team_role: "content")).sheet.notions.map(&:name)

        assert_equal %w[Brouillon Publiée], names
      end

      test "un élève ne lit que les notions publiées" do
        course = lesson
        add_notion(course, revision_notion("Brouillon"), status: "draft")
        add_notion(course, revision_notion("Publiée"))

        assert_equal %w[Publiée], call(course, actor: Entities::Identity::Actor.new(user_id: create_student_for(course).id, role: :student)).sheet.notions.map(&:name)
      end

      test "une notion qui cite une figure inconnue de la leçon n'a pas de figure" do
        course = lesson(figures: [])
        add_notion(course)

        assert_nil call(course).sheet.notions.first.figure
      end

      test "une notion sans fiche (ancien contenu) n'est pas montrée : l'état est vide" do
        course = lesson
        create_essential(course:, name: "Ancienne")

        assert_equal RevisionSheetQuery::EMPTY, call(course)
      end

      def add_notion_with_practice(course, *questions)
        notion = revision_notion("Avec entraînement")
        sheet = { "remember" => notion["remember"], "method" => notion["method"], "example" => notion["example"], "pitfall" => notion["pitfall"],
                  "practice" => raw_practice(*questions) }
        create_essential(course:, name: notion["name"], sheet:)
      end

      test "l'entraînement de la notion est rendu sans correction, sans explication et sans valeur attendue" do
        course = lesson
        add_notion_with_practice(course, numeric_question, choice_question)

        practice = call(course).sheet.notions.first.practice

        assert_kind_of Entities::Catalog::NotionPractice, practice
        assert_equal 2, practice.questions.size
        assert practice.questions.all? { it.explanation.nil? }
        assert_equal [], practice.questions.first.answers
        assert_equal [ nil, nil, nil ], practice.questions.last.answers.map(&:correct)
        assert_equal %w[6 7 8], practice.questions.last.answers.map(&:content).sort
      end

      test "les propositions d'un ordre ou d'un relier sont mélangées, jamais dans l'ordre de la solution" do
        course = lesson
        add_notion_with_practice(course, ordering_question, matching_question)

        ordering, matching = call(course).sheet.notions.first.practice.questions

        assert_not_equal %w[Décomposer Séparer Calculer], ordering.answers.map(&:content)
        assert_not_equal [ "3", "4", "5" ], matching.answers.map(&:match_content)
        assert_equal %w[Calculer Décomposer Séparer], ordering.answers.map(&:content).sort
      end

      test "une notion sans entraînement n'en a pas" do
        course = lesson
        add_notion(course)

        assert_nil call(course).sheet.notions.first.practice
      end

      test "la coupe compte l'entraînement pour zéro mot" do
        course = lesson
        add_notion_with_practice(course, numeric_question, choice_question, fill_blank_question)
        add_notion(course, revision_notion("Autre"))

        assert_nil call(course).cut, "l'entraînement n'ajoute aucun mot : la fiche reste courte"
      end

      test "une leçon inconnue est vide" do
        assert_equal RevisionSheetQuery::EMPTY, RevisionSheetQuery.new.call(course_slug: "inconnue", actor: nil)
      end

      test "une fiche longue porte la coupe des 150 mots, une courte n'en a pas" do
        course = lesson
        notion = revision_notion("Longue").merge("remember" => words(160))
        add_notion(course, notion)
        add_notion(course, revision_notion("Autre"))

        cut = call(course).cut

        assert_predicate cut, :cut?
        assert cut.rest?(0, Entities::Catalog::RevisionPreview::METHOD)
        assert cut.rest?(1)
        short = lesson(name: "Courte")
        add_notion(short, revision_notion("Courte"))

        assert_nil call(short).cut
      end
    end
  end
end

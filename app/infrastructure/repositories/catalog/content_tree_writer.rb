# 🔌 INFRA · Repositories::Catalog::ContentTreeWriter
# Rôle : écrit en masse des arbres de contenu validés (cours → fiches → exercices → questions → propositions), tout en draft
# ADR  : 0035, 0039
module Repositories
  module Catalog
    class ContentTreeWriter
      include Ports::Catalog::ContentTreeWriterPort

      SANITIZER = Rails::HTML5::SafeListSanitizer.new
      NATURAL_KEYS = { "Orm::Course" => %w[slug], "Orm::Essential" => %w[slug], "Orm::Exercise" => %w[public_id],
                       "Orm::Question" => %w[exercise_id position], "Orm::Answer" => [], "ActionText::RichText" => [] }.freeze

      # Une table après l'autre, parents d'abord : les ids créés sont relus par clé naturelle (slug, public_id, position).
      def write(author_id:, at:, courses: [], essentials: [], exercises: [])
        @author_id = author_id
        @at = at
        course_ids = ids_by(insert(Orm::Course, courses.map { |node| course_row(node) }), "slug")
        write_rich_texts("Orm::Course", courses, course_ids)

        essentials += courses.flat_map { |course| course.essentials.map { |node| node.with(course_id: course_ids.fetch(course.slug)) } }
        essential_ids = ids_by(insert(Orm::Essential, essentials.map { |node| essential_row(node) }), "slug")
        write_rich_texts("Orm::Essential", essentials, essential_ids)

        exercises += essentials.flat_map { |essential| essential.exercises.map { |node| node.with(essential_id: essential_ids.fetch(essential.slug)) } }
        exercise_ids = ids_by(insert(Orm::Exercise, exercises.map { |node| exercise_row(node) }), "public_id")

        questions = exercises.flat_map { |exercise| exercise.questions.map { |node| [ exercise_ids.fetch(exercise.public_id), node ] } }
        question_ids = ids_by(insert(Orm::Question, questions.map { |exercise_id, node| question_row(exercise_id, node) }), "exercise_id", "position")
        answers = questions.flat_map do |exercise_id, question|
          question.answers.map { |node| answer_row(question_ids.fetch([ exercise_id, question.position ]), node) }
        end
        insert(Orm::Answer, answers)

        { courses: courses.size, essentials: essentials.size, exercises: exercises.size, questions: questions.size, answers: answers.size }
      end

      private

      # insert_all saute les callbacks : le repository pose les horodatages. → lignes créées (id et clés naturelles)
      def insert(model, rows)
        return [] if rows.empty?

        model.insert_all!(rows.map { |row| row.merge(created_at: @at, updated_at: @at) }, returning: [ "id", *NATURAL_KEYS.fetch(model.name) ])
      end

      def ids_by(inserted, *key)
        inserted.to_h { |row| [ row.values_at(*key).then { |values| key.one? ? values.first : values }, row["id"] ] }
      end

      def course_row(node)
        { slug: node.slug, name: node.name, subtitle: node.subtitle, level_id: node.level_id, series_id: node.series_id,
          material_id: node.material_id, author_id: @author_id, status: "draft" }
      end

      def essential_row(node)
        { slug: node.slug, course_id: node.course_id, name: node.name, subtitle: node.subtitle, position: node.position,
          author_id: @author_id, status: "draft" }
      end

      def exercise_row(node)
        { public_id: node.public_id, essential_id: node.essential_id, title: node.title, description: node.description,
          exercise_type: node.exercise_type, position: node.position, author_id: @author_id, status: "draft" }
      end

      def question_row(exercise_id, node)
        { exercise_id:, position: node.position, content: node.content, explanation: node.explanation,
          question_type: node.question_type }
      end

      def answer_row(question_id, node)
        { question_id:, position: node.position, content: node.content, correct: node.correct }
      end

      # Le contenu importé est assaini avant d'entrer dans le contenu riche ; un contenu vide ne crée pas de ligne.
      def write_rich_texts(record_type, nodes, ids)
        rows = nodes.filter_map do |node|
          body = SANITIZER.sanitize(node.content.to_s)
          { record_type:, record_id: ids.fetch(node.slug), name: "content", body: } if body.present?
        end
        insert(ActionText::RichText, rows)
      end
    end
  end
end

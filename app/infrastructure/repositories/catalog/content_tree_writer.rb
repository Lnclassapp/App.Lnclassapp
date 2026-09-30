# 🔌 INFRA · Repositories::Catalog::ContentTreeWriter
# Rôle : écrit en masse des arbres de contenu validés (cours → fiches → exercices → questions → propositions), tout en draft
# ADR  : 0035, 0039, 0068
module Repositories
  module Catalog
    class ContentTreeWriter
      include Ports::Catalog::ContentTreeWriterPort

      NATURAL_KEYS = { "Orm::Course" => %w[slug], "Orm::Essential" => %w[slug], "Orm::RichTextRow" => [] }.freeze
      EXERCISE_COLUMNS = %w[id public_id essential_id title description exercise_type position author_id status created_at updated_at].freeze
      QUESTION_COLUMNS = %w[id exercise_id position content explanation question_type created_at updated_at].freeze
      ANSWER_COLUMNS = %w[question_id position content correct created_at updated_at].freeze
      # Format texte de COPY : ces quatre caractères seraient lus comme séparateurs ou échappements.
      COPY_ESCAPES = { "\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r" }.freeze
      COPY_SPECIALS = /[\\\t\n\r]/

      # Une table après l'autre, parents d'abord : les ids des cours et des fiches sont relus par slug, ceux des exercices et
      # des questions sont réservés d'avance. Exercices, questions et propositions s'écrivent par COPY (ADR-0068 §4).
      def write(author_id:, at:, courses: [], essentials: [], exercises: [])
        @author_id = author_id
        @at = at
        @copy_at = copy_timestamp(at)
        course_ids = ids_by(insert(Orm::Course, courses.map { |node| course_row(node) }), "slug")
        write_rich_texts("Orm::Course", courses, course_ids)

        essentials += courses.flat_map { |course| course.essentials.map { |node| node.with(course_id: course_ids.fetch(course.slug)) } }
        essential_ids = ids_by(insert(Orm::Essential, essentials.map { |node| essential_row(node) }), "slug")
        write_rich_texts("Orm::Essential", essentials, essential_ids)

        exercises += essentials.flat_map { |essential| essential.exercises.map { |node| node.with(essential_id: essential_ids.fetch(essential.slug)) } }
        exercise_ids = reserve_ids(Orm::Exercise, exercises.size)
        copy("exercises", EXERCISE_COLUMNS, exercises.zip(exercise_ids).map { |node, id| exercise_row(id, node) })

        questions = exercises.zip(exercise_ids).flat_map { |exercise, exercise_id| exercise.questions.map { |node| [ exercise_id, node ] } }
        question_ids = reserve_ids(Orm::Question, questions.size)
        copy("questions", QUESTION_COLUMNS, questions.zip(question_ids).map { |(exercise_id, node), id| question_row(id, exercise_id, node) })
        answers = questions.zip(question_ids).flat_map { |(_, question), id| question.answers.map { |node| answer_row(id, node) } }
        copy("answers", ANSWER_COLUMNS, answers)

        { courses: courses.size, essentials: essentials.size, exercises: exercises.size, questions: questions.size, answers: answers.size }
      end

      private

      def connection = ActiveRecord::Base.connection

      # insert_all saute les callbacks : le repository pose les horodatages. → lignes créées (id et clés naturelles)
      def insert(model, rows)
        return [] if rows.empty?

        model.insert_all!(rows.map { |row| row.merge(created_at: @at, updated_at: @at) }, returning: [ "id", *NATURAL_KEYS.fetch(model.name) ])
      end

      def ids_by(inserted, key) = inserted.to_h { |row| [ row.fetch(key), row.fetch("id") ] }

      # Une requête pour tous les ids d'une table ; croissants, dans l'ordre des lignes, comme l'aurait donné un INSERT.
      def reserve_ids(model, count)
        return [] if count.zero?

        sql = ActiveRecord::Base.sanitize_sql_array([ "SELECT nextval(?) FROM generate_series(1, ?)", model.sequence_name, count ])
        connection.select_values(sql).sort
      end

      # COPY … FROM STDIN sur la connexion d'ActiveRecord, donc dans la transaction du lot : contraintes et index
      # s'appliquent comme pour un INSERT. Un refus de la base lève l'erreur qu'ActiveRecord aurait levée
      # (RecordNotUnique, CheckViolation…), pour que le moteur rejoue le lot élément par élément.
      def copy(table, columns, rows)
        return if rows.empty?

        sql = "COPY #{table} (#{columns.join(', ')}) FROM STDIN"
        raw = connection.raw_connection
        raw.copy_data(sql) { raw.put_copy_data(rows.map { |row| copy_line(row) }.join) }
      rescue PG::Error => error
        raise connection.send(:translate_exception_class, error, sql, [])
      end

      def copy_line(row) = "#{row.map { |value| copy_value(value) }.join("\t")}\n"

      # NULL vaut \N, un booléen t ou f ; un texte est échappé, un entier écrit tel quel.
      def copy_value(value)
        case value
        when nil then "\\N"
        when true then "t"
        when false then "f"
        when String then value.match?(COPY_SPECIALS) ? value.gsub(COPY_SPECIALS, COPY_ESCAPES) : value
        else value.to_s
        end
      end

      # L'heure UTC tronquée à la microseconde, comme insert_all l'écrit dans une colonne datetime(6) ; encodée une fois
      # par écriture, elle ne contient aucun caractère à échapper.
      def copy_timestamp(at) = at.getutc.strftime("%Y-%m-%d %H:%M:%S.%6N")

      def course_row(node)
        { slug: node.slug, name: node.name, subtitle: node.subtitle, level_id: node.level_id, series_id: node.series_id,
          material_id: node.material_id, author_id: @author_id, status: "draft" }
      end

      def essential_row(node)
        { slug: node.slug, course_id: node.course_id, name: node.name, subtitle: node.subtitle, position: node.position,
          author_id: @author_id, status: "draft" }
      end

      # Dans l'ordre d'EXERCISE_COLUMNS.
      def exercise_row(id, node)
        [ id, node.public_id, node.essential_id, node.title, node.description, node.exercise_type, node.position, @author_id, "draft",
          @copy_at, @copy_at ]
      end

      # Dans l'ordre de QUESTION_COLUMNS.
      def question_row(id, exercise_id, node)
        [ id, exercise_id, node.position, node.content, node.explanation, node.question_type, @copy_at, @copy_at ]
      end

      # Dans l'ordre d'ANSWER_COLUMNS.
      def answer_row(question_id, node)
        [ question_id, node.position, node.content, node.correct, @copy_at, @copy_at ]
      end

      # Le contenu importé est assaini avant d'entrer dans le contenu riche ; un contenu vide ne crée pas de ligne.
      # Le corps est écrit tel que l'assainisseur le rend, sans conversion par ActionText::Content (ADR-0068 §4) :
      # seul le strip que cette conversion appliquait est gardé.
      def write_rich_texts(record_type, nodes, ids)
        rows = nodes.filter_map do |node|
          body = RichTextSanitizer.call(node.content.to_s)
          { record_type:, record_id: ids.fetch(node.slug), name: "content", body: body.strip } if body.present?
        end
        insert(Orm::RichTextRow, rows)
      end
    end
  end
end

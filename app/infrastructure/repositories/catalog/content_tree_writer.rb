# 🔌 INFRA · Repositories::Catalog::ContentTreeWriter
# Rôle : écrit en masse des arbres de contenu validés (cours → fiches → exercices → questions → propositions), tout en draft
# ADR  : 0035, 0039, 0068, 0091, 0105, 0113, 0115, 0116, 0119-entrainement-de-notion-corrige-sans-trace, 0120-questions-a-plusieurs-cases-et-indice, XXXX-sujets-de-devoir-et-verification-sur-la-feuille
module Repositories
  module Catalog
    class ContentTreeWriter
      include Ports::Catalog::ContentTreeWriterPort

      # Un contenu de la leçon réimportée n'est plus en brouillon : la base du lot refuse, le moteur le note (Transaction::WRITE_FAILURES).
      class NotDraft < ActiveRecord::CheckViolation; end

      NATURAL_KEYS = { "Orm::Course" => %w[slug], "Orm::Essential" => %w[slug], "Orm::Subject" => %w[course_id position],
                       "Orm::RichTextRow" => [] }.freeze
      EXERCISE_COLUMNS = %w[id public_id course_id essential_id subject_id title statement statement_blocks figure_key hint exercise_type position
                            author_id status created_at updated_at].freeze
      QUESTION_COLUMNS = %w[id exercise_id position content explanation question_type numeric_tolerance image_description points unit
                            starter criteria hint created_at updated_at].freeze
      ANSWER_COLUMNS = %w[question_id position content correct match_content blank created_at updated_at].freeze
      # Format texte de COPY : ces quatre caractères seraient lus comme séparateurs ou échappements.
      COPY_ESCAPES = { "\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r" }.freeze
      COPY_SPECIALS = /[\\\t\n\r]/

      # Une table après l'autre, parents d'abord : les ids des cours et des fiches sont relus par slug, ceux des exercices et
      # des questions sont réservés d'avance. Exercices, questions et propositions s'écrivent par COPY (ADR-0068 §4).
      # Une leçon déjà en base (existing_id) n'est pas réécrite, ni ses notions : ses exercices sont archivés, puis remplacés.
      # Les contrôles de clé étrangère gardent le plan choisi quand la table parente était presque vide : un parcours
      # complet par ligne, coût quadratique (10 000 exercices au-delà de 5 min sur une base neuve). Sans parcours
      # séquentiel, jusqu'à la fin de la transaction du lot, ils passent par la clé primaire.
      def write(author_id:, at:, courses: [], essentials: [], exercises: [])
        connection.execute("SET LOCAL enable_seqscan = off")
        stamp(author_id, at)
        kept, courses = courses.partition(&:existing_id)
        archived = archive_exercises(kept.map(&:existing_id))
        course_ids = ids_by(insert(Orm::Course, courses.map { |node| course_row(node) }), "slug")
        write_rich_texts("Orm::Course", courses, course_ids)

        essentials += courses.flat_map { |course| course.essentials.map { |node| node.with(course_id: course_ids.fetch(course.slug)) } }
        essential_ids = ids_by(insert(Orm::Essential, essentials.map { |node| essential_row(node) }), "slug")

        # Les notions v3 (fiche en jsonb) sont des lignes de la même table ; leurs exercices suivent ceux des fiches.
        notions = courses.flat_map { |course| course.notions.map { |node| node.with(course_id: course_ids.fetch(course.slug)) } }
        notion_ids = ids_by(insert(Orm::Essential, notions.map { |node| notion_row(node) }), "slug")

        exercises += essentials.flat_map { |essential| essential.exercises.map { |node| node.with(essential_id: essential_ids.fetch(essential.slug)) } }
        exercises += notions.flat_map { |notion| notion.exercises.map { |node| node.with(essential_id: notion_ids.fetch(notion.slug)) } }
        exercises += kept.flat_map { |course| course.essentials.flat_map { |essential| essential.exercises.map { |node| node.with(essential_id: essential.existing_id) } } }
        # Les exercices de toute la leçon viennent après ceux des notions : sans notion, ils prennent la leçon de leur cours (ADR-0113 §4.1).
        lesson_wide = courses.flat_map { |course| course.exercises.map { |node| [ node, course_ids.fetch(course.slug), nil ] } } +
                      kept.flat_map { |course| course.exercises.map { |node| [ node, course.existing_id, nil ] } }
        # Les sujets de devoir (ADR-XXXX §4) viennent après les exercices de la leçon : leurs exercices sont les derniers de la leçon.
        subjects = courses.flat_map { |course| course.subjects.map { |node| node.with(course_id: course_ids.fetch(course.slug)) } }
        counts = write_exercises(exercises, lesson_wide + subject_exercises(subjects, insert_subjects(subjects)))

        { courses: courses.size, essentials: essentials.size + notions.size, **counts, archived: }
      end

      # ADR-0116 §4.4 : remplace une leçon encore en brouillon, dans la transaction de l'appelant, la leçon verrouillée. Elle garde son id,
      # son slug et son auteur (les lignes réécrites lui appartiennent). → { courses:, essentials:, exercises:, questions:, answers:, subjects: }
      def replace_draft(course_id:, tree:)
        connection.execute("SET LOCAL enable_seqscan = off")
        course = Orm::Course.lock.find(course_id)
        raise NotDraft, "la leçon #{course.slug} ou l'un de ses contenus n'est plus en brouillon" unless draft?(course)

        stamp(course.author_id, Time.current)
        deleted = delete_content(course_id)
        Rails.logger.info("[import] leçon remplacée : course_id=#{course_id} slug=#{course.slug} lignes supprimées #{deleted.to_json}")
        course.update_columns(name: tree.name, subtitle: tree.subtitle, figures: tree.figures, sheet_theme: tree.sheet_theme, updated_at: @at)

        taken = Orm::Essential.pluck(:slug).to_set
        notions = tree.notions.map { |node| node.with(course_id:, slug: Entities::Catalog::Slug.unique(node.slug, taken:)) }
        notion_ids = ids_by(insert(Orm::Essential, notions.map { |node| notion_row(node) }), "slug")
        exercises = notions.flat_map { |notion| notion.exercises.map { |node| node.with(essential_id: notion_ids.fetch(notion.slug)) } }
        lesson_wide = tree.exercises.map { [ it, course_id, nil ] }
        subjects = tree.subjects.map { it.with(course_id:) }
        counts = write_exercises(exercises, lesson_wide + subject_exercises(subjects, insert_subjects(subjects)))

        { courses: 1, essentials: notions.size, **counts, subjects: subjects.size }
      end

      private

      def connection = ActiveRecord::Base.connection

      def stamp(author_id, at)
        @author_id = author_id
        @at = at
        @copy_at = copy_timestamp(at)
      end

      # Les sujets de devoir des leçons (course_id posé), numérotés de 1 dans l'ordre reçu. → { [course_id, position] => id }
      def insert_subjects(subjects)
        rows = subjects.group_by(&:course_id).flat_map do |course_id, nodes|
          nodes.each_with_index.map { |node, index| { course_id:, position: index + 1, title: node.title, notions: node.notions } }
        end
        insert(Orm::Subject, rows).to_h { |row| [ [ row.fetch("course_id"), row.fetch("position") ], row.fetch("id") ] }
      end

      # Les exercices des sujets, avec l'id de leur leçon et celui de leur sujet : [nœud, course_id, subject_id].
      def subject_exercises(subjects, ids)
        subjects.group_by(&:course_id).flat_map do |course_id, nodes|
          nodes.each_with_index.flat_map do |node, index|
            node.exercises.map { |exercise| [ exercise, course_id, ids.fetch([ course_id, index + 1 ]) ] }
          end
        end
      end

      # Les exercices : ceux des notions (head) d'abord, puis, à la fin, ceux de toute la leçon et ceux des sujets (tail, des triplets
      # [nœud, id de la leçon, id du sujet ou nil]), leurs questions et leurs propositions. Exercices, questions et propositions
      # s'écrivent par COPY (ADR-0068 §4).
      def write_exercises(head, tail)
        exercises = head + tail.map(&:first)
        course_of = course_ids_of(head)
        owners = head.map { course_of.fetch(it.essential_id) } + tail.map { it[1] }
        subject_of = Array.new(head.size) + tail.map(&:last)
        exercise_ids = reserve_ids(Orm::Exercise, exercises.size)
        positions = course_positions(owners)
        copy("exercises", EXERCISE_COLUMNS, exercises.zip(exercise_ids, owners, positions, subject_of).map { |node, id, owner, position, subject_id| exercise_row(id, node, owner, position, subject_id) })

        questions = exercises.zip(exercise_ids).flat_map { |exercise, exercise_id| exercise.questions.map { |node| [ exercise_id, node ] } }
        question_ids = reserve_ids(Orm::Question, questions.size)
        copy("questions", QUESTION_COLUMNS, questions.zip(question_ids).map { |(exercise_id, node), id| question_row(id, exercise_id, node) })
        answers = questions.zip(question_ids).flat_map { |(_, question), id| question.answers.map { |node| answer_row(id, node) } }
        copy("answers", ANSWER_COLUMNS, answers)

        { exercises: exercises.size, questions: questions.size, answers: answers.size }
      end

      # La leçon et tout son contenu n'ont jamais été publiés ni archivés. Les lignes sont verrouillées en même temps que lues.
      def draft?(course)
        course.status == "draft" && (Orm::Essential.where(course_id: course.id).lock.pluck(:status) +
                                     Orm::Exercise.where(course_id: course.id).lock.pluck(:status)).all?("draft")
      end

      # Du plus dépendant au moins dépendant (toutes les clés étrangères sont RESTRICT) : lacunes, copies, séances, badges, questions,
      # exercices, sujets, puis notions, leurs lectures, images et texte riche. Les images (fichiers stockés) sont détruites pour être purgées.
      # → nombre de lignes supprimées par table.
      def delete_content(course_id)
        exercise_ids = Orm::Exercise.where(course_id:).pluck(:id)
        essential_ids = Orm::Essential.where(course_id:).pluck(:id)
        question_ids = Orm::Question.where(exercise_id: exercise_ids).pluck(:id)
        session_ids = Orm::ExerciseSession.where(exercise_id: exercise_ids).pluck(:id)
        deleted = {}

        gap_ids = Orm::KnowledgeGap.where(essential_id: essential_ids).or(Orm::KnowledgeGap.where(source_session_id: session_ids))
                                   .or(Orm::KnowledgeGap.where(resolved_by_session_id: session_ids)).pluck(:id)
        # Une séance de remédiation (la base veut une lacune avec elle) devient une séance ordinaire quand sa lacune disparaît ; celles des
        # exercices supprimés partent ensuite avec eux.
        Orm::ExerciseSession.where(knowledge_gap_id: gap_ids).update_all(kind: "standard", knowledge_gap_id: nil)
        deleted[:knowledge_gaps] = Orm::KnowledgeGap.where(id: gap_ids).delete_all
        deleted[:exercise_badges] = Orm::ExerciseBadge.where(exercise_id: exercise_ids).delete_all
        deleted[:question_attempts] = Orm::QuestionAttempt.where(exercise_session_id: session_ids).or(Orm::QuestionAttempt.where(question_id: question_ids)).delete_all
        deleted[:exercise_sessions] = Orm::ExerciseSession.where(id: session_ids).delete_all
        deleted[:classroom_assignments] = Orm::ClassroomAssignment.where(assignable_type: "Exercise", assignable_id: exercise_ids).delete_all
        images = Orm::QuestionImage.where(question_id: question_ids)
        deleted[:question_images] = images.count
        images.find_each(&:destroy!)
        deleted[:answers] = Orm::Answer.where(question_id: question_ids).delete_all
        deleted[:questions] = Orm::Question.where(id: question_ids).delete_all
        deleted[:exercises] = Orm::Exercise.where(id: exercise_ids).delete_all
        deleted[:subjects] = Orm::Subject.where(course_id:).delete_all
        deleted[:essential_reads] = Orm::EssentialRead.where(essential_id: essential_ids).delete_all
        deleted[:essentials] = Orm::Essential.where(id: essential_ids).delete_all
        deleted
      end

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

      # NULL vaut \N, un booléen t ou f ; un texte est échappé, un décimal écrit sans exposant, un entier tel quel.
      def copy_value(value)
        case value
        when nil then "\\N"
        when true then "t"
        when false then "f"
        when String then value.match?(COPY_SPECIALS) ? value.gsub(COPY_SPECIALS, COPY_ESCAPES) : value
        when BigDecimal then value.to_s("F")
        else value.to_s
        end
      end

      # L'heure UTC tronquée à la microseconde, comme insert_all l'écrit dans une colonne datetime(6) ; encodée une fois
      # par écriture, elle ne contient aucun caractère à échapper.
      def copy_timestamp(at) = at.getutc.strftime("%Y-%m-%d %H:%M:%S.%6N")

      def course_row(node)
        { slug: node.slug, name: node.name, subtitle: node.subtitle, level_id: node.level_id, series_id: node.series_id,
          material_id: node.material_id, author_id: @author_id, status: "draft", figures: node.figures, sheet_theme: node.sheet_theme }
      end

      def notion_row(node)
        { slug: node.slug, course_id: node.course_id, name: node.name, subtitle: nil, position: node.position, author_id: @author_id,
          status: "draft", sheet: node.sheet }
      end

      def essential_row(node)
        { slug: node.slug, course_id: node.course_id, name: node.name, subtitle: node.subtitle, position: node.position,
          author_id: @author_id, status: "draft" }
      end

      # La leçon de chaque notion qui porte un exercice (les fiches viennent d'être écrites, dans la même transaction).
      def course_ids_of(exercises) = Orm::Essential.where(id: exercises.filter_map(&:essential_id).uniq).pluck(:id, :course_id).to_h

      # La position est unique par leçon : elle suit la dernière de la leçon (archivés compris), dans l'ordre d'arrivée des
      # exercices, qui est celui du fichier (les notions, puis toute la leçon). node.position n'est pas lue : de 1 à n sans trou
      # ni doublon, quelle que soit la façon dont l'appelant numérote ses nœuds. → [Integer]
      def course_positions(owners)
        last = Orm::Exercise.where(course_id: owners.uniq).group(:course_id).maximum(:position)
        owners.map { |course_id| last[course_id] = last.fetch(course_id, 0) + 1 }
      end

      # Réimport (ADR-0113 §4.5) : les exercices restent lisibles (séances, copies), jamais modifiés en place ; leurs assignations
      # actives sont archivées avec eux, comme la migration du Lot 0. → le nombre d'exercices archivés
      def archive_exercises(course_ids)
        return 0 if course_ids.empty?

        ids = Orm::Exercise.where(course_id: course_ids).where.not(status: "archived").pluck(:id)
        Orm::ClassroomAssignment.where(assignable_type: "Exercise", assignable_id: ids).where.not(status: "archived")
                                .update_all(status: "archived", archived_at: @at, updated_at: @at)
        Orm::Exercise.where(id: ids).update_all(status: "archived", archived_at: @at, updated_at: @at)
      end

      # Dans l'ordre d'EXERCISE_COLUMNS.
      def exercise_row(id, node, course_id, position, subject_id)
        [ id, node.public_id, course_id, node.essential_id, subject_id, node.title, node.statement, node.statement_blocks&.to_json, node.figure_key,
          node.hint, node.exercise_type, position, @author_id, "draft", @copy_at, @copy_at ]
      end

      # Dans l'ordre de QUESTION_COLUMNS. Chaînes vides → null, critères vides retirés (ADR-0115) ; la base refuse le reste.
      def question_row(id, exercise_id, node)
        [ id, exercise_id, node.position, node.content, node.explanation, node.question_type, node.numeric_tolerance, node.image_description,
          node.points, node.unit.presence, node.starter.presence, copy_array(node.criteria), node.hint.presence, @copy_at, @copy_at ]
      end

      # Un tableau de textes au format COPY d'une colonne PostgreSQL array : {"a","b"}, chaque texte entre guillemets.
      def copy_array(items)
        quoted = Array(items).map(&:to_s).map(&:strip).reject(&:empty?).map { %("#{it.gsub(/["\\]/) { |char| "\\#{char}" }}") }
        "{#{quoted.join(',')}}"
      end

      # Dans l'ordre d'ANSWER_COLUMNS.
      def answer_row(question_id, node)
        [ question_id, node.position, node.content, node.correct, node.match_content, node.blank, @copy_at, @copy_at ]
      end

      # Le contenu importé est assaini avant d'entrer dans le contenu riche ; un contenu vide ne crée pas de ligne.
      # Le corps est écrit tel que l'assainisseur le rend, sans conversion par ActionText::Content (ADR-0068 §4) :
      # seul le strip que cette conversion appliquait est gardé.
      def write_rich_texts(record_type, nodes, ids)
        rows = nodes.filter_map do |node|
          body = Repositories::Shared::RichTextSanitizer.call(node.content.to_s)
          { record_type:, record_id: ids.fetch(node.slug), name: "content", body: body.strip } if body.present?
        end
        insert(Orm::RichTextRow, rows)
      end
    end
  end
end

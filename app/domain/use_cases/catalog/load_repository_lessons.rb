# 🧠 DOMAINE · UseCases::Catalog::LoadRepositoryLessons
# Rôle : Develop et Staging chargent seuls les leçons à sujets de devoir du dépôt, Develop aussi les leçons v3 du programme, remplacées entières ; production jamais
# ADR  : chargement-automatique-des-lecons-hors-production, 0123, 0108, 0113, 0116, 0121
module UseCases
  module Catalog
    class LoadRepositoryLessons
      KIND = "course_tree"

      # outcome : :skipped (production, PR, nom absent), :no_author (aucun membre d'équipe actif), :unknown_environment (une ligne refusée
      # est laissée), :done. lessons : { nom d'import => :loaded | :created | :replaced | :unchanged | :not_started | :refused | :unpublished |
      # :partially_published | :republished | :failed } ; :created et :replaced disent qu'une leçon du programme v3 (ADR-0123) a été écrite
      # absente ou à la place de celle du même titre, :loaded qu'une leçon à sujets de devoir l'a été (ADR-0122).
      Summary = Data.define(:outcome, :lessons) do
        def initialize(lessons: {}, **) = super
      end

      # source : LessonSourcePort ; reports : ImportReportRepositoryPort ; users : UserRepositoryPort ; courses, essentials, exercises : les repositories
      # du même nom (fiches et exercices en brouillon d'une leçon) ; logger : le journal du déploiement ;
      # taxonomy : TaxonomyRepository (lookup) ; start_import, run_import, publish_cascade : les use cases du même nom, cablés par l'appelant
      # (run_import avec l'adaptateur ImportCourseTree en mode replace: :exercises, run_lesson_import en mode replace: :lesson) ;
      # policy : Policies::Catalog::ManageContentPolicy.
      def initialize(source:, reports:, users:, courses:, essentials:, exercises:, taxonomy:, start_import:, run_import:, run_lesson_import:,
                     publish_cascade:, policy:, logger:, clock:)
        @source = source
        @reports = reports
        @users = users
        @courses = courses
        @essentials = essentials
        @exercises = exercises
        @taxonomy = taxonomy
        @start_import = start_import
        @run_import = run_import
        @run_lesson_import = run_lesson_import
        @publish_cascade = publish_cascade
        @policy = policy
        @logger = logger
        @clock = clock
      end

      # → Result(Summary) | :forbidden (l'auteur n'a plus le droit de gérer les contenus). Les erreurs d'un fichier restent dans sa ligne d'import ;
      # une exception sur une leçon est journalisée avec son nom (statut :failed) et les leçons suivantes sont tentées.
      def call(environment_name:, pr_environment:)
        stage = Entities::Catalog::AutomaticLoadStage.for(name: environment_name, pr_environment:)
        return done(:skipped) if stage.skip?

        actor = @users.oldest_active_team_actor
        return done(:no_author) if actor.nil?

        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return reject_unknown(stage, actor) if stage.unknown?

        chosen = @source.lessons.filter_map do |lesson|
          mode = stage.mode_for(level_directory: lesson.level_directory, subjects: lesson.subjects)
          [ lesson, mode ] if mode
        end
        done(:done, chosen.to_h { |lesson, mode| [ lesson.import_name, load_safely(lesson, mode, actor) ] })
      end

      private

      def done(outcome, lessons = {}) = Shared::Result.success(Summary.new(outcome:, lessons:))

      def reject_unknown(stage, actor)
        error = Entities::Catalog::ImportError.new(path: "$", code: "unknown_environment", params: { name: stage.name })
        @reports.record_rejection(kind: KIND, checksum_sha256: Digest::SHA256.hexdigest("unknown_environment:#{stage.name}"),
                                  imported_by_id: actor.user_id, at: @clock.now, errors: [ error ])
        done(:unknown_environment)
      end

      def load_safely(lesson, mode, actor)
        load(lesson, mode, actor)
      rescue StandardError => error
        @logger.error("[contenus] #{lesson_name(lesson)} : échec (#{error.class} : #{error.message})")
        :failed
      end

      def load(lesson, mode, actor)
        return republish(lesson, actor) if @reports.last_loaded_checksum(kind: KIND, file_name: lesson.import_name) == lesson.checksum_sha256

        loaded = mode == :lesson ? (present?(lesson) ? :replaced : :created) : :loaded

        upload = Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(lesson.content), filename: lesson.import_name)
        started = @start_import.call(actor:, dto: Dtos::Catalog::ImportUploadInput.new(kind: KIND, files: [ upload ]))
        if started.failure?
          @logger.error("[contenus] #{lesson_name(lesson)} : import non démarré (#{started.code} #{started.errors})")
          return :not_started
        end

        ran = (mode == :lesson ? @run_lesson_import : @run_import).call(report_id: started.value.id)
        if ran.failure?
          @logger.error("[contenus] #{lesson_name(lesson)} : import en échec (#{ran.code})")
          return :refused
        end
        return :refused unless ran.value.status == "completed" && ran.value.error_count.zero?

        guarded(lesson) { publish(lesson, actor, slug_of(lesson), loaded) }
      end

      # Fichier inchangé : pas de réimport, mais une publication qui a échoué après un import réussi est reprise (même critère que
      # db/seeds/demo/lecons_completes.rb : cours publié, aucun brouillon restant). Tout publié : rien.
      def republish(lesson, actor)
        guarded(lesson) do
          slug = slug_of(lesson)
          next :unchanged unless pending_publication?(slug)

          publish(lesson, actor, slug, :republished)
        end
      end

      def pending_publication?(slug)
        course = @courses.find_by_slug(slug:)
        course.status != "published" || @exercises.draft_public_ids(course_id: course.id).any? || @essentials.draft_slugs(course_id: course.id).any?
      end

      # La cascade de publication, journalisée ; un échec ne touche ni l'import ni les autres leçons.
      def publish(lesson, actor, slug, done)
        result = @publish_cascade.call(actor:, root: :course, slug:)
        if result.failure?
          @logger.error("[contenus] #{lesson_name(lesson)} : publication refusée (#{result.code})")
          return :unpublished
        end

        skipped = result.value.skipped
        if skipped.positive?
          @logger.warn("[contenus] #{lesson_name(lesson)} : #{skipped} exercice(s) laissé(s) en brouillon (non publiables), #{result.value.exercises} publié(s)")
          return :partially_published
        end

        @logger.info("[contenus] #{lesson_name(lesson)} : publiée, #{result.value.exercises} exercice(s) publié(s)")
        done
      end

      def guarded(lesson)
        yield
      rescue StandardError => error
        @logger.error("[contenus] #{lesson_name(lesson)} : publication interrompue (#{error.class} : #{error.message})")
        :unpublished
      end

      def lesson_name(lesson) = JSON.parse(lesson.content).fetch("courses").first["name"].to_s.squish

      # La leçon que l'import vient d'écrire (ou de remplacer), retrouvée par la clé de doublon de l'import.
      def slug_of(lesson) = @courses.slugs_by_key.fetch(key_of(lesson))

      # Avant l'import : une leçon du même titre (niveau, matière, série) est-elle déjà là ? Un niveau ou une matière inconnus : non (l'import
      # refusera la leçon dans sa ligne).
      def present?(lesson) = @courses.slugs_by_key.key?(key_of(lesson))

      def key_of(lesson)
        course = JSON.parse(lesson.content).fetch("courses").first
        lookup = @taxonomy.lookup
        [ Entities::Shared::NaturalKey.compact(course["name"].to_s.squish), lookup.resolve_level(course["level_name"])&.id,
          lookup.resolve_material(course["material_name"])&.id, lookup.resolve_series(course["series_name"])&.id ]
      end
    end
  end
end

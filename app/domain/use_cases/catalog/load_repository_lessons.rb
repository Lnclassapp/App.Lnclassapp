# 🧠 DOMAINE · UseCases::Catalog::LoadRepositoryLessons
# Rôle : Develop et Staging chargent seuls les leçons à sujets de devoir du dépôt (chaîne d'import, puis publication) ; production jamais
# ADR  : chargement-automatique-des-lecons-hors-production, 0108, 0113, 0116, 0121
module UseCases
  module Catalog
    class LoadRepositoryLessons
      KIND = "course_tree"

      # outcome : :skipped (production, PR, nom absent), :no_author (aucun membre d'équipe actif), :unknown_environment (une ligne refusée
      # est laissée), :done. lessons : { nom d'import => :loaded | :unchanged | :not_started | :refused | :unpublished }.
      Summary = Data.define(:outcome, :lessons) do
        def initialize(lessons: {}, **) = super
      end

      # source : LessonSourcePort ; reports : ImportReportRepositoryPort ; users : UserRepositoryPort ; courses : CourseRepositoryPort ;
      # taxonomy : TaxonomyRepository (lookup) ; start_import, run_import, publish_cascade : les use cases du même nom, cablés par l'appelant
      # (run_import avec l'adaptateur ImportCourseTree en mode replace_exercises) ; policy : Policies::Catalog::ManageContentPolicy.
      def initialize(source:, reports:, users:, courses:, taxonomy:, start_import:, run_import:, publish_cascade:, policy:, clock:)
        @source = source
        @reports = reports
        @users = users
        @courses = courses
        @taxonomy = taxonomy
        @start_import = start_import
        @run_import = run_import
        @publish_cascade = publish_cascade
        @policy = policy
        @clock = clock
      end

      # → Result(Summary) | :forbidden (l'auteur n'a plus le droit de gérer les contenus). Les erreurs d'un fichier restent dans sa ligne d'import ; une exception imprévue remonte à l'appelant.
      def call(environment_name:, pr_environment:)
        stage = Entities::Catalog::AutomaticLoadStage.for(name: environment_name, pr_environment:)
        return done(:skipped) if stage.skip?

        actor = @users.oldest_active_team_actor
        return done(:no_author) if actor.nil?

        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return reject_unknown(stage, actor) if stage.unknown?

        done(:done, @source.lessons.to_h { [ it.import_name, load(it, actor) ] })
      end

      private

      def done(outcome, lessons = {}) = Shared::Result.success(Summary.new(outcome:, lessons:))

      def reject_unknown(stage, actor)
        error = Entities::Catalog::ImportError.new(path: "$", code: "unknown_environment", params: { name: stage.name })
        @reports.record_rejection(kind: KIND, checksum_sha256: Digest::SHA256.hexdigest("unknown_environment:#{stage.name}"),
                                  imported_by_id: actor.user_id, at: @clock.now, errors: [ error ])
        done(:unknown_environment)
      end

      def load(lesson, actor)
        return :unchanged if @reports.last_loaded_checksum(kind: KIND, file_name: lesson.import_name) == lesson.checksum_sha256

        upload = Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(lesson.content), filename: lesson.import_name)
        started = @start_import.call(actor:, dto: Dtos::Catalog::ImportUploadInput.new(kind: KIND, files: [ upload ]))
        return :not_started if started.failure?

        ran = @run_import.call(report_id: started.value.id)
        return :refused unless ran.success? && ran.value.status == "completed" && ran.value.error_count.zero?

        @publish_cascade.call(actor:, root: :course, slug: slug_of(lesson)).success? ? :loaded : :unpublished
      end

      # La leçon que l'import vient d'écrire (ou de remplacer), retrouvée par la clé de doublon de l'import.
      def slug_of(lesson)
        course = JSON.parse(lesson.content).fetch("courses").first
        lookup = @taxonomy.lookup
        key = [ Entities::Shared::NaturalKey.compact(course["name"]), lookup.resolve_level(course["level_name"]).id,
                lookup.resolve_material(course["material_name"]).id, lookup.resolve_series(course["series_name"])&.id ]
        @courses.slugs_by_key.fetch(key)
      end
    end
  end
end

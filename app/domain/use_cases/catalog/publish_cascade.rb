# 🧠 DOMAINE · UseCases::Catalog::PublishCascade
# Rôle : « Tout publier » : un cours (ou une fiche), puis ses fiches et ses exercices brouillons, en une transaction
# ADR  : 0026, 0028, 0035 (amendement du 2026-10-01), 0089 · réutilise PublishCourse, PublishEssential, PublishExercise
module UseCases
  module Catalog
    class PublishCascade
      ROOTS = %i[course essential].freeze

      # root : la racine relue ; essentials, exercises : nombres publiés ; skipped : exercices restés en brouillon
      # (sans question bien construite, :not_publishable).
      Summary = Data.define(:root, :essentials, :exercises, :skipped)

      def initialize(courses:, essentials:, exercises:, publish_course:, publish_essential:, publish_exercise:, transaction:, policy:)
        @courses = courses
        @essentials = essentials
        @exercises = exercises
        @publish_course = publish_course
        @publish_essential = publish_essential
        @publish_exercise = publish_exercise
        @transaction = transaction
        @policy = policy
      end

      # root : :course | :essential. Seuls les brouillons descendent : une fiche ou un exercice archivé le reste. La racine
      # est publiée si elle ne l'est pas (brouillon ou archivée), avec les règles de son use case ; chaque publication est
      # inscrite au journal par son use case.
      # → Result(Summary) | :forbidden | :not_found | :conflict — alors rien n'est écrit : base parent_not_published,
      #   image_slots_left ou image_alts_blank (racine fiche), ou essential_not_ready avec name (une fiche du cours, ADR-0089)
      def call(actor:, root:, slug:)
        raise ArgumentError, "racine inconnue : #{root}" unless ROOTS.include?(root)

        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        record = repository(root).find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if record.nil?

        @transaction.call { cascade(actor, root, record) }
      end

      private

      def cascade(actor, root, record)
        not_ready = root == :course ? first_essential_not_ready(record) : nil
        return not_ready if not_ready

        unless record.status == "published"
          published = publish_root(actor, root, record.slug)
          return published if published.failure?
        end

        essentials = root == :course ? count_published(@essentials.draft_slugs(course_id: record.id)) { @publish_essential.call(actor:, slug: it) } : 0
        under = root == :course ? { course_id: record.id } : { essential_id: record.id }
        drafts = @exercises.draft_public_ids(**under)
        exercises = count_published(drafts) { @publish_exercise.call(actor:, public_id: it) }

        Shared::Result.success(Summary.new(root: repository(root).find_by_slug(slug: record.slug), essentials:, exercises:,
                                           skipped: drafts.size - exercises))
      end

      # ADR-0089 §4.4 : toutes les fiches brouillons du cours sont vérifiées avant toute écriture ; la première qui n'est pas
      # prête (emplacement d'image restant, image sans texte de remplacement) refuse tout et se nomme.
      def first_essential_not_ready(course)
        @essentials.draft_slugs(course_id: course.id).each do |slug|
          essential = @essentials.find_by_slug(slug:)
          next if essential.nil? || PublishEssential.images_ready(essential).success?

          return Shared::Result.failure(:conflict, errors: { base: [ :essential_not_ready ], name: essential.name })
        end
        nil
      end

      def publish_root(actor, root, slug)
        root == :course ? @publish_course.call(actor:, slug:) : @publish_essential.call(actor:, slug:)
      end

      def count_published(keys, &publish) = keys.count { publish.call(it).success? }

      def repository(root) = root == :course ? @courses : @essentials
    end
  end
end

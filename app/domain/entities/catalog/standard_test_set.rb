# 🧠 DOMAINE · Entities::Catalog::StandardTestSet
# Rôle : le manifeste du jeu de test standard (établissements, classes, comptes, cas difficiles, leçons) et son contrôle contre les fichiers du dépôt
# ADR  : standard-de-test, 0039, 0116
module Entities
  module Catalog
    class StandardTestSet
      LESSON_VERSION = 3
      School = Data.define(:key, :type, :cycle, :drena, :students, :activity)
      Classroom = Data.define(:school, :key, :level, :series, :rank)
      Cases = Data.define(:empty_classroom, :student_without_activity, :full_classroom, :full_classroom_size)
      StudentAccount = Data.define(:school, :classroom)
      TeacherAccount = Data.define(:key, :subject, :schools)
      DirectionAccount = Data.define(:key, :school)
      TeamAccount = Data.define(:key, :role, :drena)
      Accounts = Data.define(:students, :teachers, :directions, :team)
      Error = Data.define(:code, :reference) do
        def message
          text = case code
          when :file_missing then "fichier absent du dépôt"
          when :not_v3 then "fichier qui n'est pas au format 3"
          when :couple_missing then "couple ayant du v3 mais absent du manifeste"
          when :without_v3_has_v3 then "couple listé sans v3 qui a du v3 dans le dépôt"
          when :couple_unknown then "couple listé sans v3 qui n'existe pas dans le dépôt"
          else raise ArgumentError, "code d'erreur inconnu : #{code.inspect}"
          end
          "#{text} : #{reference}"
        end
      end

      attr_reader :schools, :classrooms, :cases, :accounts, :lessons, :longest, :without_v3

      # manifest : le Hash du YAML db/seeds/standard/jeu.yml, parsé par l'appelant (clés texte).
      def initialize(manifest)
        @schools = manifest.fetch("etablissements").map { build_school(it) }
        @classrooms = manifest.fetch("etablissements").flat_map { build_classrooms(it, manifest.fetch("programme")) }
        @cases = build_cases(manifest.fetch("cas"))
        @accounts = build_accounts(manifest.fetch("comptes"))
        @lessons = manifest.fetch("lecons").dup.freeze
        @longest = manifest.fetch("longue")
        @without_v3 = manifest.fetch("sans_v3").dup.freeze
      end

      def school(key) = schools.find { it.key == key } || raise(KeyError, "établissement inconnu : #{key}")
      def classrooms_of(school_key) = classrooms.select { it.school == school_key }

      # Les chemins relatifs à docs/contenus/lecons-traitees/ : <dossier>/<matière>/<fichier>.
      def lesson_paths = lessons.map { |couple, file| "#{couple}/#{file}" }
      def expected_paths = (lesson_paths + [ longest ]).uniq

      # files : { chemin relatif => version du fichier } pour tous les fichiers du dépôt. Rend la liste des erreurs, vide si le manifeste est juste.
      # Seul l'entier 3 est du v3 : une version absente, textuelle ("3") ou décimale (3.0) ne l'est pas.
      def errors(files)
        missing = expected_paths.filter_map do |path|
          if !files.key?(path) then Error.new(:file_missing, path)
          elsif !v3?(files.fetch(path)) then Error.new(:not_v3, path)
          end
        end
        missing + without_v3_errors(files) + forgotten_couples(files).map { Error.new(:couple_missing, it) }
      end

      private

      def v3?(version) = version.is_a?(Integer) && version == LESSON_VERSION
      def couple_of(path) = path.split("/").first(2).join("/")
      def v3_couples(files) = files.select { |_, version| v3?(version) }.keys.map { couple_of(it) }.uniq

      # Un couple listé sans v3 doit exister dans le dépôt et n'y avoir aucun fichier v3.
      def without_v3_errors(files)
        existing = files.keys.map { couple_of(it) }.uniq
        with_v3 = v3_couples(files)
        without_v3.sort.filter_map do |couple|
          if !existing.include?(couple) then Error.new(:couple_unknown, couple)
          elsif with_v3.include?(couple) then Error.new(:without_v3_has_v3, couple)
          end
        end
      end

      def forgotten_couples(files) = (v3_couples(files) - covered_couples - without_v3).sort

      # La leçon longue couvre son couple, même si le manifeste n'y met pas la leçon 1.
      def covered_couples = lessons.keys | [ couple_of(longest) ]

      def build_school(data)
        School.new(key: data.fetch("cle"), type: data.fetch("type"), cycle: data.fetch("cycle"), drena: data.fetch("drena"),
                   students: data["eleves"], activity: data["activite"])
      end

      def build_classrooms(school, programme)
        keys = school.fetch("classes")
        keys = programme_keys(programme) if keys == "tout_le_programme"
        raise ArgumentError, "classes inconnues : #{keys.inspect}" unless keys.is_a?(Array)

        per_series = school.fetch("classes_par_serie", 1)
        keys.flat_map do |key|
          level, series = key.split("-", 2)
          (1..per_series).map do |rank|
            Classroom.new(school: school.fetch("cle"), key: per_series > 1 ? "#{key}-#{rank}" : key, level:, series:, rank:)
          end
        end
      end

      def programme_keys(programme)
        programme.fetch("sans_serie") +
          programme.fetch("avec_series").flat_map { |level| level.fetch("series").map { |series| "#{level.fetch('niveau')}-#{series}" } }
      end

      def build_cases(data)
        known = classrooms.map { "#{it.school}/#{it.key}" }
        refs = data.values_at("classe_vide", "eleve_sans_activite", "classe_pleine")
        unknown = refs - known
        raise ArgumentError, "cas sur une classe inconnue : #{unknown.join(', ')}" if unknown.any?

        Cases.new(empty_classroom: refs[0], student_without_activity: refs[1], full_classroom: refs[2],
                  full_classroom_size: data.fetch("classe_pleine_effectif"))
      end

      def build_accounts(data)
        raise ArgumentError, "comptes élèves inconnus : #{data['eleves'].inspect}" unless data.fetch("eleves") == "un_par_classe"

        Accounts.new(
          students: classrooms.map { StudentAccount.new(school: it.school, classroom: it.key) },
          teachers: data.fetch("enseignants").map { TeacherAccount.new(key: it.fetch("cle"), subject: it.fetch("matiere"), schools: it.fetch("etablissements")) },
          directions: data.fetch("directions").map { DirectionAccount.new(key: it.fetch("cle"), school: it.fetch("etablissement")) },
          team: data.fetch("equipe").map { TeamAccount.new(key: it.fetch("cle"), role: it.fetch("role"), drena: it["drena"]) }
        )
      end
    end
  end
end

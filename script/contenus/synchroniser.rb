# frozen_string_literal: true

# Copie figée des leçons relues (ADR contenus-dans-un-depot-dedie-copie-figee §4) : les leçons de `lecons/` d'un clone du dépôt
# Kamkara007/App.Lnclassapp-contenus sont contrôlées une à une (valider.rb), puis copiées dans docs/contenus/lecons-traitees/, et la version
# copiée est écrite dans docs/contenus/VERSION. Rien n'est copié si une seule leçon échoue.
# Usage : ruby script/contenus/synchroniser.rb <clone du dépôt de contenus> [--forcer]   (version plus ancienne : --forcer)
#         ruby script/contenus/synchroniser.rb --verifier                               (CI : la copie correspond à VERSION)
# Ruby pur : ni Rails ni bundler. Code de sortie 1 en cas de refus.
require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "time"
require "tmpdir"
require "yaml"
require_relative "valider"

module Contenus
  class Synchroniser
    ROOT = Pathname(__dir__).join("../..").expand_path
    TARGET = ROOT.join("docs/contenus/lecons-traitees")
    VERSION_FILE = ROOT.join("docs/contenus/VERSION")
    LESSONS = "lecons"
    PATTERN = "*/*/*.json" # <niveau-série>/<matière>/<leçon>.json, comme le chargement automatique
    DEFAULT_REPOSITORY = "Kamkara007/App.Lnclassapp-contenus"

    def self.run(argv, out: $stdout)
      return new(out:).verifier if argv == [ "--verifier" ]

      source, *flags = argv
      if source.nil? || source.start_with?("--") || (flags - [ "--forcer" ]).any?
        out.puts "Usage : ruby script/contenus/synchroniser.rb <clone du dépôt de contenus> [--forcer] | --verifier"
        return 1
      end
      new(source: Pathname(source).expand_path, out:).synchroniser(forcer: flags.include?("--forcer"))
    end

    def initialize(source: nil, target: TARGET, version_file: VERSION_FILE, out: $stdout)
      @source = source && Pathname(source)
      @target = Pathname(target)
      @version_file = Pathname(version_file)
      @out = out
    end

    def synchroniser(forcer: false)
      sha = git("rev-parse", "HEAD") or return refuse("#{@source} n'est pas un clone git du dépôt de contenus")
      return refuse("#{@source} a des changements non commités : la copie doit nommer une version exacte") unless git("status", "--porcelain").to_s.empty?
      return refuse("aucune leçon dans #{@source.join(LESSONS)}") if (files = lesson_files(@source.join(LESSONS))).empty?
      return 1 unless forcer || forward?(sha)
      return 1 unless all_valid?(files)

      replace_copy(files)
      write_version(sha)
      @out.puts "✓ #{files.size} leçon(s) copiée(s) depuis #{repository} à #{sha[0, 12]} ; version écrite dans #{@version_file.basename}"
      0
    end

    def verifier
      unless @version_file.file?
        @out.puts "aucune version synchronisée (#{@version_file.basename} absent) : rien à vérifier"
        return 0
      end
      expected = YAML.safe_load_file(@version_file).fetch("empreinte")
      return 0 if fingerprint(lesson_files(@target)) == expected

      @out.puts "✗ docs/contenus/lecons-traitees/ ne correspond pas à #{@version_file.basename} : une leçon a été changée à la main. " \
                "Corrige-la dans le dépôt de contenus, puis lance script/contenus/synchroniser.rb."
      1
    end

    private

    def lesson_files(root) = root.directory? ? root.glob(PATTERN).select(&:file?).sort : []

    def all_valid?(files)
      failed = files.reject do |file|
        errors = begin
          Valider.new(JSON.parse(file.read(encoding: "UTF-8"))).call.errors
        rescue JSON::ParserError => e
          [ "JSON illisible : #{e.message[0, 120]}" ]
        end
        errors.first(5).each { |message| @out.puts "✗ #{relative(file)} : #{message}" }
        errors.empty?
      end
      return true if failed.empty?

      refuse("#{failed.size} leçon(s) refusée(s) par valider.rb : rien n'est copié")
      false
    end

    # Une version déjà copiée qui descend de la nouvelle est plus récente : on ne revient pas en arrière sans --forcer.
    def forward?(sha)
      previous = @version_file.file? && YAML.safe_load_file(@version_file)["sha"]
      return true if !previous || previous == sha || !git("cat-file", "-e", "#{previous}^{commit}")
      return true unless git("merge-base", "--is-ancestor", sha, previous)

      refuse("#{sha[0, 12]} est plus ancienne que la version copiée (#{previous[0, 12]}) : relance avec --forcer pour revenir en arrière")
      false
    end

    # On prépare la copie à côté, puis on l'échange : une erreur d'écriture laisse l'ancienne copie en place.
    def replace_copy(files)
      @target.dirname.mkpath
      staging = Pathname(Dir.mktmpdir("lecons-traitees", @target.dirname))
      files.each do |file|
        destination = staging.join(relative(file))
        destination.dirname.mkpath
        FileUtils.cp(file, destination)
      end
      retired = @target.dirname.join(".#{@target.basename}.ancienne")
      FileUtils.rm_rf(retired)
      FileUtils.mv(@target, retired) if @target.exist?
      FileUtils.mv(staging, @target)
      FileUtils.rm_rf(retired)
    ensure
      FileUtils.rm_rf(staging) if staging&.exist?
    end

    def write_version(sha)
      copied = lesson_files(@target)
      @version_file.write(<<~YAML)
        # Copie figée des leçons relues : écrite par script/contenus/synchroniser.rb, jamais à la main (ADR contenus-dans-un-depot-dedie-copie-figee).
        #{YAML.dump('depot' => repository, 'sha' => sha, 'date' => Time.now.utc.iso8601, 'fichiers' => copied.size,
                    'empreinte' => fingerprint(copied)).delete_prefix("---\n")}
      YAML
    end

    def fingerprint(files)
      Digest::SHA256.hexdigest(files.map { |file| "#{file.relative_path_from(file.dirname.dirname.dirname)}\0#{Digest::SHA256.file(file).hexdigest}\n" }.join)
    end

    def relative(file) = file.relative_path_from(file.dirname.dirname.dirname).to_s

    def repository
      url = git("remote", "get-url", "origin").to_s
      url[%r{([^/:]+/[^/]+?)(?:\.git)?\z}, 1] || DEFAULT_REPOSITORY
    end

    def git(*args)
      output, status = Open3.capture2e("git", "-C", @source.to_s, *args)
      status.success? ? output.strip : nil
    rescue SystemCallError
      nil
    end

    def refuse(message)
      @out.puts "✗ #{message}"
      1
    end
  end
end

($PROGRAM_NAME == __FILE__) && exit(Contenus::Synchroniser.run(ARGV))

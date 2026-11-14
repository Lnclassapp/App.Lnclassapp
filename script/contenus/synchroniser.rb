# frozen_string_literal: true

# Copie figée des leçons relues (ADR-0134 §4) : les leçons de `lecons/` d'un clone du dépôt
# App.Lnclassapp-contenus sont contrôlées une à une (valider.rb), puis copiées dans docs/contenus/lecons-traitees/, et la version
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
      # La racine du clone, pas un dossier d'un autre dépôt (git -C remonte sinon jusqu'au dépôt parent, l'application par exemple).
      sha = root? && git("rev-parse", "HEAD") or return refuse("#{@source} n'est pas la racine d'un clone git du dépôt de contenus")
      return refuse("#{@source} a des changements non commités : la copie doit nommer une version exacte") unless git("status", "--porcelain") == ""
      files = committed_lessons or return 1
      return refuse("aucune leçon dans #{@source.join(LESSONS)}") if files.empty?
      return 1 unless forcer || forward?(sha)
      return 1 unless all_valid?(files)

      replace_copy(files)
      write_version(sha)
      @out.puts "✓ #{files.size} leçon(s) copiée(s) depuis #{repository} à #{sha[0, 12]} ; version écrite dans #{@version_file.basename}"
      0
    end

    # Sans VERSION, seule une copie vide passe : supprimer VERSION ne désactive pas le contrôle.
    def verifier
      files = all_files(@target)
      unless @version_file.file?
        return 0.tap { @out.puts "aucune version synchronisée et aucune leçon copiée : rien à vérifier" } if files.empty?

        return refuse("#{@version_file.basename} absent alors que docs/contenus/lecons-traitees/ contient #{files.size} fichier(s) : " \
                      "lance script/contenus/synchroniser.rb")
      end
      expected = YAML.safe_load_file(@version_file).fetch("empreinte")
      return 0 if fingerprint(files) == expected

      refuse("docs/contenus/lecons-traitees/ ne correspond pas à #{@version_file.basename} : une leçon a été changée à la main. " \
             "Corrige-la dans le dépôt de contenus, puis lance script/contenus/synchroniser.rb.")
    end

    private

    def root?
      top = git("rev-parse", "--show-toplevel")
      !top.nil? && File.realpath(top) == File.realpath(@source)
    rescue SystemCallError
      false
    end

    # Les seuls fichiers de la version (git ls-tree HEAD) : un fichier ignoré par .gitignore n'est pas copié. Tout fichier de lecons/
    # hors du motif <niveau-série>/<matière>/<leçon>.json est refusé, plutôt que laissé de côté sans rien dire.
    def committed_lessons
      listing = git("ls-tree", "-r", "--name-only", "HEAD", "--", "#{LESSONS}/") or return refuse("lecture de la version impossible (git ls-tree)") && nil
      paths = listing.lines.map(&:chomp).reject(&:empty?).map { it.delete_prefix("#{LESSONS}/") }
      misplaced = paths.reject { File.fnmatch?(PATTERN, it, File::FNM_PATHNAME) }
      misplaced.each { @out.puts "✗ #{LESSONS}/#{it} : hors du rangement <niveau-série>/<matière>/<leçon>.json" }
      return refuse("#{misplaced.size} fichier(s) mal rangé(s) dans #{LESSONS}/ : rien n'est copié") && nil if misplaced.any?

      paths.sort.map { [ it, @source.join(LESSONS, it) ] }
    end

    def all_files(root) = root.directory? ? root.glob("**/*", File::FNM_DOTMATCH).select(&:file?).map { [ it.relative_path_from(root).to_s, it ] }.sort : []

    def all_valid?(files)
      failed = files.reject do |name, file|
        errors = begin
          Valider.new(JSON.parse(file.read(encoding: "UTF-8"))).call.errors
        rescue JSON::ParserError => e
          [ "JSON illisible : #{e.message[0, 120]}" ]
        end
        errors.first(5).each { |message| @out.puts "✗ #{name} : #{message}" }
        errors.empty?
      end
      return true if failed.empty?

      refuse("#{failed.size} leçon(s) refusée(s) par valider.rb : rien n'est copié")
      false
    end

    # Une version déjà copiée qui descend de la nouvelle est plus récente : on ne revient pas en arrière sans --forcer. Une version
    # copiée inconnue du clone (clone superficiel, autre dépôt) ou une erreur de git ne se lit pas comme « plus récente ».
    def forward?(sha)
      return true unless @version_file.file?

      previous = YAML.safe_load_file(@version_file)["sha"]
      return true if previous == sha
      return !refuse("#{@version_file.basename} ne nomme aucune version : relance avec --forcer") unless previous.is_a?(String) && !previous.empty?
      return !refuse("version copiée #{previous[0, 12]} inconnue de ce clone (clone superficiel ?) : relance avec --forcer") unless git("cat-file", "-e", "#{previous}^{commit}")

      case git_status("merge-base", "--is-ancestor", sha, previous)
      when 1 then true
      when 0 then !refuse("#{sha[0, 12]} est plus ancienne que la version copiée (#{previous[0, 12]}) : relance avec --forcer pour revenir en arrière")
      else !refuse("comparaison des versions impossible (git merge-base) : relance avec --forcer")
      end
    end

    # On prépare la copie à côté, puis on l'échange ; si l'échange échoue, l'ancienne copie est remise en place.
    def replace_copy(files)
      retired = @target.dirname.join(".#{@target.basename}.ancienne")
      raise "#{retired} existe sans #{@target.basename} : un échange précédent a été interrompu, remets-le en place à la main" if retired.exist? && !@target.exist?

      @target.dirname.mkpath
      staging = Pathname(Dir.mktmpdir("lecons-traitees", @target.dirname))
      files.each do |name, file|
        destination = staging.join(name)
        destination.dirname.mkpath
        FileUtils.cp(file, destination)
      end
      FileUtils.rm_rf(retired)
      FileUtils.mv(@target, retired) if @target.exist?
      begin
        FileUtils.mv(staging, @target)
      rescue StandardError
        FileUtils.mv(retired, @target) if retired.exist? && !@target.exist?
        raise
      end
      FileUtils.rm_rf(retired)
    ensure
      FileUtils.rm_rf(staging) if staging&.exist?
    end

    def write_version(sha)
      copied = all_files(@target)
      @version_file.write(<<~YAML)
        # Copie figée des leçons relues : écrite par script/contenus/synchroniser.rb, jamais à la main (ADR-0134).
        #{YAML.dump('depot' => repository, 'sha' => sha, 'date' => Time.now.utc.iso8601, 'fichiers' => copied.size,
                    'empreinte' => fingerprint(copied)).delete_prefix("---\n")}
      YAML
    end

    def fingerprint(files) = Digest::SHA256.hexdigest(files.map { |name, file| "#{name}\0#{Digest::SHA256.file(file).hexdigest}\n" }.join)

    def repository
      url = git("remote", "get-url", "origin").to_s
      url[%r{([^/:]+/[^/]+?)(?:\.git)?\z}, 1] || "inconnu (pas de remote origin)"
    end

    def git(*args)
      output, status = Open3.capture2e("git", "-C", @source.to_s, *args)
      status.success? ? output.strip : nil
    rescue SystemCallError
      nil
    end

    def git_status(*args)
      _, status = Open3.capture2e("git", "-C", @source.to_s, *args)
      status.exitstatus
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

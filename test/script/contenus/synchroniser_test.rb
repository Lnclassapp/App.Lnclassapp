require "test_helper"
require "open3"
require "yaml"
require Rails.root.join("script/contenus/synchroniser")

# ADR-0134 §4 et §7 : la copie figée des leçons ne s'écrit que depuis une version
# du dépôt de contenus, après contrôle de chaque fichier, et la CI repère une leçon modifiée sans nouvelle version.
class ContenusSynchroniserTest < ActiveSupport::TestCase
  setup do
    @dir = Pathname(Dir.mktmpdir("synchroniser"))
    @source = @dir.join("contenus")
    @target = @dir.join("app/lecons-traitees")
    @version = @dir.join("app/VERSION")
    @out = StringIO.new
    @target.mkpath
    git("init", "-q", "-b", "main")
    git("config", "user.email", "test@example.invalid")
    git("config", "user.name", "Test")
  end

  teardown { FileUtils.rm_rf(@dir) }

  def git(*args)
    @source.mkpath
    output, status = Open3.capture2e("git", "-C", @source.to_s, *args)
    assert status.success?, output
    output.strip
  end

  def lesson(path, document = revision_sheet_document)
    file = @source.join("lecons", path)
    file.dirname.mkpath
    file.write(JSON.pretty_generate(document))
  end

  def commit(message = "leçons")
    git("add", "-A")
    git("commit", "-q", "-m", message)
    git("rev-parse", "HEAD")
  end

  def lesson_bytes(path) = @source.join("lecons", path).binread

  def snapshot = [ @version.exist? && @version.binread, @target.glob("**/*").select(&:file?).sort.map { [ it.to_s, it.binread ] } ]

  def synchroniser(**options) = Contenus::Synchroniser.new(source: @source, target: @target, version_file: @version, out: @out).synchroniser(**options)

  def verifier = Contenus::Synchroniser.new(target: @target, version_file: @version, out: @out).verifier

  test "copie les leçons d'une version, retire celles qui n'y sont plus et écrit la version" do
    git("remote", "add", "origin", "https://github.com/Exemple/App.Lnclassapp-contenus.git")
    lesson("3eme/mathematiques/01-thales.json")
    sha = commit
    stale = @target.join("3eme/francais/ancienne.json")
    stale.dirname.mkpath
    stale.write("{}")

    assert_equal 0, synchroniser
    assert_equal lesson_bytes("3eme/mathematiques/01-thales.json"), @target.join("3eme/mathematiques/01-thales.json").binread
    assert_not stale.exist?, "une leçon absente de la version est retirée de la copie"
    version = YAML.safe_load_file(@version)
    assert_equal "Exemple/App.Lnclassapp-contenus", version.fetch("depot")
    assert_equal sha, version.fetch("sha")
    assert_equal 1, version.fetch("fichiers")
    expected = Digest::SHA256.hexdigest("3eme/mathematiques/01-thales.json\0#{Digest::SHA256.hexdigest(lesson_bytes('3eme/mathematiques/01-thales.json'))}\n")
    assert_equal expected, version.fetch("empreinte")
  end

  test "refuse une version dont une leçon échoue au contrôle : rien n'est copié" do
    lesson("3eme/mathematiques/01-thales.json")
    broken = Marshal.load(Marshal.dump(revision_sheet_document))
    broken["courses"].first["notions"][1].delete("exercise")
    lesson("3eme/mathematiques/02-faute.json", broken)
    commit
    kept = @target.join("3eme/francais/en-place.json")
    kept.dirname.mkpath
    kept.write("{}")

    assert_equal 1, synchroniser
    assert kept.exist?, "la copie en place reste intacte"
    assert_not @target.join("3eme/mathematiques/01-thales.json").exist?
    assert_not @version.exist?
    assert_includes @out.string, "02-faute.json"
  end

  test "une version invalide laisse la copie et VERSION d'une synchronisation précédente identiques, octet pour octet" do
    lesson("3eme/mathematiques/01-thales.json")
    commit("v1")
    assert_equal 0, synchroniser
    before = snapshot
    broken = Marshal.load(Marshal.dump(revision_sheet_document))
    broken["courses"].first["notions"][1].delete("exercise")
    lesson("3eme/mathematiques/01-thales.json", broken)
    lesson("3eme/mathematiques/02-pythagore.json")
    commit("v2 fautive")

    assert_equal 1, synchroniser
    assert_equal before, snapshot
  end

  test "refuse un JSON illisible : rien n'est copié" do
    file = @source.join("lecons/3eme/svt/01-cassee.json")
    file.dirname.mkpath
    file.write("{ pas du json")
    commit
    kept = @target.join("3eme/francais/en-place.json")
    kept.dirname.mkpath
    kept.write("{}")

    assert_equal 1, synchroniser
    assert_not @version.exist?
    assert_equal "{}", kept.read
    assert_includes @out.string, "01-cassee.json"
  end

  test "refuse une source qui n'est pas la racine d'un dépôt git, ou dont l'arbre n'est pas propre" do
    plain = @dir.join("pas-un-depot")
    FileUtils.mkdir_p(plain.join("lecons/3eme/mathematiques"))
    plain.join("lecons/3eme/mathematiques/01-thales.json").write(JSON.generate(revision_sheet_document))
    assert_equal 1, Contenus::Synchroniser.new(source: plain, target: @target, version_file: @version, out: @out).synchroniser
    assert_includes @out.string, "n'est pas la racine d'un clone git"

    lesson("3eme/mathematiques/01-thales.json")
    commit
    nested = Contenus::Synchroniser.new(source: @source.join("lecons"), target: @target, version_file: @version, out: @out)
    assert_equal 1, nested.synchroniser, "un dossier à l'intérieur d'un dépôt n'est pas une source"
    assert_not @version.exist?

    lesson("3eme/mathematiques/02-non-commitee.json")
    assert_equal 1, synchroniser
    assert_not @version.exist?
  end

  test "refuse de revenir à une version plus ancienne, sauf si on le force" do
    lesson("3eme/mathematiques/01-thales.json")
    old = commit("v1")
    lesson("3eme/mathematiques/02-pythagore.json")
    commit("v2")
    assert_equal 0, synchroniser
    git("checkout", "-q", old)

    assert_equal 1, synchroniser
    assert_equal 2, YAML.safe_load_file(@version).fetch("fichiers")
    assert_equal 0, synchroniser(forcer: true)
    assert_equal old, YAML.safe_load_file(@version).fetch("sha")
  end

  test "la vérification passe sur une copie synchronisée et refuse une leçon modifiée, ajoutée ou retirée à la main" do
    lesson("3eme/mathematiques/01-thales.json")
    commit
    assert_equal 0, synchroniser
    assert_equal 0, verifier

    copy = @target.join("3eme/mathematiques/01-thales.json")
    original = copy.read
    refused = lambda do
      @out = StringIO.new
      assert_equal 1, verifier
      assert_includes @out.string, "script/contenus/synchroniser.rb"
    end
    copy.write(original.sub("}", ", \"x\": 1}"))
    refused.call
    copy.write(original)

    @target.join("3eme/mathematiques/02-ajout.json").write("{}")
    refused.call
    @target.join("3eme/mathematiques/02-ajout.json").delete

    copy.delete
    refused.call
  end

  test "sans VERSION, la vérification ne passe que sur une copie vide" do
    assert_equal 0, verifier
    assert_includes @out.string, "rien à vérifier"

    @target.join("3eme").mkpath
    @target.join("3eme/libre.json").write("{}")
    assert_equal 1, verifier, "supprimer VERSION ne désactive pas le contrôle"
    assert_includes @out.string, "VERSION absent"
  end

  test "la vérification voit un fichier ajouté à la main hors du rangement" do
    lesson("3eme/mathematiques/01-thales.json")
    commit
    assert_equal 0, synchroniser
    @target.join("3eme/egare.json").write("{}")

    assert_equal 1, verifier
  end

  test "ne copie que les fichiers de la version : un fichier ignoré par git reste dehors" do
    @source.join(".gitignore").write("*-brouillon.json\n")
    lesson("3eme/mathematiques/01-thales.json")
    commit
    lesson("3eme/mathematiques/02-brouillon.json")

    assert_equal 0, synchroniser
    assert_not @target.join("3eme/mathematiques/02-brouillon.json").exist?
    assert_equal 1, YAML.safe_load_file(@version).fetch("fichiers")
  end

  test "refuse un fichier rangé hors de <niveau-série>/<matière>/<leçon>.json, en le nommant" do
    lesson("3eme/mathematiques/01-thales.json")
    file = @source.join("lecons/3eme/x.json")
    file.write(JSON.generate(revision_sheet_document))
    commit

    assert_equal 1, synchroniser
    assert_includes @out.string, "lecons/3eme/x.json"
    assert_not @version.exist?
  end

  test "refuse sans --forcer une version copiée inconnue du clone (clone superficiel d'une version plus ancienne)" do
    lesson("3eme/mathematiques/01-thales.json")
    commit("v1")
    git("tag", "v1")
    lesson("3eme/mathematiques/02-pythagore.json")
    commit("v2")
    assert_equal 0, synchroniser
    before = snapshot
    shallow = @dir.join("superficiel")
    output, status = Open3.capture2e("git", "clone", "-q", "--depth", "1", "--branch", "v1", "file://#{@source}", shallow.to_s)
    assert status.success?, output
    old = Contenus::Synchroniser.new(source: shallow, target: @target, version_file: @version, out: @out)

    assert_equal 1, old.synchroniser
    assert_includes @out.string, "inconnue de ce clone"
    assert_equal before, snapshot
  end

  test "si l'échange de dossiers échoue, l'ancienne copie est remise en place" do
    lesson("3eme/mathematiques/01-thales.json")
    commit("v1")
    assert_equal 0, synchroniser
    before = snapshot
    lesson("3eme/mathematiques/02-pythagore.json")
    commit("v2")
    calls = 0
    original = FileUtils.method(:mv)
    FileUtils.define_singleton_method(:mv) do |*args, **options|
      calls += 1
      raise Errno::EACCES, "échange" if calls == 2

      original.call(*args, **options)
    end
    begin
      assert_raises(Errno::EACCES) { synchroniser }
    ensure
      FileUtils.define_singleton_method(:mv, original)
    end
    assert_equal before, snapshot
    assert_not @target.dirname.join(".lecons-traitees.ancienne").exist?
  end
end

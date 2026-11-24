require "test_helper"
require "open3"
require "tmpdir"
require "yaml"
load Rails.root.join("script/ci/documents_proof").to_s unless defined?(DocumentsProof)

# Chantier preuve-arbre-documents-seuls (constat du 2026-11-24, PR #692, run 45403364756) : une promotion de documents
# seuls dont le code est celui d'un arbre déjà prouvé publie la preuve de son propre arbre, sans quoi le déploiement de
# Staging refuse « Arbre sans ci vert ». Le script du verdict est rejoué tel qu'il est écrit dans .github/workflows/ci.yml.
class CiDocumentsProofTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/ci.yml")

  def verdict_script = YAML.safe_load_file(WORKFLOW, aliases: true).dig("jobs", "ci", "steps").find { it["id"] == "verdict" }["run"]

  def verdict(**env)
    Dir.mktmpdir do |dir|
      output = File.join(dir, "output")
      FileUtils.touch(output)
      base = { "PLAN" => "success", "CODE" => "false", "UNIT" => "skipped", "COVERAGE" => "skipped", "SYSTEM" => "skipped",
               "LESSONS" => "false", "LECONS" => "skipped", "DOCUMENTS_PROVEN" => "", "GITHUB_OUTPUT" => output, "RUNNER_TEMP" => dir }
      log, status = Open3.capture2e(base.merge(env.transform_keys(&:to_s)), "bash", "-e", "-c", verdict_script)
      return { ok: status.success?, proof: File.read(output).include?("proof=true"), marker: File.exist?(File.join(dir, "ci-tree")), log: }
    end
  end

  test "documents alone over a proven tree prove the tree" do
    result = verdict(DOCUMENTS_PROVEN: "true")

    assert result[:ok], result[:log]
    assert result[:proof], "proof=true attendu : #{result[:log]}"
    assert result[:marker], "le fichier ci-tree à publier"
  end

  test "documents alone with green v3 lessons over a proven tree prove the tree" do
    result = verdict(DOCUMENTS_PROVEN: "true", LESSONS: "true", LECONS: "success")

    assert result[:ok], result[:log]
    assert result[:proof]
  end

  test "documents alone whose lessons fail are red and prove nothing" do
    result = verdict(DOCUMENTS_PROVEN: "true", LESSONS: "true", LECONS: "failure")

    refute result[:ok]
    refute result[:proof]
  end

  test "documents alone without a proven base, or a tree already proven, publish nothing" do
    [ "", "false" ].each do |proven|
      result = verdict(DOCUMENTS_PROVEN: proven)

      assert result[:ok], result[:log]
      refute result[:proof], "DOCUMENTS_PROVEN=#{proven.inspect}"
    end
    refute verdict(CODE: "", DOCUMENTS_PROVEN: "").fetch(:proof), "arbre déjà prouvé : rien à republier"
  end

  test "code still needs every test job green to prove the tree" do
    assert verdict(CODE: "true", UNIT: "success", COVERAGE: "success", SYSTEM: "success", LECONS: "success")[:proof]
    result = verdict(CODE: "true", UNIT: "success", COVERAGE: "success", SYSTEM: "failure", LECONS: "success", DOCUMENTS_PROVEN: "true")
    refute result[:ok]
    refute result[:proof], "DOCUMENTS_PROVEN ne remplace jamais les tests du code"
  end

  # « plan » : the tree tested may prove itself only when it differs from its first parent, the head of the base, by
  # documents alone, and that parent's tree is proven. Played on a throwaway repository, with a stand-in proof.
  class Proof
    attr_reader :asked

    def initialize(answer) = @answer = answer

    def tested?(sha)
      (@asked ||= []) << sha
      @answer
    end
  end

  def git(repo, *args)
    env = ENV.keys.grep(/\AGIT_/).to_h { [ it, nil ] }
    out, status = Open3.capture2(env, "git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", *args, err: File::NULL)
    status.success? ? out : nil
  end

  # A base commit with code and documents, then the commit tested, whose first parent is the base.
  def with_promotion(changes)
    Dir.mktmpdir do |repo|
      { "app/models/a.rb" => "a", "docs/a.md" => "a", "README.md" => "a" }.each { write(repo, *it) }
      git(repo, "init", "-q")
      git(repo, "add", "-A")
      git(repo, "commit", "-q", "-m", "base")
      base = git(repo, "rev-parse", "HEAD").strip
      changes.call(repo)
      git(repo, "add", "-A")
      git(repo, "commit", "-q", "--allow-empty", "-m", "promotion")
      yield ->(*args) { git(repo, *args) }, base
    end
  end

  def write(repo, path, content)
    FileUtils.mkdir_p(File.join(repo, File.dirname(path)))
    File.write(File.join(repo, path), content)
  end

  test "documents alone over a proven parent are proven, asked about the parent" do
    with_promotion(->(repo) { write(repo, "docs/contenus/lecons-traitees/x/y/z.json", "{}"); write(repo, "notes.md", "n") }) do |git, base|
      proof = Proof.new(true)

      assert DocumentsProof.new(git:, proof:).proven?
      assert_equal [ base ], proof.asked
    end
  end

  test "documents alone over an unproven parent are not proven" do
    with_promotion(->(repo) { write(repo, "docs/b.md", "b") }) do |git, _base|
      refute DocumentsProof.new(git:, proof: Proof.new(false)).proven?
    end
  end

  test "any code in the difference, added, changed, deleted or moved out of docs, is never proven this way" do
    [
      ->(repo) { write(repo, "app/models/a.rb", "changed") },
      ->(repo) { write(repo, "config/x.yml", "x") },
      ->(repo) { FileUtils.rm(File.join(repo, "app/models/a.rb")) },
      ->(repo) { FileUtils.mv(File.join(repo, "docs/a.md"), File.join(repo, "app/models/a.md.rb")) },
      ->(repo) { FileUtils.mv(File.join(repo, "app/models/a.rb"), File.join(repo, "docs/a.rb")) }
    ].each_with_index do |change, index|
      with_promotion(change) do |git, _base|
        proof = Proof.new(true)

        refute DocumentsProof.new(git:, proof:).proven?, "cas #{index}"
        assert_nil proof.asked, "la preuve n'est pas lue quand le code diffère (cas #{index})"
      end
    end
  end

  test "a commit without parent, or a git that fails, proves nothing" do
    Dir.mktmpdir do |repo|
      write(repo, "docs/a.md", "a")
      git(repo, "init", "-q")
      git(repo, "add", "-A")
      git(repo, "commit", "-q", "-m", "seul")

      refute DocumentsProof.new(git: ->(*args) { git(repo, *args) }, proof: Proof.new(true)).proven?
    end
    refute DocumentsProof.new(git: ->(*) { nil }, proof: Proof.new(true)).proven?
    failing_diff = ->(*args) { args.first == "rev-parse" ? "c0ffee\n" : nil }
    refute DocumentsProof.new(git: failing_diff, proof: Proof.new(true)).proven?
  end

  # The script reads the proof of the parent through script/ci/tested_tree, never with a cloud session's proof.
  test "the script asks GitHub through tested_tree, without local proof" do
    script = Rails.root.join("script/ci/documents_proof").read

    assert_includes script, "TestedTree.new(repository: ENV.fetch(\"GITHUB_REPOSITORY\", \"Lnclassapp/App.Lnclassapp\"),"
    refute_includes script, "local_proof"
  end

  # The wiring: « plan » fetches the parent, asks the script for documents alone, plays the whole suite when the parent is
  # not proven; « ci » proves the tree from that answer only, and publishes for Staging and main only.
  test "plan asks the script for documents alone and plays the suite when the base is not proven" do
    workflow = YAML.safe_load_file(WORKFLOW, aliases: true)
    plan = workflow.dig("jobs", "plan")
    checkout = plan["steps"].find { it["uses"].to_s.start_with?("actions/checkout") }
    changes = plan["steps"].find { it["id"] == "changes" }["run"]

    assert_equal 2, checkout.dig("with", "fetch-depth")
    assert_equal "${{ steps.changes.outputs.documents_proven }}", plan.dig("outputs", "documents_proven")
    assert_match(/if \[ "\$code" = false \]; then\n\s+script_output=.*\n\s+GITHUB_OUTPUT="\$script_output" script\/ci\/documents_proof \|\| true/, changes)
    assert_match(/documents_proven=true\n\s+else\n\s+code=true/, changes, "base sans preuve : la suite entière tourne")
    assert_operator changes.index("script/ci/documents_proof"), :<, changes.index('echo "code=$code"')
    assert_equal "${{ needs.plan.outputs.documents_proven }}", workflow.dig("jobs", "ci", "steps").find { it["id"] == "verdict" }.dig("env", "DOCUMENTS_PROVEN")
  end
end

require "test_helper"
load Rails.root.join("script/ci/tested_tree").to_s unless defined?(TestedTree)

# ADR-0069 : a promotion does not replay the suite when the tree it promotes already got a green « ci ».
# Any doubt (unreadable commit, API error, expired proof) must answer false, so that the suite runs.
class CiTestedTreeTest < ActiveSupport::TestCase
  REPOSITORY = "Lnclassapp/App.Lnclassapp"
  SHA = "c0ffee"
  TREE = "7ee5"

  def api(responses) = ->(path) { responses.fetch(path) { flunk "appel inattendu : #{path}" } }

  def commit = { "repos/#{REPOSITORY}/commits/#{SHA}" => { "commit" => { "tree" => { "sha" => TREE } } } }

  def artifacts(list) = { "repos/#{REPOSITORY}/actions/artifacts?name=ci-tree-#{TREE}&per_page=100" => { "artifacts" => list } }

  RUN_ID = 42

  def green_artifact(**over) = { "name" => "ci-tree-#{TREE}", "expired" => false, "workflow_run" => { "id" => RUN_ID, "head_branch" => "Develop" } }.merge(over)

  def ci_run(name: "CI", event: "pull_request", head: "Develop", base: "Staging", repository: REPOSITORY, pull_requests: nil)
    pulls = pull_requests || [ { "head" => { "ref" => head }, "base" => { "ref" => base } } ]
    { "repos/#{REPOSITORY}/actions/runs/#{RUN_ID}" => { "name" => name, "event" => event, "head_branch" => head,
                                                         "head_repository" => { "full_name" => repository }, "pull_requests" => pulls } }
  end

  def proof(responses, local_proof: false) = TestedTree.new(repository: REPOSITORY, api: api(responses), local_proof:)

  def cloud(answer) = { "repos/#{REPOSITORY}/contents/arbres/#{TREE}?ref=ci/preuves" => answer }

  test "a tree that got a green ci is tested, and the artifact is named after the tree" do
    subject = proof(commit.merge(artifacts([ green_artifact ])).merge(ci_run))

    assert_equal "ci-tree-#{TREE}", subject.artifact_name(SHA)
    assert subject.tested?(SHA)
  end

  test "a tree never tested, or only by an expired proof, is not tested" do
    refute proof(commit.merge(artifacts([]))).tested?(SHA)
    refute proof(commit.merge(artifacts([ green_artifact("expired" => true) ])).merge(ci_run)).tested?(SHA)
  end

  # Revue sécurité du 2026-11-24 : l'artefact ne prouve rien s'il ne vient pas du workflow « CI » d'une PR vers Staging ou main.
  test "the artifact of a pull request into Develop, another workflow, another event or a fork proves nothing" do
    {
      "base Develop" => ci_run(base: "Develop", head: "feature/x"),
      "another workflow" => ci_run(name: "Deploy"),
      "another event" => ci_run(event: "push"),
      "a fork" => ci_run(repository: "intrus/App.Lnclassapp"),
      "no pull request" => ci_run(pull_requests: []),
      "head branch differing" => ci_run(pull_requests: [ { "head" => { "ref" => "autre" }, "base" => { "ref" => "main" } } ])
    }.each do |label, responses|
      refute proof(commit.merge(artifacts([ green_artifact ])).merge(responses)).tested?(SHA), label
    end
  end

  test "an artifact without a run, or whose run cannot be read, proves nothing" do
    refute proof(commit.merge(artifacts([ green_artifact("workflow_run" => nil) ]))).tested?(SHA)
    refute proof(commit.merge(artifacts([ green_artifact ])).merge("repos/#{REPOSITORY}/actions/runs/#{RUN_ID}" => nil)).tested?(SHA)
    refute proof(commit.merge(artifacts([ green_artifact("workflow_run" => { "id" => RUN_ID, "head_branch" => "autre" }) ])).merge(ci_run)).tested?(SHA)
  end

  test "a pull request into main counts" do
    assert proof(commit.merge(artifacts([ green_artifact("workflow_run" => { "id" => RUN_ID, "head_branch" => "Staging" }) ])).merge(ci_run(head: "Staging", base: "main"))).tested?(SHA)
  end

  test "an artifact of another tree proves nothing" do
    refute proof(commit.merge(artifacts([ green_artifact("name" => "ci-tree-#{TREE}0") ]))).tested?(SHA)
  end

  test "an unreadable commit or a failed API call answers false instead of raising" do
    refute proof({ "repos/#{REPOSITORY}/commits/#{SHA}" => nil }).tested?(SHA)
    assert_nil proof({ "repos/#{REPOSITORY}/commits/#{SHA}" => { "message" => "Not Found" } }).artifact_name(SHA)
    refute proof(commit.merge(artifacts(nil))).tested?(SHA)
    refute proof(commit.merge("repos/#{REPOSITORY}/actions/artifacts?name=ci-tree-#{TREE}&per_page=100" => nil)).tested?(SHA)
  end

  # ADR-0069 §8 : a cloud session's proof, the file arbres/<tree> of ci/preuves, counts only when allowed.
  test "a proof on ci/preuves counts when local proofs are allowed, never otherwise" do
    responses = commit.merge(artifacts([])).merge(cloud({ "type" => "file", "name" => TREE }))

    assert proof(responses, local_proof: true).tested?(SHA)
    refute proof(commit.merge(artifacts([])), local_proof: false).tested?(SHA), "sans autorisation, ci/preuves n'est pas lu"
  end

  test "no file, a directory or an API error on ci/preuves proves nothing" do
    [ nil, { "message" => "Not Found" }, [ { "type" => "file" } ], { "type" => "dir" } ].each do |answer|
      refute proof(commit.merge(artifacts([])).merge(cloud(answer)), local_proof: true).tested?(SHA), answer.inspect
    end
  end
end

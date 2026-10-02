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

  def proof(responses, local_proof: false) = TestedTree.new(repository: REPOSITORY, api: api(responses), local_proof:)

  def cloud(answer) = { "repos/#{REPOSITORY}/contents/arbres/#{TREE}?ref=ci/preuves" => answer }

  test "a tree that got a green ci is tested, and the artifact is named after the tree" do
    subject = proof(commit.merge(artifacts([ { "name" => "ci-tree-#{TREE}", "expired" => false } ])))

    assert_equal "ci-tree-#{TREE}", subject.artifact_name(SHA)
    assert subject.tested?(SHA)
  end

  test "a tree never tested, or only by an expired proof, is not tested" do
    refute proof(commit.merge(artifacts([]))).tested?(SHA)
    refute proof(commit.merge(artifacts([ { "name" => "ci-tree-#{TREE}", "expired" => true } ]))).tested?(SHA)
  end

  test "an artifact of another tree proves nothing" do
    refute proof(commit.merge(artifacts([ { "name" => "ci-tree-#{TREE}0", "expired" => false } ]))).tested?(SHA)
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

# Pure Ruby, no Rails boot (like the other guards). standard-de-test, Lot G (ADR standard-de-test §4 point 9): a pull request
# into Develop that changes code says what it proved on the standard set, in a « Prouvé sur le jeu standard » section of its body.
# script/ci/proof_section.rb decides; bin/ci-quiet applies it (the body comes from tmp/pr-body.md, or from GitHub when
# it can be read, and the guard abstains, saying so, when it cannot).
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../script/ci/proof_section"

class ProofSectionTest < Minitest::Test
  FILLED = <<~BODY
    ## Résumé
    Un changement.

    ## Prouvé sur le jeu standard
    - Parcours de recette rejoués : enseignant (390 px et ordinateur)
    - Leçons rendues : aucune
    - Preuve : `bin/ci-quiet` niveau pr vert sur `abcd1234`

    ## Risques
    Aucun.
  BODY
  CODE = %w[app/controllers/classroom/x.rb docs/a.md].freeze
  DOCS = %w[docs/a.md docs/recette/eleve.md].freeze

  def verdict(body, changed: CODE, **) = ProofSection.verdict(body:, changed:, **)

  def test_a_filled_section_is_enough
    assert_equal :ok, verdict(FILLED).status
  end

  def test_no_section_is_refused
    result = verdict("## Résumé\nUn changement.\n")

    assert_equal :missing, result.status
    assert_includes result.message, "Prouvé sur le jeu standard"
  end

  def test_an_empty_section_is_refused
    assert_equal :missing, verdict("## Prouvé sur le jeu standard\n\n## Risques\nAucun.\n").status
    assert_equal :missing, verdict("## Prouvé sur le jeu standard\n").status
  end

  def test_the_unfilled_template_is_refused
    template = File.read(File.expand_path("../../.github/pull_request_template.md", __dir__), encoding: "UTF-8")

    assert_equal :missing, verdict(template).status
  end

  def test_comments_and_bare_labels_do_not_count
    body = "### Prouvé sur le jeu standard\n<!-- à remplir -->\n- Parcours rejoués :\n- Leçons rendues : \n- Preuve :\n"

    assert_equal :missing, verdict(body).status
  end

  def test_the_section_ends_at_the_next_heading_of_its_level_or_above
    assert_equal :missing, verdict("## Prouvé sur le jeu standard\n\n## Autre\nTexte ici.\n").status
    assert_equal :ok, verdict("## Prouvé sur le jeu standard\nParcours : aucun\n### Détail\nplus\n").status
  end

  def test_the_heading_is_found_whatever_its_case_and_accents
    assert_equal :ok, verdict("## PROUVE SUR LE JEU STANDARD\nAucun : ne touche ni rôle ni écran\n").status
  end

  def test_a_change_of_documentation_alone_needs_no_section
    assert_equal :ok, verdict("", changed: DOCS).status
    assert_equal :ok, verdict(nil, changed: DOCS).status
  end

  def test_an_unreadable_body_makes_the_guard_abstain_and_say_so
    result = verdict(nil)

    assert_equal :abstain, result.status
    assert_includes result.message, "tmp/pr-body.md"
  end

  def test_a_pull_request_opened_before_the_rule_is_not_broken
    old = verdict("## Résumé\nrien\n", created_at: "2026-11-02T10:00:00Z")

    assert_equal :abstain, old.status
    assert_includes old.message, ProofSection::ENFORCED_FROM
    assert_equal :missing, verdict("## Résumé\nrien\n", created_at: "#{ProofSection::ENFORCED_FROM}T00:00:00Z").status
  end

  def test_a_body_file_is_read_first_and_always_enforced
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "tmp"))
      File.write(File.join(root, "tmp/pr-body.md"), "## Résumé\nrien\n")
      found = ProofSection.body_for(root:, branch: "x", gh: ->(*) { raise "pas d'appel GitHub" })

      assert_equal [ "## Résumé\nrien\n", nil, "tmp/pr-body.md" ], found
    end
  end

  def test_without_a_file_the_body_comes_from_the_open_pull_request_of_the_branch
    Dir.mktmpdir do |root|
      asked = nil
      gh = ->(*args) { asked = args; '[{"body":"Texte","created_at":"2026-11-05T08:00:00Z"}]' }

      assert_equal [ "Texte", "2026-11-05T08:00:00Z", "GitHub" ], ProofSection.body_for(root:, branch: "feature/x", gh:)
      assert_includes asked.join(" "), "head=" # the branch is looked up by name
    end
  end

  def test_gitHub_unreachable_or_no_open_pull_request_gives_no_body
    Dir.mktmpdir do |root|
      assert_equal [ nil, nil, nil ], ProofSection.body_for(root:, branch: "x", gh: ->(*) { nil })
      assert_equal [ nil, nil, nil ], ProofSection.body_for(root:, branch: "x", gh: ->(*) { "[]" })
      assert_equal [ nil, nil, nil ], ProofSection.body_for(root:, branch: "x", gh: ->(*) { "pas du json" })
    end
  end
end

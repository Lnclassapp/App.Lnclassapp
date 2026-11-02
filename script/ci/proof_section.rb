# The merge rule of the standard test set (chantier standard-de-test, Lot G, ADR standard-de-test §4 point 9): a pull request
# into Develop that changes code says what it proved, in a section « Prouvé sur le jeu standard » of its body, filled.
# Pure Ruby, no Rails. Played by bin/ci-quiet (level pr and train, only against origin/Develop); rules held by
# test/guards/proof_section_test.rb. The body is read, in this order, from:
#   1. tmp/pr-body.md (explicit: always enforced, the way to check a body before the pull request exists);
#   2. the open pull request of the branch, through `gh api` (REST), when GitHub can be reached.
# When neither can be read, or the pull request was opened before the rule, the guard abstains and says so: it never
# breaks a pull request already open, and it never guesses.
require "json"
require "open3"
require "timeout"
require_relative "scope"

module ProofSection
  HEADING = "Prouvé sur le jeu standard".freeze
  # Pull requests opened before this day are not held to the rule (the ones already open when it was written).
  ENFORCED_FROM = "2026-11-03".freeze
  BODY_FILE = "tmp/pr-body.md".freeze
  Verdict = Data.define(:status, :message)

  module_function

  # :ok, :missing (refuse) or :abstain (the guard could not judge, and says why).
  def verdict(body:, changed:, created_at: nil)
    return Verdict.new(:ok, "aucun code changé : la section « #{HEADING} » n'est pas requise") if changed.all? { CiScope.doc?(it) }
    return Verdict.new(:abstain, "corps de la PR illisible (hors ligne, pas de PR ouverte pour la branche ou pas d'accès à GitHub) : " \
                                 "section « #{HEADING} » non vérifiée. Écris le corps dans #{BODY_FILE} pour la contrôler.") if body.nil?
    if created_at && created_at[0, 10] < ENFORCED_FROM
      return Verdict.new(:abstain, "PR ouverte avant la règle (#{ENFORCED_FROM}) : section « #{HEADING} » non exigée")
    end
    return Verdict.new(:ok, "section « #{HEADING} » remplie") if filled?(section(body))

    Verdict.new(:missing, "la PR change du code : la section « #{HEADING} » manque ou est vide (modèle : .github/pull_request_template.md, " \
                          "parcours : docs/recette/README.md). Un chantier sans parcours à rejouer écrit « aucun : ne touche ni rôle ni écran ».")
  end

  # [body, created_at, source], or [nil, nil, nil].
  def body_for(root:, branch:, gh: method(:github))
    file = File.join(root, BODY_FILE)
    return [ File.read(file, encoding: "UTF-8"), nil, BODY_FILE ] if File.file?(file)

    pulls = JSON.parse(gh.call("api", "repos/{owner}/{repo}/pulls?state=open&head={owner}:#{branch}").to_s)
    pull = pulls.first if pulls.is_a?(Array)
    return [ pull["body"].to_s, pull["created_at"], "GitHub" ] if pull.is_a?(Hash)

    [ nil, nil, nil ]
  rescue JSON::ParserError
    [ nil, nil, nil ]
  end

  def github(*args)
    out, status = Timeout.timeout(10) { Open3.capture2("gh", *args, err: File::NULL) }
    status.success? ? out.force_encoding("UTF-8") : nil
  rescue Timeout::Error, SystemCallError
    nil
  end

  # The text under the heading, up to the next heading of the same level or above; nil when there is no such heading.
  def section(body)
    level = nil
    lines = []
    body.to_s.each_line do |line|
      heading = line.match(/\A(\#{1,6})\s+(.+?)\s*#*\s*\z/)
      if heading
        break if level && heading[1].size <= level

        level = heading[1].size if !level && normalize(heading[2]).start_with?(normalize(HEADING))
        next
      end
      lines << line if level
    end
    level ? lines.join : nil
  end

  # Filled: at least one line that is neither a comment nor a label without its value (« - Parcours rejoués : »).
  def filled?(text)
    return false if text.nil?

    text.gsub(/<!--.*?-->/m, "").lines.map { it.strip.sub(/\A[-*]\s*/, "") }.any? { !it.empty? && !it.end_with?(":") }
  end

  def normalize(text) = text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
end

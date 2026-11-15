# Branch and line coverage of the files a pull request touches (ADR-0107 §10, chantier couverture-branches-visible).
# The threshold of ADR-0024 stays a measure of the whole suite, played once per train (coverage job). This reads the
# .resultset.json the unit tests of the pr level leave when they run with COVERAGE_PART, and says, for the touched
# app/ and lib/ files only, which lines and which branches no test of the change plays.
#
# The tests of the change are a part of the suite: a branch covered only by a test outside the change shows here
# although the train will accept it (a warning, never a block). The reverse never happens: a branch the part leaves
# uncovered is uncovered by the whole suite as well, unless a test outside the part plays it.
require "json"

module CoverageTouched
  Gap = Data.define(:file, :lines, :branches, :line_total, :branch_total) do
    def clean? = lines.empty? && branches.empty?

    def percent(missing, total) = total.zero? ? 100.0 : ((total - missing) * 100.0 / total).round(2)
  end

  TOUCHED = %r{\A(app|lib)/.+\.rb\z}

  def self.touched(changed, exist: ->(path) { File.exist?(path) }) = changed.grep(TOUCHED).select { exist.(it) }.uniq.sort

  # resultset: the parsed .resultset.json ({ "<command name>" => { "coverage" => { "<absolute path>" => … } } }).
  # A file measured under several command names counts as covered when any of them played it.
  def self.gaps(resultset, files, root: Dir.pwd)
    merged = Hash.new { |hash, key| hash[key] = { lines: [], branches: {} } }
    resultset.each_value do |run|
      run.fetch("coverage", {}).each do |path, data|
        file = path.delete_prefix("#{root}/")
        next unless files.include?(file)

        lines = data.is_a?(Hash) ? data["lines"] : data
        merged[file][:lines] = lines.each_with_index.map { |hits, index| [ merged[file][:lines][index], hits ].compact.then { it.empty? ? nil : it.sum } }
        (data["branches"] || {}).each do |condition, arms|
          arms.each { |arm, hits| merged[file][:branches][[ condition, arm ]] = merged[file][:branches].fetch([ condition, arm ], 0) + hits }
        end if data.is_a?(Hash)
      end
    end
    files.map do |file|
      # A file no test loaded is absent from the result: nothing played it.
      data = merged.fetch(file) { { lines: nil, branches: nil } }
      next Gap.new(file:, lines: [ :never_loaded ], branches: [], line_total: 0, branch_total: 0) unless data[:lines]

      lines = data[:lines].each_with_index.select { |hits, _| hits&.zero? }.map { |_, index| index + 1 }
      branches = data[:branches].select { |_, hits| hits.zero? }.keys.map { |condition, arm| describe(condition, arm) }.sort_by(&:first).map(&:last)
      Gap.new(file:, lines:, branches:, line_total: data[:lines].count { !it.nil? }, branch_total: data[:branches].size)
    end
  end

  # SimpleCov keys: "[:if, 0, 10, 4, 14, 7]" = [type, id, first line, first column, last line, last column].
  # "[:if, 0, 10, 4, 14, 7]" and "[:then, 1, 11, 4, 11, 20]" -> [11, "line 11: then of the if on line 10"]
  def self.describe(condition, arm)
    kind = condition[/\[:(\w+)/, 1]
    line = condition.split(",")[2].to_i
    target, at = arm[/\[:(\w+)/, 1], arm.split(",")[2].to_i
    [ at, "line #{at}: #{target} of the #{kind} on line #{line}" ]
  end

  def self.report(gaps)
    dirty = gaps.reject(&:clean?)
    return [] if dirty.empty?

    out = [ "⚠️  Branch coverage: #{dirty.size} touched file(s) with code that no test of the change plays " \
            "(the train demands 100 % lines and branches on the whole suite, ADR-0024):" ]
    dirty.each do |gap|
      if gap.lines == [ :never_loaded ]
        out << "  #{gap.file}: no test of the change loads this file"
        next
      end
      out << "  #{gap.file}: lines #{gap.percent(gap.lines.size, gap.line_total)} %, branches #{gap.percent(gap.branches.size, gap.branch_total)} %"
      out << "    lines not played: #{gap.lines.join(', ')}" if gap.lines.any?
      gap.branches.each { out << "    branch not played, #{it}" }
    end
    out << "  A test outside the change may play them: the warning blocks nothing, the train decides."
    out
  end
end

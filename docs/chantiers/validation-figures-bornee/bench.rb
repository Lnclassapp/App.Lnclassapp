# Bench du chantier validation-figures-bornee : durée de Figure.errors_for sur des listes hors bornes.
# Ruby pur, hors Rails : ruby docs/chantiers/validation-figures-bornee/bench.rb [taille] (5 000 par défaut).
# Pire cas de chaque sorte : arbre en chaîne, aire connue répétée après une moitié inconnue, partie connue répétée après une moitié inconnue.
# Médiane de 3 exécutions par cas ; chaque exécution est coupée à 60 s.
require "set"
require "timeout"
require_relative "../../../app/domain/entities/catalog/figure_kinds"
require_relative "../../../app/domain/entities/catalog/figure"

size = Integer(ARGV.fetch(0, "5000"))
base = { "key" => "bench", "description" => "a" * 150 }
figures = {
  "diagram tree en chaîne" => { "kind" => "diagram", "params" => { "layout" => "tree", "nodes" => Array.new(size) { { "id" => "n#{it}", "label" => "n" } },
                                                                    "edges" => Array.new(size - 1) { { "from" => "n#{it}", "to" => "n#{it + 1}" } } } },
  "map à N aires" => { "kind" => "map", "params" => { "base" => "cote_d_ivoire", "legend" => %w[A],
                                                       "areas" => Array.new(size) { { "id" => it < size / 2 ? "x" : "savanna", "category" => 1 } } } },
  "plate à N étiquettes" => { "kind" => "plate", "params" => { "plate" => "heart", "numbering" => "names",
                                                                "labels" => Array.new(size) { { "part" => it < size / 2 ? "x" : "aorta" } },
                                                                "highlight" => Array.new(size) { it < size / 2 ? "x" : "aorta" } } },
  "geometry à N points" => { "kind" => "geometry", "params" => { "points" => Array.new(size) { { "id" => "P#{it}", "x" => 0, "y" => 0 } } } }
}

figures.select { |label, _| ARGV[1].nil? || label.start_with?(ARGV[1]) }.each do |label, figure|
  runs = Array.new(3) do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Timeout.timeout(60) { Entities::Catalog::Figure.errors_for(base.merge(figure)) }
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  rescue Timeout::Error
    Float::INFINITY
  end
  median = runs.sort[1]
  puts format("%-26s N=%-6d médiane %s", label, size, median.infinite? ? "> 60 s (coupé)" : format("%.2f ms", median * 1000))
end

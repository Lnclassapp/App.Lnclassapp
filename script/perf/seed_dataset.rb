# Sème le jeu de mesure du chantier cache-ecrans-lourds (script/perf/dataset.rb) dans la base de développement, après
# `bin/rails db:reset` :
#
#   bin/rails runner script/perf/seed_dataset.rb
raise "script/perf/seed_dataset.rb est réservé au développement" unless Rails.env.development?

require_relative "dataset"

PerfDataset.run

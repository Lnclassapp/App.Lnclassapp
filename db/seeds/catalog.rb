# ADR-0034: the development and test referential — 7 levels, 5 series, 10 level/series pairs, 6 materials — and its
# barème of the classrooms, taken over exactly as the deployment did (ADR-0058).
# Idempotent by slug. Never in production: the team creates its referential on screen. Only a PR environment, which
# runs in production, receives it too (ADR-0108).
raise "db/seeds/catalog.rb est réservé au développement, au test et aux environnements de PR" unless Rails.env.local? || PrEnvironment.active?

levels = [ [ "6ème", "first" ], [ "5ème", "first" ], [ "4ème", "first" ], [ "3ème", "first" ],
           [ "2nde", "second" ], [ "1ère", "second" ], [ "Tle", "second" ] ]
series_by_level = { "2nde" => %w[A C], "1ère" => %w[A1 A2 C D], "Tle" => %w[A1 A2 C D] }
materials = [ [ "Mathématiques", "Maths", "science" ], [ "Physique-Chimie", "PC", "science" ], [ "SVT", "SVT", "science" ],
              [ "Français", "Français", "literature" ],
              [ "Histoire-Géographie", "HG", "literature" ], [ "Philosophie", "Philo", "literature" ] ]

# The slug is the frozen parameterized name (ADR-0029): « 1ère » → « 1ere ».
by_slug = ->(model, name, **attributes) { model.find_by(slug: name.parameterize) || model.create!(name:, **attributes) }

level_records = levels.each_with_index.to_h do |(name, cycle), index|
  [ name, by_slug.call(Orm::Level, name, position: index + 1, cycle:) ]
end
series_records = series_by_level.values.flatten.uniq.to_h { |name| [ name, by_slug.call(Orm::Series, name) ] }
series_by_level.each do |level, names|
  names.each do |name|
    pair = { level: level_records.fetch(level), series: series_records.fetch(name) }
    Orm::LevelSeries.create!(**pair) unless Orm::LevelSeries.exists?(**pair)
  end
end
# The program rank of ADR-0090 §4.2, from the table the migration and the team's creation read.
materials.each do |name, shortname, category|
  position = Repositories::Catalog::ProgramOrder.rank(name.parameterize)
  by_slug.call(Orm::Material, name, shortname:, category:, position:).update!(position:)
end

require Rails.root.join("db/migrate/20260928140100_fill_classroom_plan_entries").to_s
FillClassroomPlanEntries.fill

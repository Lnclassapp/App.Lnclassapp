# ADR-0058: the barème taken over from the constant it replaces (Entities::Classroom::DefaultClassroomPlan::PLAN, ADR-0030),
# on the referential in base, by slug, so that production generates exactly the same classrooms after the deployment:
# - a number (6eme … 3eme): one entry for the level;
# - per_series (2nde, 1ere): one entry per series linked to the level now;
# - named series (tle): one entry per named series linked to the level; another series of Tle stays undefined.
# Idempotent (ON CONFLICT DO NOTHING): a count the team has set is never overwritten. The seeds and the test factories
# call FillClassroomPlanEntries.fill after creating their referential.
class FillClassroomPlanEntries < ActiveRecord::Migration[8.1]
  PLAN = {
    "public" => { "6eme" => 4, "5eme" => 4, "4eme" => 10, "3eme" => 10, "2nde" => { per_series: 6 },
                  "1ere" => { per_series: 6 }, "tle" => { "c" => 2, "d" => 6, "a1" => 3, "a2" => 2 } },
    "private" => { "6eme" => 2, "5eme" => 2, "4eme" => 4, "3eme" => 4, "2nde" => { per_series: 3 },
                   "1ere" => { per_series: 3 }, "tle" => { "c" => 1, "d" => 3, "a1" => 2, "a2" => 2 } }
  }.freeze

  def self.fill(connection = ActiveRecord::Base.connection)
    levels, per_series, named = rows_by_form
    [ [ levels, <<~SQL ], [ per_series, <<~SQL ], [ named, <<~SQL ] ].each { |rows, select| insert(connection, rows, select) }
      SELECT v.school_type, l.id, NULL::bigint, v.count FROM (VALUES %s) AS v(school_type, level_slug, count)
      JOIN levels l ON l.slug = v.level_slug
    SQL
      SELECT v.school_type, l.id, ls.series_id, v.count FROM (VALUES %s) AS v(school_type, level_slug, count)
      JOIN levels l ON l.slug = v.level_slug JOIN level_series ls ON ls.level_id = l.id
    SQL
      SELECT v.school_type, l.id, s.id, v.count FROM (VALUES %s) AS v(school_type, level_slug, series_slug, count)
      JOIN levels l ON l.slug = v.level_slug JOIN series s ON s.slug = v.series_slug
      JOIN level_series ls ON ls.level_id = l.id AND ls.series_id = s.id
    SQL
  end

  # → three lists of VALUES tuples: [type, level, count], [type, level, count], [type, level, series, count]
  def self.rows_by_form
    PLAN.each_with_object([ [], [], [] ]) do |(school_type, levels), (numbers, per_series, named)|
      levels.each do |level_slug, config|
        next numbers << [ school_type, level_slug, config ] if config.is_a?(Integer)
        next per_series << [ school_type, level_slug, config[:per_series] ] if config.key?(:per_series)

        config.each { |series_slug, count| named << [ school_type, level_slug, series_slug, count ] }
      end
    end
  end

  def self.insert(connection, rows, select)
    values = rows.map { |row| "(#{row.map { connection.quote(it) }.join(', ')})" }.join(", ")
    connection.execute(<<~SQL)
      INSERT INTO classroom_plan_entries (school_type, level_id, series_id, count, created_at, updated_at)
      SELECT sub.*, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM (#{format(select, values)}) AS sub
      ON CONFLICT DO NOTHING
    SQL
  end

  def up
    self.class.fill(connection)
  end

  def down
    execute "DELETE FROM classroom_plan_entries"
  end
end

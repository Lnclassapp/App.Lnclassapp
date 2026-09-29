# Chantier cache-ecrans-lourds, lot 3 (ADR-0062 amended, ADR-0067): the name searches ignore case and accents through
# translate(lower(...)) LIKE '%term%' (AccountSearchQuery, SchoolsQuery), which no B-tree can serve. pg_trgm, a standard
# PostgreSQL extension, indexes these very expressions: they must stay identical, character for character, to the ones
# of the queries (test/infrastructure/queries/trigram_search_indexes_test.rb checks the planner uses them). Built
# concurrently: no step blocks writes.
class AddTrigramSearchIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  ACCENTED = "àâäçéèêëîïôöùûüÿÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ".freeze
  PLAIN = "aaaceeeeiioouuuyaaaceeeeiioouuuy".freeze
  INDEXES = {
    users: { "index_users_on_searchable_full_name" => "first_name || ' ' || last_name",
             "index_users_on_searchable_reversed_name" => "last_name || ' ' || first_name" },
    schools: { "index_schools_on_searchable_name" => "name", "index_schools_on_searchable_sigle" => "sigle",
               "index_schools_on_national_code_trigram" => nil }
  }.freeze

  def up
    enable_extension "pg_trgm"
    INDEXES.each do |table, indexes|
      indexes.each do |name, expression|
        column = expression ? "(translate(lower(#{expression}), '#{ACCENTED}', '#{PLAIN}'))" : "national_code"
        add_index table, "#{column} gin_trgm_ops", using: :gin, name:, algorithm: :concurrently, if_not_exists: true
      end
    end
  end

  def down
    INDEXES.each do |table, indexes|
      indexes.each_key { |name| remove_index table, name:, algorithm: :concurrently, if_exists: true }
    end
    disable_extension "pg_trgm"
  end
end

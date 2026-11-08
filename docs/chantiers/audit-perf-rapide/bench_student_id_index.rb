# Bench O-X05 : EXPLAIN de classroom_students WHERE student_id, avec et sans l'index.
# Usage : bin/rails runner docs/chantiers/audit-perf-rapide/bench_student_id_index.rb  (dev ; tout est annulé)
# Volume : 180 000 classes, 1 000 000 d'adhésions (élèves 1..400 000, historique compris).
conn = ActiveRecord::Base.connection
def plan(conn, label)
  3.times.map do
    rows = conn.select_values("EXPLAIN (ANALYZE, TIMING OFF) SELECT 1 FROM classroom_students WHERE student_id = 123456")
    [ rows.find { it.include?("Scan") }.to_s.strip, rows.last.to_s ]
  end.last.tap { |scan, exec| puts "#{label}: #{scan}\n  #{exec}" }
end
ActiveRecord::Base.transaction do
  conn.execute("SET LOCAL statement_timeout = 0")
  conn.execute("SET LOCAL session_replication_role = replica") # sans les clés étrangères, sur des données jetables
  conn.execute("DELETE FROM classroom_students")
  conn.execute(<<~SQL)
    INSERT INTO classroom_students (classroom_id, student_id, "primary", joined_at, joined_via, left_at)
    SELECT g, (g * 7919 % 400000) + 1 + (k * 400000), false, now(), 'standard', now()
    FROM generate_series(1, 180000) g, generate_series(0, 5) k
  SQL
  conn.execute("ANALYZE classroom_students")
  plan(conn, "avant ")
  conn.execute("CREATE INDEX tmp_cs_student ON classroom_students (student_id)")
  conn.execute("ANALYZE classroom_students")
  plan(conn, "après ")
  raise ActiveRecord::Rollback
end

# Contrôle de « Je m'entraîne » : ruby practice_check.rb fichier.json…  (lancé depuis la racine du dépôt)
require "active_support"
require "active_support/core_ext"
require "bigdecimal"
$LOAD_PATH.unshift File.expand_path("app/domain", Dir.pwd)
%w[statement_blocks content_node].each { |f| require File.expand_path("app/domain/entities/catalog/#{f}", Dir.pwd) }
%w[blanks].each { require File.expand_path("app/domain/entities/assessment/question_kinds/blanks", Dir.pwd) }
%w[choice fill_blank matching numeric ordering select written notebook].each { require File.expand_path("app/domain/entities/assessment/question_kinds/#{it}", Dir.pwd) }
require File.expand_path("app/domain/entities/assessment/answer", Dir.pwd)
require File.expand_path("app/domain/entities/assessment/question", Dir.pwd)
require File.expand_path("app/domain/entities/catalog/notion_practice", Dir.pwd)
bad = 0
ARGV.each do |f|
  j = JSON.parse(File.read(f)); c = j["courses"][0]; multi = 0; hint = 0
  c["notions"].each_with_index do |n, i|
    p = n["practice"]
    (puts "#{f} notion #{i}: practice absent"; bad += 1; next) unless p
    errs = Entities::Catalog::NotionPractice.errors_for(p)
    errs.each { |e| puts "#{f} notion #{i}: #{e.inspect}"; bad += 1 }
    p["questions"].each do |q|
      multi += 1 if (q["answers"] || []).map { _1["blank"] }.compact.uniq.size > 1
      hint += 1 if q["hint"]
      txt = q["content"].to_s
      blanks = txt.scan("___").size
      nb = (q["answers"]||[]).map { _1["blank"] }.compact.uniq.size
      (puts "#{f} notion #{i}: ___ #{blanks} vs blank #{nb}"; bad += 1) if blanks > 0 && nb > 0 && blanks != nb
    end
    graded = n["exercise"]["questions"].map { _1["content"] }
    p["questions"].each { |q| (puts "#{f} notion #{i}: question reprise de l'exercice"; bad += 1) if graded.include?(q["content"]) }
  end
  (puts "#{f}: aucune question à plusieurs cases"; bad += 1) if multi.zero?
  (puts "#{f}: aucun indice"; bad += 1) if hint.zero?
end
puts bad.zero? ? "practice OK" : "practice: #{bad} problème(s)"
exit(bad.zero? ? 0 : 1)

# 🔌 INFRA · Queries::School::SchoolSearchQuery
# Rôle : chercher un établissement actif en tapant (nom, sigle, DRENA, initiales), 20 au plus, avec sa DRENA ; retrouver le choisi
# ADR  : 0029, 0067, 0142-recherche-etablissement · UDR : 0177-champ-etablissement · public : rien de plus que la liste par DRENA
module Queries
  module School
    class SchoolSearchQuery
      Row = Data.define(:public_id, :name, :drena_public_id, :drena_name)
      # more : un 21e établissement existe ; la personne ajoute un mot.
      Result = Data.define(:rows, :more)

      LIMIT = 20
      MIN_LENGTH = 2
      MAX_LENGTH = 80
      MAX_WORDS = 6
      # Les initiales du nom ne sont cherchées que pour un mot court (« nd », « cndp ») : un mot long y trouverait du bruit.
      INITIALS_MAX = 4
      ACTIVE = "active".freeze

      PLAIN = ->(sql) { "translate(lower(#{sql}), '#{Orm::School::ACCENTED}', '#{Orm::School::PLAIN}')" }
      # Les mêmes expressions que les index trigrammes (migration AddTrigramSearchIndexes) pour le nom et le sigle.
      NAME = PLAIN.call("schools.name")
      SIGLE = PLAIN.call("schools.sigle")
      DRENA = PLAIN.call("drenas.name")
      # « Collège Notre-Dame de la Paix » → « cnddlp » : la première lettre ou le premier chiffre de chaque mot.
      INITIALS = "regexp_replace(#{NAME}, '([a-z0-9])[a-z0-9]*[^a-z0-9]*', '\\1', 'g')".freeze
      COLUMNS = %w[schools.public_id schools.name drenas.public_id drenas.name].freeze

      # → Result, ou nil quand la saisie est trop courte (aucune requête).
      def call(term:)
        words = self.class.words(term)
        return if words.join.length < MIN_LENGTH

        scope = Orm::School.joins(:drena).where(status: ACTIVE)
        words.each_with_index { |word, index| scope = scope.where(*matching(word, index)) }
        prefix = Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "CASE WHEN #{NAME} LIKE ? THEN 0 ELSE 1 END",
                                                                    "#{ActiveRecord::Base.sanitize_sql_like(words.first)}%" ]))
        rows = scope.order(prefix, "schools.name", "schools.id").limit(LIMIT + 1).pluck(*COLUMNS).map { Row.new(*it) }
        Result.new(rows: rows.first(LIMIT), more: rows.size > LIMIT)
      end

      # L'établissement choisi, actif, avec sa DRENA ; nil sinon (inconnu, inactif, en brouillon : aucune différence).
      def find(public_id:)
        return if public_id.blank?

        values = Orm::School.joins(:drena).where(public_id: public_id.to_s, status: ACTIVE).pick(*COLUMNS)
        Row.new(*values) if values
      end

      # La saisie normalisée comme TextSearch, coupée, en mots : un mot d'une lettre (« l' », « d' ») est oublié, un chiffre gardé.
      def self.words(term)
        Queries::Shared::TextSearch.normalize(term.to_s.first(MAX_LENGTH))
                              .split(/[^a-z0-9]+/).select { it.length > 1 || it.match?(/\d/) }.first(MAX_WORDS)
      end

      private

      def matching(word, index)
        key = :"w#{index}"
        columns = [ NAME, SIGLE, DRENA ]
        columns << INITIALS if word.length <= INITIALS_MAX
        [ columns.map { "#{it} LIKE :#{key}" }.join(" OR "), { key => "%#{ActiveRecord::Base.sanitize_sql_like(word)}%" } ]
      end
    end
  end
end

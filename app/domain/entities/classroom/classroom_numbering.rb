# 🧠 DOMAINE · Entities::Classroom::ClassroomNumbering
# Rôle : nom de la classe suivante d'un niveau (préfixe du barème, plus grand numéro + 1) et dernière classe d'un niveau
# ADR  : 0030, 0041, 0059
module Entities
  module Classroom
    module ClassroomNumbering
      # Comme DefaultClassroomPlan : « 6ème », « Tle A1 ».
      def self.prefix(level_name:, series_name:) = [ level_name, series_name ].compact.join(" ")

      # Tout nom « <préfixe> <n> » entre dans le maximum : le nom rendu n'est jamais pris. taken : noms de l'école et de l'année.
      def self.next_name(prefix:, taken:)
        pattern = /\A#{Regexp.escape(prefix)} (\d+)\z/
        "#{prefix} #{taken.filter_map { pattern.match(it)&.[](1)&.to_i }.max.to_i + 1}"
      end

      # L'ordre de la fiche (SchoolDetailQuery) : numéro final, puis nom ; un nom sans numéro passe avant « 1 ». → String | nil
      def self.last(names:) = names.max_by { [ it[/\d+\z/].to_i, it ] }
    end
  end
end

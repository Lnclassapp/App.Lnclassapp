# 🧠 DOMAINE · Entities::Classroom::LevelShortName
# Rôle : le nom court d'un niveau et de sa série (« 6e », « 2de A », « 1re D », « Tle D »), dans le rond de l'accueil enseignant
# UDR  : accueil-enseignant-actions (§3.2)
module Entities
  module Classroom
    module LevelShortName
      # Les niveaux du programme (BaseReferential::LEVELS) ; un autre nom reste tel quel.
      SHORT = { "2nde" => "2de", "1ère" => "1re" }.freeze
      ORDINAL = /\A(\d+)ème\z/

      # level : « 6ème », « Tle » ; series : « D », nil sans série. → String
      def self.for(level:, series: nil)
        short = SHORT.fetch(level) { level.sub(ORDINAL, '\1e') }
        [ short, series.presence ].compact.join(" ")
      end
    end
  end
end

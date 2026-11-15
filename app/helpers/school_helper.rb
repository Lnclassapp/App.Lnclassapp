# 🌐 UI · SchoolHelper — le sigle d'un établissement affiché en pastille ronde
# Rôle : le sigle de la base, sinon les initiales du nom (mots de 3 lettres et plus, hors articles), 4 lettres au plus
# UDR  : 0173 §3 (carte de classe de l'accueil)
module SchoolHelper
  SIGLE_STOPWORDS = %w[de du des la le les et en sur sous].freeze
  SIGLE_LENGTH = 4

  # sigle : celui de la base (nil ou vide s'il n'existe pas) ; name : le nom complet. → « LMT » pour « Lycée Moderne de Treichville »
  def school_sigle(sigle:, name:)
    return sigle.to_s.strip if sigle.present?

    words = I18n.transliterate(name.to_s).scan(/[[:alpha:]]+/).reject { it.downcase.in?(SIGLE_STOPWORDS) || it.size < 3 }
    return words.first.to_s.first(3).upcase if words.size == 1

    words.first(SIGLE_LENGTH).map { it[0] }.join.upcase
  end
end

# 🧠 DOMAINE · Entities::Crm::Redaction
# Rôle : masque, avant l'envoi à un modèle de langage, les numéros de téléphone ivoiriens et les noms des contacts d'une école ; fonction pure
# ADR  : XXXX (modèles de langage, « Données envoyées ») · les noms d'élèves ne se filtrent pas : le formulaire d'échange en avertit
module Entities
  module Crm
    module Redaction
      PHONE_MASK = "[numéro]".freeze
      CONTACT_MASK = "[contact]".freeze
      MIN_NAME_PART = 3 # lettres : en dessous, un fragment masquerait des mots courants
      # 0 suivi de 1, 5 ou 7, puis 8 chiffres (espaces ou points tolérés), précédé ou non de 225 / +225 / 00225.
      PHONE = /(?<!\d)(?:(?:\+|00)?225[\s.]*)?0[157](?:[\s.]?\d){8}(?!\d)/

      # → String | nil (nil pour un texte vide)
      def self.call(text, names: [])
        text = text.to_s.strip
        return nil if text.empty?

        mask_names(text.gsub(PHONE, PHONE_MASK), names)
      end

      def self.mask_names(text, names)
        fragments(names).reduce(text) do |masked, fragment|
          masked.gsub(/(?<![[:alpha:]])#{Regexp.escape(fragment).gsub('\\ ', '\s+')}(?![[:alpha:]])/i, CONTACT_MASK)
        end
      end

      # Le nom entier d'abord, puis chacune de ses parties assez longues ; les plus longs en premier.
      def self.fragments(names)
        wholes = names.map { it.to_s.squish }.reject(&:empty?)
        parts = wholes.flat_map { it.split }.select { it.length >= MIN_NAME_PART }
        (wholes + parts).uniq(&:downcase).sort_by { -it.length }
      end
      private_class_method :mask_names, :fragments
    end
  end
end

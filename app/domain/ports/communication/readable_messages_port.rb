# 🧠 DOMAINE · Ports::Communication::ReadableMessagesPort
# Rôle : contrat de la règle de lecture des annonces, vue par le domaine : le lecteur d'un acteur, une annonce lisible ou non
# ADR  : 0040, 0069
module Ports
  module Communication
    # Propre au Lot B (un seul consommateur) : son adaptateur est la seule définition SQL de la règle (ADR-0069 §4.3, §6).
    module ReadableMessagesPort
      # actor : Entities::Identity::Actor. L'élève est lu par sa classe principale active et l'établissement de celle-ci ;
      # l'enseignant et la direction, par actor.school_id. → Entities::Communication::Reader
      def reader_for(actor:)
        raise NotImplementedError, "#{self.class} doit implémenter #reader_for"
      end

      # Publiée, publication venue, fin non atteinte (now), audience qui couvre le lecteur. Un public_id inconnu n'est pas
      # lisible. → Boolean
      def readable?(reader:, public_id:, now:)
        raise NotImplementedError, "#{self.class} doit implémenter #readable?"
      end
    end
  end
end

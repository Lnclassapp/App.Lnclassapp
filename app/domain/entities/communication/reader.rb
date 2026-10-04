# 🧠 DOMAINE · Entities::Communication::Reader
# Rôle : l'acteur vu par la lecture des annonces, avec l'établissement et la classe principale active résolus une fois
# ADR  : 0040, 0069
module Entities
  module Communication
    # L'Actor ne porte ni l'établissement d'un élève ni sa classe : le lecteur les résout par requête (ADR-0069 §6).
    Reader = Data.define(:user_id, :role, :school_id, :classroom_id)
  end
end

# 🧠 DOMAINE · Dtos::Identity::StudentEntryInput
# Rôle : forme de l'entrée élève (au « tu ») : le numéro seul, puis le code secret, tapé une seule fois pour un nouveau compte
# ADR  : 0050, 0141-entree-eleve-revele-un-numero-inscrit, 0148-connexion-revele-un-numero-inscrit · UDR : 0176-entree-eleve-unique, 0189-connexion-numero-d-abord
module Dtos
  module Identity
    # Ses messages d'erreur sont ceux de l'élève (student_entries.fr.yml) ; la règle est celle de NumberEntryInput.
    class StudentEntryInput < NumberEntryInput
    end
  end
end

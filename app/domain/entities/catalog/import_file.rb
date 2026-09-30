# 🧠 DOMAINE · Entities::Catalog::ImportFile
# Rôle : un fichier d'un envoi, relu du stockage : son nom tel que téléversé et son contenu JSON brut
# ADR  : 0039, 0068
module Entities
  module Catalog
    ImportFile = Data.define(:name, :content)
  end
end

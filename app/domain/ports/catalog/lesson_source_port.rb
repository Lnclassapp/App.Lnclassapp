# 🧠 DOMAINE · Ports::Catalog::LessonSourcePort
# Rôle : contrat de la source des leçons à sujets de devoir du dépôt (nom d'import, empreinte SHA-256, contenu)
# ADR  : chargement-automatique-des-lecons-hors-production
module Ports
  module Catalog
    module LessonSourcePort
      # import_name : le nom du fichier d'import, « chargement-automatique-<niveau>-<matière>-<fichier>.json » (il identifie la leçon
      # d'un chargement à l'autre) ; checksum_sha256 : l'empreinte du contenu tel que lu ; content : le fichier JSON, tel quel.
      LessonFile = Data.define(:import_name, :checksum_sha256, :content)

      # Les leçons au format 3 dont le cours porte au moins un sujet de devoir, dans un ordre stable. → [LessonFile]
      def lessons
        raise NotImplementedError, "#{self.class} doit implémenter #lessons"
      end
    end
  end
end

# 🧠 DOMAINE · Ports::Catalog::LessonSourcePort
# Rôle : contrat de la source des leçons v3 du dépôt (nom d'import, empreinte SHA-256, contenu, dossier de niveau, sujets de devoir)
# ADR  : chargement-automatique-des-lecons-hors-production, 0123
module Ports
  module Catalog
    module LessonSourcePort
      # import_name : le nom du fichier d'import, « chargement-automatique-<niveau>-<matière>-<fichier>.json » (il identifie la leçon
      # d'un chargement à l'autre) ; checksum_sha256 : l'empreinte du contenu tel que lu ; content : le fichier JSON, tel quel ;
      # level_directory : le dossier de niveau (« tle-c », « 3eme ») ; subjects : le cours porte au moins un sujet de devoir.
      LessonFile = Data.define(:import_name, :checksum_sha256, :content, :level_directory, :subjects) do
        def initialize(level_directory: nil, subjects: true, **) = super
      end

      # Les leçons au format 3, dans un ordre stable ; le use case choisit celles qu'il charge (AutomaticLoadStage#mode_for). → [LessonFile]
      def lessons
        raise NotImplementedError, "#{self.class} doit implémenter #lessons"
      end
    end
  end
end

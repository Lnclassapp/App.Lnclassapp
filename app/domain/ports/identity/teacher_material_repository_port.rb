# 🧠 DOMAINE · Ports::Identity::TeacherMaterialRepositoryPort
# Rôle : contrat des matières d'un enseignant dans un établissement (clé du rattachement teacher_schools)
# ADR  : 0094 (§10), 0103
module Ports
  module Identity
    module TeacherMaterialRepositoryPort
      # → Array<Integer>, ordre d'ajout ; [] sans liste dans cet établissement
      def material_ids_for(teacher_id:, school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #material_ids_for"
      end

      # Remplace TOUTE la liste (déjà bornée par Entities::Identity::TeacherMaterials), dans la transaction de l'appelant ;
      # les matières gardées conservent leur rang, les nouvelles suivent dans l'ordre donné. → true
      def replace(teacher_id:, school_id:, material_ids:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #replace"
      end

      # Un nouveau rattachement reçoit une liste : celle déjà connue pour cet établissement (un retour), sinon celle de
      # from_school_id (l'établissement d'où il l'ajoute), sinon sa dernière liste écrite. Rien à copier : rien n'est écrit.
      # → true
      def inherit(teacher_id:, school_id:, from_school_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #inherit"
      end
    end
  end
end

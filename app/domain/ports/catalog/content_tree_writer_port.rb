# 🧠 DOMAINE · Ports::Catalog::ContentTreeWriterPort
# Rôle : contrat d'écriture en masse d'arbres de contenu déjà validés et identifiés, tout en draft
# ADR  : 0035, 0039, 0068
module Ports
  module Catalog
    module ContentTreeWriterPort
      # Nœuds que remplissent les imports I1 à I3. slug et public_id sont tirés par le domaine avant l'insertion.
      # course_id (resp. essential_id) vaut nil pour un nœud porté par son parent, l'id du parent existant sinon.
      AnswerNode = Data.define(:position, :content, :correct)
      QuestionNode = Data.define(:position, :content, :explanation, :question_type, :answers)
      ExerciseNode = Data.define(:public_id, :essential_id, :title, :description, :exercise_type, :position, :questions)
      EssentialNode = Data.define(:slug, :course_id, :name, :subtitle, :content, :position, :exercises)
      CourseNode = Data.define(:slug, :name, :subtitle, :content, :level_id, :series_id, :material_id, :essentials)

      # Appelé dans une transaction ; une table après l'autre, parents d'abord (insert_all ou COPY, ADR-0068) ; lève si la base refuse.
      # → { courses:, essentials:, exercises:, questions:, answers: } (lignes créées)
      def write(author_id:, at:, courses: [], essentials: [], exercises: [])
        raise NotImplementedError, "#{self.class} doit implémenter #write"
      end
    end
  end
end

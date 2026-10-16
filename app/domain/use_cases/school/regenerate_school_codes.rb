# 🧠 DOMAINE · UseCases::School::RegenerateSchoolCodes
# Rôle : régénère en masse les codes d'établissement d'une sélection (rapport school_codes), par lots, sans jamais les écrire ailleurs
# ADR  : 0057, 0077, 0096 · moteur : RegenerateInBulk
module UseCases
  module School
    class RegenerateSchoolCodes < RegenerateInBulk
      # schools : Ports::School::SchoolRepositoryPort ; les autres dépendances : celles du moteur.
      def initialize(schools:, **)
        super(**)
        @schools = schools
      end

      private

      # Les codes pris sont lus une fois ; chaque tirage complète l'ensemble (Entities::School::SchoolCode.generate_unique).
      def prepare = (@taken = @schools.taken_school_codes)

      def fetch(selection:, created_before:, after_id:, limit:, **)
        @schools.code_regeneration_batch(selection:, created_before:, after_id:, limit:)
      end

      def replace(candidates, at:, unchanged_since:)
        codes = Entities::School::SchoolCode.generate_unique(count: candidates.size, taken: @taken)
        rows = candidates.zip(codes).map { |candidate, school_code| { id: candidate.id, school_code: } }
        @schools.replace_school_codes(rows:, at:, unchanged_since:)
      end

      # La forme de « Régénérer le code » un par un, sans le code (ADR-0096 §4.4).
      def audit_entry(candidate)
        { subject_id: candidate.id, metadata: { change: "code_regenerated", public_id: candidate.public_id } }
      end
    end
  end
end

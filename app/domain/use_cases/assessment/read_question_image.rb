# 🧠 DOMAINE · UseCases::Assessment::ReadQuestionImage
# Rôle : lire les octets de l'image d'une question sous la règle de lecture de son exercice ; non rattachée, l'équipe seule
# ADR  : 0026, 0028, 0035, 0089 · UDR : 0084
module UseCases
  module Assessment
    class ReadQuestionImage
      # public : exercice lisible de tous (chaîne publiée) : le navigateur la garde, en cache privé (ADR-0089 §4.5).
      # exercise_public_id : pour la règle du niveau de l'élève, tenue par le contrôleur (ReadsOwnLevel) ; nil si non rattachée.
      Image = Data.define(:content_type, :public, :exercise_public_id, :data)

      def initialize(images:, exercises:, policy:)
        @images = images
        @exercises = exercises
        @policy = policy
      end

      # → Result(Image) | :not_found. Le fichier n'est jamais lu avant la règle de lecture.
      def call(actor:, public_id:)
        image = @images.find(public_id:)
        return Shared::Result.failure(:not_found) if image.nil?

        exercise = image.exercise_public_id && @exercises.find_by_public_id(public_id: image.exercise_public_id)
        return Shared::Result.failure(:not_found) unless readable?(actor, image, exercise)

        Shared::Result.success(Image.new(content_type: image.content_type, public: exercise&.readable_chain_published? == true,
                                         exercise_public_id: image.exercise_public_id,
                                         data: -> { @images.download(public_id:) }))
      end

      private

      # Une image non rattachée se lit comme un brouillon : par l'équipe seule.
      def readable?(actor, image, exercise)
        return actor&.team? == true if image.exercise_public_id.nil?
        return false if exercise.nil?

        @policy.call(actor:, content: exercise).success?
      end
    end
  end
end

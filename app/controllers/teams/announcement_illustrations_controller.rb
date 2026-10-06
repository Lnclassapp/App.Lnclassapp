# 🌐 DELIVERY · Teams::AnnouncementIllustrationsController
# Rôle : page « Illustrations d'annonce » de l'équipe : liste, ajout d'un dessin SVG reconstruit, renommage ; 422 sous les champs
# ADR  : 0026, 0028, 0081 (§4.3) · UDR : 0075 (§3.5) · garde : celle de BaseController (équipe seule, 403 sinon)
module Teams
  class AnnouncementIllustrationsController < BaseController
    helper_method :library

    def index
      @form = Dtos::Communication::IllustrationInput.new
    end

    # Échec : la page re-rendue en 422, la raison sous « Dessin » ou « Nom ».
    def create
      values = params.expect(illustration: %i[name file])
      @form = Dtos::Communication::IllustrationInput.new(name: values[:name], file: uploaded(values[:file]))
      render_result add.call(actor: current_actor, dto: @form), form: :index, success: ->(_) { done(t(".added")) }
    end

    # Les 8 de base n'ont pas de public_id : leur adresse répond 404, comme une illustration inconnue (AV-10).
    def edit
      @illustration = illustrations.find_by_public_id(public_id: params[:public_id])
      return render_not_found if @illustration.nil?

      @form = Dtos::Communication::IllustrationInput.new(name: @illustration.name)
    end

    def update
      @illustration = illustrations.find_by_public_id(public_id: params[:public_id])
      @form = Dtos::Communication::IllustrationInput.new(name: params.expect(illustration: [ :name ])[:name])
      result = rename.call(actor: current_actor, public_id: params[:public_id], dto: @form)
      render_result result, form: :edit, success: ->(_) { done(t(".renamed")) }
    end

    private

    def done(notice) = redirect_to(teams_announcement_illustrations_path, notice:, status: :see_other)

    # Seul un vrai fichier téléversé compte ; une chaîne à la place du fichier vaut une absence.
    def uploaded(file) = (file if file.is_a?(ActionDispatch::Http::UploadedFile))

    # La liste de la page, lue seulement si la page est rendue (index, ou ajout refusé).
    def library = @library ||= Queries::Communication::IllustrationLibraryQuery.new.call

    def illustrations = @illustrations ||= Repositories::Communication::IllustrationRepository.new
    def policy = Policies::Communication::ManageIllustrationsPolicy.new

    def add
      UseCases::Communication::AddIllustration.new(illustrations:, drawings: ::Communication::DrawingReader.new,
                                                   transaction: Repositories::Shared::Transaction.new, policy:)
    end

    def rename
      UseCases::Communication::RenameIllustration.new(illustrations:, transaction: Repositories::Shared::Transaction.new, policy:)
    end
  end
end

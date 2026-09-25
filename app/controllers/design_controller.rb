# 🌐 DELIVERY · DesignController — guide de style vivant (/design), dessiné hors production seulement
# Rôle : rend chaque composant dans ses variantes et états, le shell de chaque rôle, et un CRUD Hotwire de démonstration
# UDR  : 0005, 0006
class DesignController < ApplicationController
  # Formulaire d'exemple : fournit au composant champ un objet avec et sans erreurs, sans toucher au domaine.
  class Sample
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :email, :string
    attribute :password, :string
    attribute :bio, :string
    attribute :level, :string
    attribute :terms, :boolean

    validate { errors.add(:name, I18n.t("design.index.sample.errors.name")) if name.blank? }

    def self.with_errors
      new(email: "awa@exemple").tap do |sample|
        sample.errors.add(:name, I18n.t("design.index.sample.errors.name"))
        sample.errors.add(:email, I18n.t("design.index.sample.errors.email"))
        sample.errors.add(:level, I18n.t("design.index.sample.errors.level"))
        sample.errors.add(:terms, I18n.t("design.index.sample.errors.terms"))
      end
    end
  end

  helper_method :shell_user

  def index
    @sample = Sample.new
    @invalid_sample = Sample.with_errors
  end

  def shell
    @role = params[:role].to_sym
    render layout: "shell"
  end

  def toast
    message = t(".message", time: Time.current.strftime("%H:%M:%S"))
    type = ComponentsHelper::TOAST_TYPES.keys.find { |key| key.to_s == params[:type] } || :success

    respond_to do |format|
      format.turbo_stream { render turbo_stream: helpers.turbo_stream_toast(message, type:) }
      format.html { redirect_to design_path, flash: { type => message } }
    end
  end

  # CRUD Hotwire (UDR-0006) : le formulaire arrive dans le frame « modal » du layout.
  def modal
    @sample = Sample.new
  end

  # Échec : 422 et la modale re-rendue dans son frame, erreurs comprises. Succès : Turbo Stream, la modale se ferme.
  def create
    @sample = Sample.new(params.expect(sample: %i[name email]))
    return render :modal, status: :unprocessable_entity if @sample.invalid?

    render turbo_stream: [
      helpers.turbo_stream_toast(t(".created", name: @sample.name), type: :success),
      turbo_stream.append("design-created", helpers.ui_badge(@sample.name, tone: :brand, dot: true))
    ]
  end

  # Contenu d'un frame paresseux : l'état vide remplace l'état de chargement servi par la page.
  def frame
  end

  private

  def shell_user
    NavigationHelper::ShellUser.new(name: t("design.shell.names.#{@role}"), role: @role, detail: t("design.shell.details.#{@role}"))
  end
end

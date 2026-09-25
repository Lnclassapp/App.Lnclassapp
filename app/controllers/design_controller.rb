# 🌐 DELIVERY · DesignController — guide de style vivant (/design), dessiné hors production seulement
# Rôle : rend chaque composant dans chaque variante et état, le shell de chaque rôle, et un toast par Turbo Stream
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

  private

  def shell_user
    NavigationHelper::ShellUser.new(name: t("design.shell.names.#{@role}"), role: @role, detail: t("design.shell.details.#{@role}"))
  end
end

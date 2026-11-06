# 🌐 DELIVERY · Teams::Crm::ContactsController
# Rôle : contacts d'une école (frame school_crm_contacts), ajout en modale, retrait après confirmation en GET (archivage) ; garde ManageCrmPolicy héritée
# ADR  : XXXX (contexte crm) · UDR : XXXX (bloc « Suivi » de la fiche établissement) · CA-09, CA-10
module Teams
  module Crm
    class ContactsController < BaseController
      # Saisie de la modale : les règles sont celles du use case, qui rend ses erreurs ici.
      class Form
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :full_name, :string
        attribute :position, :string
        attribute :phone, :string
        attribute :note, :string

        def self.model_name = ActiveModel::Name.new(self, nil, "ContactForm")
      end

      before_action :load_school
      before_action :load_contact, only: %i[archive destroy]

      def index
        load_contacts
      end

      def new
        @form = Form.new
      end

      def create
        @form = Form.new(params.fetch(:contact, {}).permit(:full_name, :position, :phone, :note))
        result = add_contact.call(actor: current_actor, school_id: @school.id, full_name: @form.full_name, position: @form.position,
                                  phone: @form.phone, note: @form.note)
        render_result result, form: :new, success: ->(_) { respond_changed(:created) }
      end

      # Confirmation « Retirer <nom> ? », lue à la demande (GET) ; rien n'est retiré ici.
      def archive; end

      def destroy
        render_result archive_contact.call(actor: current_actor, public_id: @contact.public_id), success: ->(_) { respond_changed(:destroyed) }
      end

      private

      def load_school
        @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
        render_not_found if @school.nil?
      end

      # Un contact d'une autre école est introuvable ici, comme un identifiant inconnu.
      def load_contact
        @contact = repository.find_by_public_id(public_id: params[:public_id])
        render_not_found unless @contact && @contact.school_id == @school.id
      end

      def load_contacts
        @contacts = repository.active_for_school(school_id: @school.id)
      end

      def respond_changed(outcome)
        load_contacts
        respond_to do |format|
          format.turbo_stream { render outcome == :created ? "teams/crm/contacts/create" : "teams/crm/contacts/destroy" }
          format.html { redirect_to school_path(@school.public_id), notice: t(".done"), status: :see_other }
        end
      end

      def repository = Repositories::Crm::ContactRepository.new

      def add_contact = UseCases::Crm::AddContact.new(contacts: repository, policy: Policies::Crm::ManageCrmPolicy.new)

      def archive_contact
        UseCases::Crm::ArchiveContact.new(contacts: repository, policy: Policies::Crm::ManageCrmPolicy.new, clock: Time.zone)
      end
    end
  end
end

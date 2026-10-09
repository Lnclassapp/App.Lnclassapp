# 🌐 DELIVERY · ClassPicker — les quatre listes de la cascade DRENA → établissement → niveau → classe, pour le partial _class_picker
# Rôle : chaque liste seulement si le choix précédent lui appartient ; partagé par l'inscription élève et « Choisis ta classe »
# ADR  : 0062, 0085 (§4.2) · UDR : 0081 (§3.3, §3.5)
module ClassPicker
  extend ActiveSupport::Concern

  included { helper_method :class_picker_lists }

  private

  # Lit les choix de @form (Dtos::Classroom::StudentRegistrationInput). Un identifiant forgé ne touche pas la base, et un
  # choix orphelin vide les listes d'après. nil : liste non affichée.
  def class_picker_lists
    @class_picker_lists ||= begin
      drenas = class_picker_options.drenas
      schools = (class_picker_options.schools_for(drena_public_id: @form.drena_public_id) if drenas.any? { it.public_id == @form.drena_public_id })
      levels = (Queries::School::SchoolLevelsQuery.new.call(school_public_id: @form.school_public_id) if schools&.any? { it.public_id == @form.school_public_id })
      classrooms = (level_classrooms(@form.school_public_id, @form.level_slug) if levels&.any? { it.slug == @form.level_slug })
      { drenas:, schools:, levels:, classrooms: }
    end
  end

  def class_picker_options = @class_picker_options ||= Queries::School::SchoolOptionsQuery.new

  def level_classrooms(school_public_id, level_slug)
    Queries::Classroom::LevelClassroomsQuery.new.call(school_public_id:, level_slug:)
  end
end

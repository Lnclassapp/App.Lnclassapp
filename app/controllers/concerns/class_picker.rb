# 🌐 DELIVERY · ClassPicker — la cascade établissement (recherche) → niveau → classe, pour le partial _class_picker
# Rôle : niveaux seulement pour un établissement actif choisi, classes seulement pour un niveau de cet établissement ; partagé par l'inscription élève, « Choisis ta classe » et « Changer de classe »
# ADR  : 0062, 0085 (§4.2), XXXX-recherche-etablissement · UDR : 0081 (§3.3, §3.5), XXXX-champ-etablissement
module ClassPicker
  extend ActiveSupport::Concern
  include SchoolSearchField

  included { helper_method :class_picker_lists }

  private

  # Lit les choix de @form (Dtos::Classroom::StudentRegistrationInput). Un identifiant forgé ou inactif ne liste rien, et un
  # choix orphelin vide les listes d'après. nil : liste non affichée.
  def class_picker_lists
    @class_picker_lists ||= begin
      search = school_search_locals(@form.school_public_id)
      school = search[:chosen]
      levels = (Queries::School::SchoolLevelsQuery.new.call(school_public_id: school.public_id) if school)
      classrooms = (level_classrooms(school.public_id, @form.level_slug) if levels&.any? { it.slug == @form.level_slug })
      { search:, levels:, classrooms: }
    end
  end

  def level_classrooms(school_public_id, level_slug)
    Queries::Classroom::LevelClassroomsQuery.new.call(school_public_id:, level_slug:)
  end
end

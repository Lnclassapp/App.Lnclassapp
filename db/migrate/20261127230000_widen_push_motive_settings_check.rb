# envoi-immediat-notifications, Lot 0 (ADR-0147, amendement du 2026-11-27 II) : une case pour chacun des sept motifs.
# Élargit seulement une contrainte : l'image précédente écrit toujours des motifs acceptés.
class WidenPushMotiveSettingsCheck < ActiveRecord::Migration[8.1]
  OLD = "motive IN ('quiz_prep','assignment_due','assignment_new')".freeze
  NEW = "motive IN ('quiz_prep','assignment_due','assignment_new','announcement','unfinished','result','inactive')".freeze

  def up = swap(OLD, NEW)
  def down = swap(NEW, OLD)

  private

  def swap(from, to)
    %i[push_motive_settings push_motive_setting_changes].each do |table|
      remove_check_constraint table, from, name: "#{table}_motive_check"
      add_check_constraint table, to, name: "#{table}_motive_check"
    end
  end
end

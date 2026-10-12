# ADR-0085 §4.1, Lot F of inscription-eleve-sans-code (IL-02): a student enters a classroom by the cascade or by its link,
# never by a code any more. The classroom code goes, with its rotation date, its partial unique index and its format.
# Rerunnable both ways. Down brings the columns back empty: the codes themselves are not restored, and no screen reads
# them any more.
class RemoveClassroomJoinCodes < ActiveRecord::Migration[8.1]
  FORMAT = "join_code ~ '^[a-hj-np-z]{3}[2-9]{2}$'".freeze
  CHECK = "classrooms_join_code_format".freeze

  def up
    remove_check_constraint :classrooms, name: CHECK, if_exists: true
    remove_index :classrooms, :join_code, if_exists: true
    remove_column :classrooms, :join_code, if_exists: true
    remove_column :classrooms, :join_code_rotated_at, if_exists: true
  end

  def down
    add_column :classrooms, :join_code, :string, limit: 5, if_not_exists: true
    add_column :classrooms, :join_code_rotated_at, :datetime, if_not_exists: true
    add_index :classrooms, :join_code, unique: true, where: "join_code IS NOT NULL", if_not_exists: true
    add_check_constraint :classrooms, FORMAT, name: CHECK, if_not_exists: true
  end
end

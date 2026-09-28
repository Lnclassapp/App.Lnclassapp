# ADR-0065: the MENA student number of a student, 8 digits then a letter, unique among living accounts, only a student's.
# Nullable here: the constraint that makes it mandatory for a student comes with the sign-up field (Lot F,
# 20260929091000_require_student_number).
class AddStudentNumberToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :student_number, :string, limit: 12
    add_index :users, :student_number, unique: true, where: "student_number IS NOT NULL"
    add_check_constraint :users, "student_number ~ '^[0-9]{8}[A-Z]$'", name: "users_student_number_format"
    add_check_constraint :users, "student_number IS NULL OR role = 'student'", name: "users_student_number_only_students"
  end
end

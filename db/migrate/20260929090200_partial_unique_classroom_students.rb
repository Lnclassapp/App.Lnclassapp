# ADR-0066 §4.4, amends ADR-0040: a student may leave a classroom and come back (« erreur de classe ») — one open
# membership per classroom and student; the closed ones stay as history.
class PartialUniqueClassroomStudents < ActiveRecord::Migration[8.1]
  def change
    remove_index :classroom_students, %i[classroom_id student_id],
                 name: "index_classroom_students_on_classroom_id_and_student_id", unique: true
    add_index :classroom_students, %i[classroom_id student_id], unique: true, where: "left_at IS NULL",
              name: "index_classroom_students_one_open_per_classroom"
  end
end

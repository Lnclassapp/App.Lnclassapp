# Audit O-X05 : les lectures qui filtrent seulement sur student_id (historique d'un élève, quitter une classe, jointures
# des tableaux de bord) ne pouvaient utiliser ni l'index composite (classroom_id en tête) ni l'index partiel de
# l'adhésion principale active. La table grossit d'une ligne par élève et par classe ; l'index est donc créé sans verrou
# d'écriture (concurrently), hors transaction, et la migration peut être rejouée.
class AddStudentIdIndexToClassroomStudents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :classroom_students, :student_id, name: "index_classroom_students_on_student_id",
                                                algorithm: :concurrently, if_not_exists: true
  end
end

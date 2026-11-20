require "test_helper"

# Lot A de partage-classe-k-factor (UDR partage-de-classe §3.1) : le QR du lien de classe dans la carte
# « Inscrire vos élèves », le lien vers l'affiche, l'avertissement du changement de lien.
class Classroom::ClassroomsQrTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", sigle: "LCA")
    @classroom = create_classroom(school: @school, name: "6ème 1")
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    sign_in_as @teacher
    get classroom_path(@classroom.public_id)
  end

  test "la carte du lien a un bouton « QR code » et une fenêtre avec le QR du lien" do
    assert_response :success
    assert_select "#classroom_link button", text: /QR code/
    assert_select "dialog#classroom-qr figure#classroom_qr[role='img'] svg", 1
  end

  test "la fenêtre du QR propose d'imprimer l'affiche de la classe" do
    assert_select "dialog#classroom-qr a[href='#{classroom_poster_path(@classroom.public_id)}'][target='_blank']",
                  text: /Imprimer l'affiche/
  end

  test "la confirmation « Changer le lien » prévient pour les QR et affiches imprimés" do
    assert_select "dialog#change-classroom-link", text: /QR et affiches déjà imprimés/
  end
end

# Cartes d'activation (Lot B) : abonne un élève par le dépôt des cartes, jamais en contournant la garde.
module BillingHelper
  ActiveSupport::TestCase.include(self)

  # Active la première carte remise du lot de la Boutique Awa (fixtures) pour l'élève, à l'instant donné.
  def subscribe_student(student, at: Time.current)
    card = Orm::Billing::ActivationCard.where(state: "issued").order(:serial).first
    school_id = Orm::ClassroomStudent.find_by(student_id: student.id)&.classroom&.school_id
    Repositories::Billing::CardRepository.new.activate(card_id: card.id, student_id: student.id, school_id:, at:).tap { |result| raise result.errors.inspect if result.failure? }
  end
end

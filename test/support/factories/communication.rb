# Announcements (ADR-0045, ADR-0069): a message of any author and status, its targeted classrooms, a dismissal.
module Factories
  module Communication
    ActiveSupport::TestCase.include(self)

    # Returns the Orm::Message. ends_at: published_at + 30 days by default, nil for a draft. A message for classrooms
    # takes the school of its first classroom; a withdrawn one, a moderator of the team unless `withdrawn_by:` is given.
    def create_message(author:, title: "Devoirs communs", body: "Ils commencent lundi.", audience: "students", school: nil,
                       classrooms: [], status: "published", published_at: 1.hour.ago, ends_at: nil, illustration: "info",
                       edited_at: nil, withdrawn_by: nil, **attributes)
      school ||= classrooms.first&.school if audience == "classrooms"
      ends_at ||= published_at + Entities::Communication::Message::DEFAULT_DURATION unless status == "draft" || published_at.nil?
      if status == "withdrawn"
        withdrawn_by ||= create_team_member(second_factor: false)
        attributes[:withdrawn_at] ||= Time.current
      end
      Orm::Message.create!(author:, title:, body:, audience:, school:, status:, published_at:, ends_at:, illustration:,
                           edited_at:, withdrawn_by:, **attributes).tap do |message|
        classrooms.each { |classroom| Orm::MessageClassroom.create!(message:, classroom:) }
      end
    end

    def dismiss_message(message:, user:, at: Time.current)
      Orm::MessageDismissal.create!(message:, user:, dismissed_at: at)
    end
  end
end

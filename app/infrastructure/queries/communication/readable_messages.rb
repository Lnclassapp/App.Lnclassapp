# 🔌 INFRA · Queries::Communication::ReadableMessages
# Rôle : LA règle de lecture des annonces, seule définition en SQL ; la liste, le carrousel et les fichiers en partent
# ADR  : 0040, 0045, 0078 · adaptateur de Ports::Communication::ReadableMessagesPort
module Queries
  module Communication
    class ReadableMessages
      include Ports::Communication::ReadableMessagesPort

      # L'audience qui désigne chaque rôle. L'équipe n'est l'audience d'aucune annonce : elle lit tout au titre de son
      # rôle (fichiers, modération), pas par cette règle.
      ROLE_AUDIENCES = { student: "students", teacher: "teachers", school_admin: "school_admins" }.freeze

      # ADR-0078 §4.3 : publiée, published_at <= now < ends_at, et une audience qui couvre le lecteur — par rôle (« all »
      # ou son rôle ; nationale ou de son établissement), ou par classes (élève dont la classe principale active est
      # ciblée). Sans établissement, le lecteur ne lit que les annonces nationales. → relation Orm::Message
      def scope(reader:, now:)
        audience = ROLE_AUDIENCES[reader.role]
        return Orm::Message.none if audience.nil?

        published = Orm::Message.where(status: "published", published_at: ..now).where("messages.ends_at > ?", now)
        by_role = published.where(audience: [ "all", audience ], school_id: [ nil, reader.school_id ].uniq)
        return by_role unless reader.role == :student && reader.classroom_id

        by_role.or(published.where(audience: "classrooms",
                                   id: Orm::MessageClassroom.where(classroom_id: reader.classroom_id).select(:message_id)))
      end

      # Classe principale active (ADR-0040) et son établissement : une requête, pour l'élève seulement.
      def reader_for(actor:)
        return Entities::Communication::Reader.new(user_id: actor.user_id, role: actor.role, school_id: actor.school_id, classroom_id: nil) unless actor.student?

        classroom_id, school_id = Orm::ClassroomStudent.joins(:classroom)
                                                       .where(student_id: actor.user_id, primary: true, left_at: nil,
                                                              classrooms: { status: "active" })
                                                       .pick("classrooms.id", "classrooms.school_id")
        Entities::Communication::Reader.new(user_id: actor.user_id, role: :student, school_id:, classroom_id:)
      end

      def readable?(reader:, public_id:, now:) = scope(reader:, now:).exists?(public_id:)
    end
  end
end

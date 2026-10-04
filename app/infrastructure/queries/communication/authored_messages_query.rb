# 🔌 INFRA · Queries::Communication::AuthoredMessagesQuery
# Rôle : « Mes annonces » (20 par page, « Terminée » déduite de la date de fin) et ce que montre le formulaire d'une annonce
# ADR  : 0026, 0078 · UDR : 0071 (§3.7, §3.8)
module Queries
  module Communication
    class AuthoredMessagesQuery
      PER_PAGE = 20
      # status : celui de la ligne, ou "ended" pour une annonce publiée dont la date de fin est passée (ADR-0078 §4.1).
      # at : la date montrée (publication, fin, archivage ou retrait) ; last_day : dernier jour d'affichage d'une publiée.
      Row = Data.define(:public_id, :title, :illustration, :image, :status, :audience, :school_name, :classroom_names, :at,
                        :last_day) do
        # Modifier et archiver : ni terminée, ni archivée, ni retirée (UDR-0071 §3.7).
        def manageable? = %w[draft scheduled published].include?(status)
      end
      Page = Data.define(:rows, :page, :pages)
      School = Data.define(:public_id, :name)
      # Une annonce vue par son formulaire : son établissement et ses classes par public_id, ses fichiers.
      Edited = Data.define(:school_public_id, :classroom_public_ids, :image, :audio)

      IMAGE = Arel.sql("EXISTS (SELECT 1 FROM active_storage_attachments files WHERE files.record_type = 'Orm::Message' " \
                       "AND files.record_id = messages.id AND files.name = 'image')").freeze
      COLUMNS = [ "messages.id", "messages.public_id", "messages.title", "messages.illustration", IMAGE, "messages.status",
                  "messages.audience", "schools.name", "messages.published_at", "messages.ends_at", "messages.updated_at",
                  "messages.withdrawn_at" ].freeze

      # Trois requêtes, quel que soit le nombre d'annonces et de classes : le compte, les lignes, leurs classes.
      def page(author_id:, page:, now:)
        scope = Orm::Message.where(author_id:)
        pages = [ scope.count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages) # to_s : page[]=2 donne un tableau
        records = scope.left_joins(:school).order(created_at: :desc, id: :desc).offset((page - 1) * PER_PAGE).limit(PER_PAGE)
                       .pluck(*COLUMNS)
        names = classroom_names(records.map(&:first))
        Page.new(rows: records.map { |id, *values| row(values, names.fetch(id, []), now) }, page:, pages:)
      end

      # Les classes que l'enseignant peut viser : actives, de son établissement, où il enseigne ; par niveau puis par nom.
      # → [[nom, public_id]]
      def classroom_choices(teacher_id:, school_id:)
        Orm::Classroom.joins(:level, :teacher_classrooms)
                      .where(teacher_classrooms: { teacher_id: }, school_id:, status: "active")
                      .pluck("classrooms.name", "classrooms.public_id", "levels.position")
                      .sort_by { |name, _, position| [ position, natural_key(name) ] }.map { |name, public_id, _| [ name, public_id ] }
      end

      # L'établissement d'un formulaire, par son public_id (l'équipe, depuis sa fiche) ou son id (la direction).
      # → School | nil
      def school(public_id: nil, id: nil)
        values = Orm::School.where(public_id:).or(Orm::School.where(id:)).pick(:public_id, :name)
        values && School.new(*values)
      end

      # message : Entities::Communication::Message. → Edited
      def edited(message)
        attached = ActiveStorage::Attachment.where(record_type: "Orm::Message", record_id: message.id).pluck(:name)
        Edited.new(school_public_id: Orm::School.where(id: message.school_id).pick(:public_id),
                   classroom_public_ids: Orm::Classroom.where(id: message.classroom_ids).pluck(:public_id),
                   image: attached.include?("image"), audio: attached.include?("audio"))
      end

      private

      def row(values, classroom_names, now)
        public_id, title, illustration, image, status, audience, school_name, published_at, ends_at, updated_at, withdrawn_at = values
        status = "ended" if status == "published" && ends_at <= now
        at = { "scheduled" => published_at, "published" => published_at, "ended" => ends_at, "archived" => updated_at,
               "withdrawn" => withdrawn_at }[status]
        # La date de fin est le lendemain du dernier jour d'affichage, à 00:00 (UDR-0071 §3.8).
        last_day = (ends_at - 1).to_date if status == "published"
        Row.new(public_id:, title:, illustration:, image:, status:, audience:, school_name:, classroom_names:, at:, last_day:)
      end

      # → { message_id => [noms des classes, « 6ème 2 » avant « 6ème 10 »] }
      def classroom_names(message_ids)
        Orm::MessageClassroom.joins(:classroom).where(message_id: message_ids).pluck(:message_id, "classrooms.name")
                             .group_by(&:first).transform_values { |pairs| pairs.map(&:last).sort_by { natural_key(it) } }
      end

      def natural_key(name)
        name.scan(/\d+|\D+/).map { |part| part.match?(/\A\d/) ? [ 0, part.to_i ] : [ 1, part ] }
      end
    end
  end
end

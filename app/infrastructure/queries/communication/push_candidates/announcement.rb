# 🔌 INFRA · Queries::Communication::PushCandidates::Announcement
# Rôle : candidats du motif announcement : annonce publiée par l'équipe depuis moins de 48 h, ni retirée ni terminée, que l'élève lit et n'a pas masquée
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · 0078 (§4.3 : règle de lecture) · 0045 · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class Announcement
        WINDOW = 48.hours
        Reader = Data.define(:school_id, :classroom_id)

        # → [Entities::Communication::PushCandidate] ; un nombre fixe de lectures (annonces, classes ciblées, abonnés, inscriptions, masquages).
        # La règle de lecture est celle de ReadableMessages#scope, évaluée en mémoire pour tous les élèves à la fois (test de parité).
        def for(now:)
          messages = messages(now)
          return [] if messages.empty?

          student_ids = subscribed_user_ids
          return [] if student_ids.empty?

          readers = readers(student_ids)
          targets = targets(messages)
          dismissed = Orm::MessageDismissal.where(message_id: messages.map(&:id), user_id: student_ids).pluck(:message_id, :user_id).to_set
          messages.flat_map do |message|
            readers.filter_map do |student_id, reader|
              next if dismissed.include?([ message.id, student_id ]) || !reads?(message, reader, targets)

              Entities::Communication::PushCandidate.new(user_id: student_id, motive: "announcement", object_key: "announcement:#{message.public_id}",
                                                         url: Rails.application.routes.url_helpers.announcements_path, variables: {},
                                                         valid_until: message.published_at + WINDOW)
            end
          end
        end

        private

        # L'annonce de l'équipe, publiée dans les 48 h, encore en cours, pour les élèves (tous, élèves, ou classes ciblées).
        def messages(now)
          Orm::Message.joins(:author).where(users: { role: "team" }, status: "published", published_at: (now - WINDOW)..now)
                      .where("messages.ends_at > ?", now).where(audience: %w[all students classrooms]).order(:id)
                      .select(:id, :public_id, :audience, :school_id, :published_at).to_a
        end

        # { message_id => [classroom_id] } des annonces par classes.
        def targets(messages)
          Orm::MessageClassroom.where(message_id: messages.select { it.audience == "classrooms" }.map(&:id))
                               .pluck(:message_id, :classroom_id).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
        end

        # ADR-0078 §4.3 : audience « all » ou « students » de l'école du lecteur ou nationale ; « classrooms » : sa classe principale active.
        def reads?(message, reader, targets)
          return Array(targets[message.id]).include?(reader.classroom_id) if message.audience == "classrooms"

          message.school_id.nil? || message.school_id == reader.school_id
        end

        # { student_id => Reader } : la classe principale active et son école ; sans classe active, l'école de la dernière inscription.
        def readers(student_ids)
          rows = Orm::ClassroomStudent.joins(:classroom).where(student_id: student_ids)
                                      .order(:student_id, joined_at: :desc, id: :desc)
                                      .pluck(:student_id, :primary, :left_at, "classrooms.status", "classrooms.id", "classrooms.school_id")
          rows.group_by(&:first).transform_values do |memberships|
            active = memberships.find { |_, primary, left_at, status| primary && left_at.nil? && status == "active" }
            active ? Reader.new(school_id: active[5], classroom_id: active[4]) : Reader.new(school_id: memberships.first[5], classroom_id: nil)
          end.merge(student_ids.index_with { Reader.new(school_id: nil, classroom_id: nil) }) { |_, known, _| known }
        end

        # Abonnés, non coupés, non anonymisés.
        def subscribed_user_ids
          Orm::Communication::PushSubscription.joins(:user).where(users: { anonymized_at: nil })
                                              .where.not(user_id: Orm::Communication::PushPreference.where.not(turned_off_at: nil).select(:user_id))
                                              .distinct.pluck(:user_id)
        end
      end
    end
  end
end

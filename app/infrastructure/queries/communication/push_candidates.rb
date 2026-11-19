# 🔌 INFRA · Queries::Communication::PushCandidates
# Rôle : les candidats des six motifs, réunis ; chaque motif a sa requête, remplie par son lot
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2, §6)
module Queries
  module Communication
    class PushCandidates
      include Ports::Communication::PushCandidatesPort

      SOURCES = [ PushCandidates::Inactive, PushCandidates::AssignmentDue, PushCandidates::QuizPrep, PushCandidates::Announcement,
                  PushCandidates::Result, PushCandidates::Unfinished ].freeze

      def initialize(sources: SOURCES.map(&:new)) = @sources = sources

      # → [Entities::Communication::PushCandidate], tous motifs confondus ; chaque source lit son motif, rien d'autre.
      def for(now:, user_ids: nil) = @sources.flat_map { it.for(now:, user_ids:) }
    end
  end
end

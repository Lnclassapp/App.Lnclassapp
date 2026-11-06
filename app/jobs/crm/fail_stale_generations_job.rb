# 🔌 INFRA · Crm::FailStaleGenerationsJob
# Rôle : toutes les 15 minutes, ferme (`timeout`) les générations restées « en attente » de toutes les écoles et purge leur audio, même si personne ne revient sur l'école
# ADR  : XXXX (modèles de langage) · CA-25 · config/recurring.yml
module Crm
  class FailStaleGenerationsJob < ApplicationJob
    def perform
      closed = Repositories::Crm::GenerationRepository.new.fail_stale(school_id: nil, kind: nil, before: UseCases::Crm::RequestBriefing::STALE_AFTER.ago)
      Rails.logger.warn("[crm.generation] #{closed} génération(s) orpheline(s) fermée(s)") if closed.positive?
    end
  end
end

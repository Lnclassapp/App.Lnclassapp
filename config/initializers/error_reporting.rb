# Rails.error n'avait aucun abonné : une erreur signalée « rattrapée » (handled: true), comme une panne de la base
# pendant le compteur de lectures du blog (ADR-0073 §4.7), disparaissait sans trace en production. Cet abonné la
# journalise. Il ignore les erreurs non rattrapées (handled: false) : Rails les journalise déjà (ActionDispatch::
# DebugExceptions pour une requête, Active Job et Solid Queue pour un job) ; les reprendre les doublerait.
module ErrorReporting
  class LogSubscriber
    def report(error, handled:, severity:, context:, source: nil)
      return unless handled

      Rails.logger.error("[Rails.error] #{error.class}: #{error.message} " \
                         "(handled: #{handled}, severity: #{severity}, source: #{source}, context: #{context.inspect})")
    end
  end
end

Rails.error.subscribe(ErrorReporting::LogSubscriber.new)

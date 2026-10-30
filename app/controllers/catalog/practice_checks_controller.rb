# 🌐 DELIVERY · Catalog::PracticeChecksController
# Rôle : « Vérifier » dans « Je m'entraîne » : le serveur juge les réponses de la notion case par case et rend le verdict puis le corrigé, sans rien écrire ; un frame par notion, une page pleine sans JavaScript
# ADR  : XXXX-entrainement-de-notion-corrige-sans-trace (§4), 0026, 0028, 0035 · UDR : XXXX-je-m-entraine-dans-la-fiche §3.4, §3.5, §3.6
module Catalog
  class PracticeChecksController < AuthenticatedController
    include ReadsOwnLevel

    # Par compte, pas par adresse (ADR entraînement corrigé sans trace §4) : 30 vérifications par minute (CA-8).
    rate_limit to: 30, within: 1.minute, by: -> { current_actor.user_id }, with: -> { refuse_too_many }

    # Au plus 6 questions de 6 cases, 10 propositions chacune : au-delà, la forme est forgée et ne compte pas.
    MAX_QUESTIONS = 6
    MAX_ITEMS = 10

    def create
      result = judge
      return present(nil, :changed, :conflict) if result.code == :conflict

      render_result result, success: ->(check) { present(check, :checked, :ok) }
    end

    private

    def use_case
      UseCases::Catalog::CheckPractice.new(notions: Repositories::Catalog::EssentialRepository.new, policy: Policies::Catalog::ReadPublishedPolicy.new,
                                           level_policy: Policies::Catalog::ReadOwnLevelPolicy.new)
    end

    def judge
      use_case.call(
        actor: current_actor, audience: (student_audience if current_actor.student?), course_slug: params[:course_slug],
        notion_slug: params[:slug], digest: params[:digest].to_s, responses:
      )
    end

    # CA-8 : la saisie est gardée ; l'accès est jugé comme pour une vérification (404 hors niveau), le verdict est jeté.
    def refuse_too_many
      result = judge
      return present(nil, :changed, :conflict) if result.code == :conflict

      render_result result, success: ->(check) { present(check, :rate_limited, :too_many_requests) }
    end

    # Sous un frame : le frame seul ; sans en-tête Turbo-Frame (JavaScript coupé) : la page pleine, même statut.
    def present(check, state, status)
      locals = { course_slug: params[:course_slug], notion_slug: params[:slug], practice: check&.practice,
                 check: (check if state == :checked), values: responses, state:, title_id: "notion-#{params[:slug]}-practice-title",
                 notion_name: check&.notion_name }
      if turbo_frame_request?
        render partial: "catalog/practice_checks/result", locals: locals.except(:notion_name), status:
      else
        render :show, locals:, status:
      end
    end

    # La saisie telle que la fiche la poste, ramenée à des chaînes bornées : { "0" => { "blanks" => {…}, "ids" => […], "order" => […], "text" => "…" } }.
    def responses
      @responses ||= begin
        raw = params[:answers].respond_to?(:to_unsafe_h) ? params[:answers].to_unsafe_h : {}
        raw.first(MAX_QUESTIONS).to_h { |key, value| [ key.to_s, answer_input(value) ] }
      end
    end

    def answer_input(value)
      return {} unless value.is_a?(Hash)

      { "blanks" => (value["blanks"].is_a?(Hash) ? value["blanks"].first(MAX_QUESTIONS).to_h { |k, v| [ k.to_s, v.to_s ] } : {}),
        "ids" => list(value["ids"]), "order" => list(value["order"]), "text" => value["text"].to_s }
    end

    def list(value) = value.is_a?(Array) ? value.first(MAX_ITEMS).map(&:to_s) : []
  end
end

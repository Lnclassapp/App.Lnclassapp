require "test_helper"

# ADR-0126 §4.6, UDR-0158 §3 « Redirection de blocage » : seul un chemin de l'application (« /… », jamais « //… » ni une
# adresse complète) est rangé pour le retour après l'activation ; tout autre retour est ignoré, la redirection a lieu quand même.
class RedirectsSubscriptionRequiredTest < ActionDispatch::IntegrationTest
  class ProbeController < ApplicationController
    include RedirectsSubscriptionRequired

    allow_unauthenticated_access

    def show
      session[RedirectsSubscriptionRequired::RETURN_KEY] = nil
      redirect_subscription_required(return_to: params[:return_to])
    end
  end

  with_routing do |set|
    set.draw do
      root to: "homepage#index"
      get "abonnement", to: "billing/subscriptions#show", as: :billing_subscription
      get "probe", to: "redirects_subscription_required_test/probe#show"
    end
  end

  test "un chemin de l'application est rangé pour le retour" do
    get "/probe", params: { return_to: "/cours/racines-carrees" }

    assert_redirected_to "/abonnement"
    assert_equal "/cours/racines-carrees", session[RedirectsSubscriptionRequired::RETURN_KEY]
  end

  test "une adresse d'un autre site ou un retour absent n'est pas rangé, la redirection a lieu" do
    [ "//evil.example", "https://evil.example", "cours", nil ].each do |return_to|
      get "/probe", params: { return_to: }.compact

      assert_redirected_to "/abonnement"
      assert_nil session[RedirectsSubscriptionRequired::RETURN_KEY], return_to.inspect
    end
  end
end

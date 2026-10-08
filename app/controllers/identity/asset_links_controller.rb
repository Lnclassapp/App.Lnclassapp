# 🌐 DELIVERY · Identity::AssetLinksController — /.well-known/assetlinks.json (Digital Asset Links), public
# Rôle : déclare les apps Android autorisées à ouvrir les liens du site, lue dans config.x.android ; ni use case ni query
# ADR  : 0084 (§4.7), 0085 (§4.7), 0070 (R2)
module Identity
  class AssetLinksController < ApplicationController
    RELATION = [ "delegate_permission/common.handle_all_urls" ].freeze

    allow_unauthenticated_access

    def show
      render json: statements
    end

    private

    # Sans empreinte configurée, aucune déclaration : Android ne vérifie rien et les liens s'ouvrent dans le navigateur.
    def statements
      android = Rails.configuration.x.android
      return [] if android[:cert_fingerprints].empty?

      # ADR-0085 §4.7 : une déclaration par app, les mêmes empreintes pour les deux.
      android[:apps].values.map do |app|
        { relation: RELATION,
          target: { namespace: "android_app", package_name: app[:package_name],
                    sha256_cert_fingerprints: android[:cert_fingerprints] } }
      end
    end
  end
end

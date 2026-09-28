# 🌐 DELIVERY · Identity::AccountPhotosController
# Rôle : sert la photo d'un compte sous session et ReadUserPolicy, en cache privé ; aucune adresse Active Storage n'est émise
# ADR  : 0028, 0060 · UDR : 0047
module Identity
  class AccountPhotosController < AuthenticatedController
    # L'adresse porte la version du fichier (?v=) : une nouvelle photo change d'adresse, le cache peut durer.
    CACHE_FOR = 1.day

    def show
      render_result read.call(actor: current_actor, target_public_id: params[:user_public_id]), success: lambda { |photo|
        expires_in CACHE_FOR, public: false
        send_data photo.data, type: photo.content_type, disposition: :inline, filename: "photo"
      }
    end

    private

    def read
      UseCases::Identity::ReadAccountPhoto.new(
        users: Repositories::Identity::UserRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        teachings: Repositories::Classroom::TeachingRepository.new, photos: Repositories::Identity::ProfilePhotoStore.new,
        policy: Policies::Identity::ReadUserPolicy.new
      )
    end
  end
end

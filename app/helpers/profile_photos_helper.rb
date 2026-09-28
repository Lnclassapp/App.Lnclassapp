# 🌐 DELIVERY · ProfilePhotosHelper
# Rôle : adresse de la photo d'un compte pour ui_avatar(src:) ; nil sans photo, et l'avatar montre les initiales
# ADR  : 0060 · UDR : 0047
module ProfilePhotosHelper
  # version : Queries::Identity::PhotoVersions ; elle change avec le fichier, donc l'adresse aussi.
  def account_photo_src(public_id, version)
    main_app.account_photo_path(public_id, v: version) if version
  end
end

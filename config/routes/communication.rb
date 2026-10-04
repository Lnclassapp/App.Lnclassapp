# 🌐 DELIVERY · routes du contexte communication
# Rôle : annonces — toutes les routes du chantier, gelées au Lot 0 ; une annonce par son public_id, sans page de détail
# ADR  : 0045, 0069 · UDR : 0056 · V6
scope module: "communication" do
  get "announcements", to: "inboxes#show", as: :announcements
  get "announcements/mine", to: "authored_messages#index", as: :my_announcements
  get "announcements/moderation", to: "moderations#index", as: :moderated_announcements
  get "announcements/new", to: "authored_messages#new", as: :new_announcement
  post "announcements", to: "authored_messages#create"
  get "announcements/:public_id/edit", to: "authored_messages#edit", as: :edit_announcement
  patch "announcements/:public_id", to: "authored_messages#update", as: :announcement
  post "announcements/:public_id/archive", to: "message_archives#create", as: :announcement_archive
  post "announcements/:public_id/withdrawal", to: "message_withdrawals#create", as: :announcement_withdrawal
  post "announcements/:public_id/dismissal", to: "message_dismissals#create", as: :announcement_dismissal
  delete "announcements/:public_id/dismissal", to: "message_dismissals#destroy"
  get "announcements/:public_id/:kind", to: "message_files#show", as: :announcement_file, constraints: { kind: /image|audio/ }
end

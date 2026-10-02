# 🌐 DELIVERY · routes du contexte communication
# Rôle : annonces ; questions fréquentes (/aide, publique)
# ADR  : 0045 · V6 · UDR : 0061 (FAQ)
get "aide", to: "communication/help#show", as: :help

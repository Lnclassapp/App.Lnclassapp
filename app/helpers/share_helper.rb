# 🌐 DELIVERY · ShareHelper
# Rôle : liens de partage vers WhatsApp (wa.me) et l'application SMS, avec un message prêt ; liens sortants, aucun script tiers
# ADR  : 0049, 0063 · UDR : 0050
module ShareHelper
  def whatsapp_share_url(text) = "https://wa.me/?text=#{ERB::Util.url_encode(text)}"
  def sms_share_url(text) = "sms:?body=#{ERB::Util.url_encode(text)}"
end

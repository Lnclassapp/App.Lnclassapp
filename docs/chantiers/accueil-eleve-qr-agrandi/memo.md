# Memo — Accueil élève : le QR en grand, avec le partage WhatsApp

**Demande** (porteur, 2026-11-24, relayée par l'orchestrateur) : « Ajoute au click sur le QR code de l'élève : sur mobile, un pop-up en plein écran ; sur d'autres écrans, un pop-up. Ajoute le lien de partage vers WhatsApp. »

**Acteur** : l'élève avec une classe, sur son accueil.

**Pourquoi** : le QR de la carte de classe (96 px) se scanne mal à plus d'un bras ; l'adresse de l'établissement ne se partage pas à un camarade absent.

**Périmètre** : vue `_class_card`, un placement `ui_modal`, une règle CSS, des clés I18n. Aucune route, aucun use case, aucune donnée : l'adresse partagée est celle que le QR porte déjà (ADR-0145).

**Hors périmètre** : un scanner dans l'application ; le QR de l'enseignant ou de la direction.

Décision d'interface : [UDR-XXXX accueil-eleve-qr-agrandi](../../decisions/udr/0182-accueil-eleve-qr-agrandi.md).

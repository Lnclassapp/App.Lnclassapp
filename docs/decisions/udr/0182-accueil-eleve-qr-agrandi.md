# UDR-0182 : Accueil élève — le QR de l'établissement en grand, avec le partage WhatsApp
<!-- index
titre: Accueil élève, QR en grand et partage WhatsApp
statut: Accepté
adr-lie: [0145](../adr/0145-adresse-publique-etablissement.md)
problematique: Le QR de la carte de classe est trop petit pour être scanné de loin, et l'adresse de l'établissement ne se partage pas à distance
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-24 |
| **Chantier** | `docs/chantiers/accueil-eleve-qr-agrandi` |
| **ADR lié** | ADR-0145 |
| **Amende** | UDR-0179 §3.1 (le QR devient un bouton) |
| **Remplacé par** | — |

---

## 1. Contexte

Porteur, 2026-11-24 : « Ajoute au click sur le QR code de l'élève : sur mobile, un pop-up en plein écran ; sur d'autres écrans, un pop-up. Ajoute le lien de partage vers WhatsApp. » Référence : la carte de Wave (feuille blanche plein écran, croix, grande carte de marque à motif portant un panneau blanc et un grand QR, logo en bas à gauche).

## 2. Décision

Le cadre du QR de la carte de classe devient un bouton qui ouvre le QR en grand dans le `ui_modal` du projet. Un nouveau placement `:phone_full` le met en plein écran sous 700 px (palier du téléphone, UDR-0086 §3.5) et en modale centrée `sm` au-delà. Sous la carte, une phrase et « Partager sur WhatsApp », qui envoie l'adresse publique de l'établissement, celle du QR (ADR-0145). De Wave on ne reprend pas le contrôle « Scanner un code | Ma carte » : l'application n'a pas de scanner.

## 3. Règles d'implémentation

**Bouton** — `button#student_school_qr_button` (`type=button`, `aria-haspopup=dialog`, `aria-controls`, `aria-label` « Agrandir le QR de %{school} »), même cadre que le QR d'avant (`w-24 rounded-ln ring-2 ring-brand/20`). Le petit QR et « Scanner » y sont `aria-hidden`.

**Fenêtre** — `ui_modal id: "student_school_qr_dialog", size: :sm, placement: :phone_full`, titre « QR de ton établissement », décrite par la phrase.
- Carte `qr-card-pattern rounded-sheet bg-brand p-5`, `max-w-80` : panneau `rounded-card bg-white p-4` avec le grand QR (`#student_school_qr_large`, `role=img`, nom `qr_label`), puis le logo sur un disque blanc et le nom de l'établissement en blanc.
- Phrase `text-sm text-mute` : « Fais-le scanner pour s'inscrire : élèves et enseignants. » (texte du porteur)
- `ui_button` primaire pleine largeur `#student_school_qr_whatsapp`, `chat-bubble-left-right`, nouvel onglet : `whatsapp_share_url` du message « Inscris-toi sur Lnclass avec %{school} : %{url} », où `url` = `school_signup_link_url(public_id)`. Ni jeton de classe, ni donnée de l'élève.

**Placement `:phone_full`** — `dialog.dialog-phone-full`, hors couche comme les feuilles : sous 700 px, `margin: 0`, largeur 100 %, hauteur `100dvh`, sans coins, marges de sécurité ; ouverte, colonne flex dont le dernier enfant (le corps, sans pied) est centré en hauteur. Le vide autour est la `<dialog>` : un clic hors du contenu la ferme.

**Fermeture** — croix du composant, Échap, clic sur le fond ou hors du contenu ; le focus revient au bouton du QR (`modal_controller`).

### États

- Pas de classe : pas de carte, donc ni QR ni fenêtre.
- Sans JavaScript : le bouton n'ouvre rien ; le QR reste lisible dans la carte.

### Accessibilité

`<dialog>` modale (focus piégé, Échap, titre lié, description liée) ; bouton nommé ; tokens seulement.

## 4. Conséquences

- Un placement de plus pour `ui_modal`, réutilisable par toute fenêtre qui doit occuper le téléphone.
- La croix reste à droite, comme dans toutes les fenêtres du projet, et non à gauche comme chez Wave (À trancher du journal).

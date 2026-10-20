# UDR-0122 : Consentement WhatsApp — une ligne du profil, une fenêtre qui dit ce qui sera envoyé, un accord qu'on retire en un geste
<!-- index
titre: Consentement WhatsApp sur le profil
statut: Proposé
adr-lie: [0102](../adr/0102-canal-whatsapp-sortant-port-d-envoi-consentement-et-avis-d-annonce.md)
problematique: Ligne « Annonces sur WhatsApp » dans « Mes informations » (enseignant, direction, équipe ; élève seulement si `whatsapp.students`) ; fenêtre d'accord qui montre le message type et le numéro ; état « Activé », « Désactivé », « À confirmer pour ce numéro » ; retrait sans confirmation. Amende UDR-0041 et UDR-0089.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/canal-whatsapp`](../../chantiers/canal-whatsapp/memo.md) — Lot A |
| **ADR lié** | [ADR-0102](../adr/0102-canal-whatsapp-sortant-port-d-envoi-consentement-et-avis-d-annonce.md) §4.2, §4.3 |
| **Amende** | [UDR-0041](0041-page-profil.md) (carte « Mes informations ») · [UDR-0089](0089-profil-eleve-carte-bleue-lignes-a-toucher-et-se-deconnecter.md) (lignes de l'élève, si les élèves sont ouverts) |
| **Remplacé par** | — |

---

## 1. Contexte

L'ADR-0102 n'écrit qu'à un compte qui a accepté, pour son numéro actuel. L'accord doit donc se donner quelque part, se prouver (version du texte affiché) et se retirer aussi facilement qu'il se donne. Le profil est l'endroit où le compte voit déjà son numéro : c'est là que l'accord a un sens (« ce numéro-ci »).

## 2. Décision

- **Une ligne de plus** dans la carte « Mes informations », sous la ligne du numéro : « Annonces sur WhatsApp ». Pas de page de réglages : il n'y a qu'un réglage.
- **Activer ouvre une fenêtre** (le `turbo_frame "modal"` des autres lignes) qui montre **le message type tel qu'il sera reçu** et le numéro concerné, puis « Activer ». On n'accepte pas un texte juridique abstrait : on accepte un message qu'on voit.
- **Désactiver ne demande pas de confirmation** : retirer un accord ne doit pas coûter plus qu'un geste.
- **Pas de bandeau** ni de fenêtre surgissante à la connexion pour réclamer l'accord : un accord obtenu par insistance n'en est pas un.

## 3. Règles d'implémentation

**Structure**
- Ligne dans `app/views/identity/profiles/_information.html.erb` (enseignant, direction, équipe), même gabarit `dt`/`dd` + `ui_button` que la ligne « Photo » ; dans `_student_information.html.erb` par le partiel `identity/profiles/student_row`, **seulement si** `Rails.configuration.x.whatsapp.students` est vrai. Sinon la ligne n'est pas rendue (aucun état « indisponible »).
- La ligne est rendue par le partiel `communication/whatsapp_consents/_row.html.erb`, id `whatsapp_consent_row`, qui reçoit l'état calculé par `Queries::Communication::WhatsappConsentQuery` (un appel, pas de requête dans la vue).
- Fenêtre : `communication/whatsapp_consents/new.html.erb` dans `ui_modal` (feuille par le bas sous 700 px, centrée au-delà, comme UDR-0089).
  1. Titre `h2` : « Recevoir les annonces sur WhatsApp ».
  2. Paragraphe : « Lnclass t'enverra un message sur WhatsApp au **{numéro groupé}** quand ton établissement ou l'équipe Lnclass publie une annonce. » (vouvoiement pour les adultes, tutoiement pour l'élève — UDR-0041).
  3. **Aperçu du message** : une bulle (`rounded-card bg-mist p-4 text-sm`) avec le texte exact du modèle `announcement_notice` rempli pour ce compte (nom de son établissement, lien).
  4. Liste de 3 points : « Pas le contenu de l'annonce, seulement un avis et un lien. » · « Jamais entre 20 h et 7 h. » · « Réponds STOP ou reviens ici pour arrêter. »
  5. `ui_button "Activer"` (`variant: :brand`, `full: true`), puis `ui_button "Annuler"` (`variant: :secondary`).
- Formulaire : `POST /profile/whatsapp_consent` (activer, champ caché `text_version`), `DELETE /profile/whatsapp_consent` (désactiver, `button_to`).

**États de la ligne**

| État | Libellé (`dd`) | Action | Badge |
|---|---|---|---|
| Désactivé (aucune ligne, ou révoquée) | « Désactivées » | `ui_button "Activer"` `variant: :secondary`, ouvre la fenêtre | — |
| Activé | « Activées pour ce numéro » | `button_to "Désactiver"` `variant: :secondary` | `ui_badge tone: :success, dot: true` « Actif » |
| À confirmer (empreinte ≠ numéro actuel) | « Ton numéro a changé : à réactiver » | `ui_button "Réactiver"`, ouvre la fenêtre | `ui_badge tone: :warning` |
| Désactivé par STOP | « Désactivées depuis WhatsApp (STOP) » | `ui_button "Activer"` | — |
| Compte sans numéro | Ligne non rendue | — | — |

**Tokens**
- Couleurs du design system uniquement : `text-ink`, `text-mute`, `border-line`, `bg-mist`, tons `success` / `warning` de `ui_badge`. Aucune couleur WhatsApp (vert de la marque) : l'icône est `chat-bubble-left-right`, comme la carte d'aide.
- Typographie et espacements : ceux de la ligne « Photo » (`py-3`, `text-sm`).

**Comportement**
- Activer : réponse `turbo_stream` qui ferme la fenêtre (`turbo_stream.update "modal"`), remplace `whatsapp_consent_row` et affiche `ui_toast` « Annonces WhatsApp activées. »
- Désactiver : `turbo_stream.replace "whatsapp_consent_row"` + `ui_toast` « Annonces WhatsApp désactivées. »
- Sans JavaScript : `POST`/`DELETE` puis redirection vers `/profile` avec le message flash.
- Double envoi : le bouton porte `data-turbo-submits-with` (« Activation… »).

**États obligatoires**
- Vide : sans objet (la ligne a toujours un état).
- Chargement : `data-turbo-submits-with` sur le bouton.
- Erreur : échec d'écriture → la fenêtre reste ouverte, `role="alert"` en tête « L'activation n'a pas abouti. Réessaie. » (422).
- Succès : toast + ligne remplacée.

**Accessibilité**
- Cibles ≥ 48 px (`min-h-tap`).
- La fenêtre a `aria-labelledby` sur son titre ; le focus va au titre à l'ouverture et revient au bouton « Activer » de la ligne à la fermeture.
- L'aperçu du message est un `blockquote` avec `aria-label="Message que tu recevras"`.
- Le badge n'est pas la seule indication : le libellé du `dd` dit l'état en toutes lettres.

## 4. Conséquences

- La carte « Mes informations » gagne une ligne pour trois rôles, et pour l'élève quand les juristes l'autorisent : l'activation des élèves ne demande alors aucun changement d'interface.
- Le texte d'accord a une version (`consent_text_version`) : changer le texte de la fenêtre oblige à changer la version, et les accords déjà donnés restent prouvés pour l'ancienne.
- Interdit désormais : réclamer l'accord WhatsApp ailleurs que sur le profil (bandeau, inscription, fenêtre à la connexion) sans nouvelle UDR.

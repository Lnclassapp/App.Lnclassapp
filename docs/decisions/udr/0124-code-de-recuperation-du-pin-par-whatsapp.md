# UDR-0124 : Code de récupération du PIN par WhatsApp — un lien « Recevoir un code sur WhatsApp » sur l'écran de récupération, une réponse identique que le compte existe ou non
<!-- index
titre: Code de récupération du PIN par WhatsApp (gelé)
statut: Proposé — *gelé jusqu'à la vérification du numéro (chantier `verification-whatsapp`)*
adr-lie: [0102](../adr/0102-canal-whatsapp-sortant-port-d-envoi-consentement-et-avis-d-annonce.md)
problematique: Sur `pin_resets/new` et la connexion, « Recevoir un code sur WhatsApp » : saisie du numéro, réponse unique quel que soit le compte, puis le formulaire existant pré-rempli ; renvoi après 60 s, 3 par heure ; le code dicté par l'enseignant reste le recours. Amende UDR-0060.
-->

| | |
|---|---|
| **Statut** | Proposé — **gelé** (ADR-0102 §4.7) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/canal-whatsapp`](../../chantiers/canal-whatsapp/memo.md) — Lot D, gelé |
| **ADR lié** | [ADR-0102](../adr/0102-canal-whatsapp-sortant-port-d-envoi-consentement-et-avis-d-annonce.md) ; amendement de l'[ADR-0032](../adr/0032-recuperation-assistee-du-pin.md) **à écrire** au dégel |
| **Amende** | [UDR-0060](0060-connexion-et-recuperation-du-pin.md) (écran « Nouveau code secret ») |
| **Remplacé par** | — |

---

## 1. Contexte

Un élève qui a oublié son PIN attend aujourd'hui qu'un enseignant ou l'équipe lui dicte un code (ADR-0032) : aucune récupération le soir, en autonomie. Le porteur a demandé si le code pouvait partir sur WhatsApp (feuille de route, Q14).

**Pourquoi gelé** : le numéro d'un compte n'est pas prouvé. Envoyer un code au numéro saisi à l'inscription donnerait le compte à quiconque reçoit les messages de ce numéro. Cette UDR décrit l'écran pour qu'il ne soit pas recadré ; elle ne s'applique **qu'après** la livraison de `verification-whatsapp` et l'amendement de l'ADR-0032.

## 2. Décision

- **Un lien de plus** sur l'écran de récupération, pas un nouvel écran d'entrée : « Recevoir un code sur WhatsApp ». Le chemin assisté (code dicté) reste affiché, il reste le recours.
- **Une réponse identique** que le numéro corresponde à un compte, à un compte vérifié, ou à rien : « Si ce numéro a un compte Lnclass vérifié, un code vient de partir sur WhatsApp. » L'écran ne doit pas permettre de savoir qui a un compte.
- **Le formulaire existant** (numéro, code, nouveau PIN deux fois) reçoit ensuite le code : un seul endroit où saisir un code, quelle que soit sa source.
- **Pas d'accord préalable** aux annonces (UDR-0122) : demander son propre code est une demande, pas un abonnement. Le message est un modèle « authentification » distinct.

## 3. Règles d'implémentation

**Structure**
- `app/views/identity/pin_resets/new.html.erb` : sous le titre de la carte, `ui_button "Recevoir un code sur WhatsApp"` (`variant: :secondary`, `full: true`, icône `chat-bubble-left-right`), vers `GET /pin_reset/whatsapp_code/new`.
- `app/views/identity/whatsapp_pin_codes/new.html.erb` : même carte que la connexion (`ui_card heading: :h1`, logo, `ui_back_link "Se connecter"`).
  1. Titre : « Recevoir un code sur WhatsApp ».
  2. `ui_field :contact, as: :tel` (mêmes attributs que `pin_resets/new`).
  3. `ui_button "Envoyer le code"` (`variant: :brand`, `full: true`).
  4. Texte `text-sm text-mute` : « Pas de WhatsApp sur ce numéro ? Demande un code à ton enseignant. »
- Après envoi : redirection vers `pin_resets/new` avec le numéro pré-rempli, une bannière `role="status"` (`bg-info-soft`) au texte unique ci-dessus, et le champ « Code » focalisé.

**Tokens**
- Ceux de `pin_resets/new` et de la connexion (UDR-0060) ; aucun ajout.

**Comportement**
- `rate_limit` par IP (5 par 10 minutes) **et** par numéro (3 par heure, côté use case) ; au-delà, la même réponse unique (rien n'est envoyé, rien n'est dit).
- Bouton « Renvoyer le code » sur `pin_resets/new` seulement après 60 s : `ui_button` désactivé avec décompte, rendu actif par le serveur au rechargement (pas de minuterie indispensable côté client).
- Le code envoyé est celui de l'ADR-0032 (8 chiffres, 15 min, 5 essais) ; en émettre un nouveau révoque le précédent.

**États obligatoires**
- Vide : formulaire.
- Chargement : `data-turbo-submits-with="Envoi…"`.
- Erreur : numéro au mauvais format → erreur de champ (422), seul cas qui ne renvoie pas la réponse unique, car il ne révèle rien.
- Succès : la réponse unique, quel que soit le résultat réel.

**Accessibilité**
- `autocomplete="one-time-code"` sur le champ code (déjà présent).
- La bannière est `role="status"` ; le focus va au champ « Code ».
- Cibles ≥ 48 px.

## 4. Conséquences

- L'écran de récupération propose deux chemins, l'autonome d'abord, l'assisté ensuite.
- Interdit : tout message d'erreur qui distingue « numéro inconnu », « numéro non vérifié » ou « pas de WhatsApp ».
- Au dégel : écrire l'amendement de l'ADR-0032 (émetteur « le compte lui-même, par WhatsApp » ; journal `pin.recovery_code_sent`) avant le code du Lot D.

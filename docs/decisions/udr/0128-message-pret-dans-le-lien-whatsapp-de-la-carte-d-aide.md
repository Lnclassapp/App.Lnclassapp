# UDR-0128 : Message prêt dans le lien WhatsApp de la carte d'aide — la personne connectée se présente déjà
<!-- index
titre: Message prêt dans le lien WhatsApp de la carte d'aide
statut: Accepté
adr-lie: [0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md)
problematique: La ligne WhatsApp de la carte d'aide ouvre une conversation vide : le support doit demander qui écrit. Le lien devient `wa.me/<numéro>?text=<message encodé>` : élève (nom, classe, établissement), enseignant(e) (nom, matière, établissement), direction (nom, établissement) ; équipe et visiteur : « Bonjour Lnclass, ma question : ». Jamais un numéro, un secret ni un identifiant. La direction gagne « Besoin d'aide ? » dans son en-tête. Amende UDR-0061 §3.4 et UDR-0006.
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16 : « je peux avoir un lien du type wa.me/0584258085 avec un texte pour introduire les informations de la personne qui nous écrit » ; textes choisis sur recommandation, à confirmer — [memo](../../chantiers/aide-whatsapp-message-pret/memo.md))* |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/aide-whatsapp-message-pret`](../../chantiers/aide-whatsapp-message-pret/memo.md) |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucun service tiers : un lien sortant, aucun script) |
| **Amende** | [UDR-0061](0061-carte-d-aide-et-faq.md) §3.4 (lien de la ligne WhatsApp) · [UDR-0006](0006-shell-applicatif-par-role.md) (« Besoin d'aide ? » dans l'en-tête de la direction) · s'applique sous [UDR-0057](0057-ecrans-eleve-epures.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Quand une personne touche « Chatter avec le support » dans la carte d'aide, WhatsApp s'ouvre sur une conversation vide. Elle écrit « bonjour », le support répond « qui êtes-vous, de quelle école ? », et la vraie question n'arrive qu'au troisième message. Pour un élève sur un forfait limité, chaque aller-retour compte. La direction, elle, n'avait aucun accès à la carte d'aide depuis son en-tête.

## 2. Décision

Le lien WhatsApp porte un **message prêt**, que WhatsApp écrit dans le champ de saisie : la personne le relit, le modifie si elle veut, puis envoie. Le message présente la personne connectée avec ce que le shell a déjà lu pour l'en-tête : nom, rôle (avec la classe ou la matière), établissement. Pas de formulaire, pas d'écran en plus, pas de service tiers. La direction reçoit « Besoin d'aide ? » dans son en-tête, comme l'enseignant.

**Pourquoi pas d'identifiant**, même le `public_id` (ADR-0029) : la personne ne le connaît pas, il n'a aucun sens pour elle dans un message qu'elle relit, et le porteur l'a exclu (« pas d'identifiant interne »). Le nom, l'établissement et le numéro, que WhatsApp transmet, suffisent au support. **Pourquoi pas la page d'origine** : aucune page ne pose de titre lisible dans le shell, et une adresse porterait des `public_id`.

## 3. Règles d'implémentation

### 3.1 Le message, par rôle — `config/locales/shared/help_sheet.fr.yml`, `whatsapp.message`

| Qui | Message |
|---|---|
| Élève avec une classe active | « Bonjour Lnclass, je suis Awa Koné, élève de Tle D 1, Lycée moderne de Cocody. Ma question : » |
| Élève sans classe active | « Bonjour Lnclass, je suis Awa Koné, élève. Ma question : » |
| Enseignant(e) | « Bonjour Lnclass, je suis Yao Kouassi, enseignant de Mathématiques, Lycée moderne de Cocody. Ma question : » — « enseignante » pour un compte `female` |
| Enseignant(e) sans matière ni établissement principal | « …, enseignant. Ma question : » |
| Direction | « Bonjour Lnclass, je suis Koffi Yao, membre de la direction, Collège Notre-Dame. Ma question : » |
| Équipe, visiteur (connexion, inscription élève), shell sans données | « Bonjour Lnclass, ma question : » |

- Les éléments absents sont omis, avec leur virgule (UDR-0057 §2.5) : jamais « élève de , ».
- L'établissement suit après une virgule plutôt que « au … » : l'article dépend du nom (« au Lycée », « à l'École », « à la Cité ») et n'est pas enregistré.
- La fonction de la direction n'est pas enregistrée : « membre de la direction ».
- Le message finit par « Ma question : » suivi d'une espace : la personne écrit à la suite.
- **Jamais** dans le message : le numéro de la personne, son code secret, un code de classe ou d'invitation, un jeton, un identifiant (`id`, `public_id`), une adresse de page.

### 3.2 Le lien — `SupportHelper#support_contacts(user:)`

- `https://wa.me/<numéro>?text=<message>` ; `<numéro>` vient de `config/support.yml` (`whatsapp`), jamais d'une vue ni d'une locale.
- Le numéro est au format international, chiffres seuls, sans `+` ni zéro de tête : `2250584258085` (225 + 10 chiffres pour la Côte d'Ivoire). `wa.me/0584258085` n'ouvre aucune conversation. `test/config/support_config_test.rb` refuse un numéro qui commence par 0.
- Le message est encodé en pourcent par `ERB::Util.url_encode` (espace `%20`, apostrophe `%27`, `é` `%C3%A9`, `&` `%26`), comme `ShareHelper` : un seul paramètre `text`, rien d'autre.
- `target="_blank"`, `rel="noopener noreferrer"` et le nom accessible de la ligne ne changent pas (UDR-0061 §3.3).

### 3.3 Les données — aucune requête de plus

- `shared/_help_sheet` reçoit le `user` de l'en-tête (`ShellUser`, lu une fois par requête par `ShellUserQuery`). `ShellUserQuery` rend les éléments du détail séparés (`about` : classe, matière, établissement, genre) dans les **mêmes** requêtes qu'avant : le genre est une colonne de plus dans la lecture du compte.
- Sans `user` (pages d'entrée, qui n'ont pas le shell), le message simple.

### 3.4 Où la carte est rendue — la direction l'obtient

- Inchangé : en-tête de l'élève et de l'enseignant (UDR-0084 §3.1, UDR-0082 §3.1), connexion et inscription élève (UDR-0080 §3.3).
- **Direction** : son en-tête d'origine (logo, badge du rôle, thème, menu du compte) gagne « Besoin d'aide ? » (icône et libellé), entre le badge et l'interrupteur, à toute largeur. À 390 px, la rangée logo · aide · avatar tient sans défilement horizontal (`test/system/communication/help_sheet_direction_test.rb`).
- **Équipe** : pas de carte ; l'équipe, c'est le support.

**États** : pas d'état vide, de chargement ni d'erreur nouveaux. **Accessibilité** : celle de la carte (UDR-0061 §3.3) ; le bouton de la direction est le même déclencheur que celui de l'enseignant.

## 4. Conséquences

- Tout nouvel endroit qui rend `shared/_help_sheet` dans le shell lui passe `user:` ; sans lui, le message est le message simple, jamais une erreur.
- Ajouter un élément au message (ex. la fonction de la direction) passe par cette UDR et par `ShellUserQuery`, jamais par une requête dans la vue.
- Un texte du message change par la locale seule.

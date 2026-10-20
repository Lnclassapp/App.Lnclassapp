# UDR-0123 : Avis WhatsApp d'une annonce — une case dans le formulaire, le nombre de destinataires avant de publier, le bilan dans « Mes annonces »
<!-- index
titre: Avis WhatsApp d'une annonce
statut: Proposé
adr-lie: [0102](../adr/0102-canal-whatsapp-sortant-port-d-envoi-consentement-et-avis-d-annonce.md)
problematique: Case « Avertir aussi sur WhatsApp » pour l'équipe et la direction seulement, sous le choix de l'audience ; nombre de destinataires recalculé à chaque changement d'audience ; case figée après publication ; ligne « WhatsApp : 214 avertis · 3 échecs » dans « Mes annonces » ; plafond atteint signalé. Amende UDR-0071 et UDR-0075.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/canal-whatsapp`](../../chantiers/canal-whatsapp/memo.md) — Lot B |
| **ADR lié** | [ADR-0102](../adr/0102-canal-whatsapp-sortant-port-d-envoi-consentement-et-avis-d-annonce.md) §4.3 à §4.5 |
| **Amende** | [UDR-0071](0071-annonces.md) (formulaire, « Mes annonces ») · [UDR-0075](0075-annonces-themes-illustrations-et-decompte.md) (ordre des champs) |
| **Remplacé par** | — |

---

## 1. Contexte

Chaque avis coûte. L'auteur doit donc **choisir** d'avertir, **savoir combien** de personnes il va toucher avant de publier, et **voir** après coup combien ont été averties. Sans ces trois éléments, une annonce nationale peut consommer le plafond mensuel sans que personne ne s'en rende compte.

## 2. Décision

- **Une case à cocher**, désactivée par défaut, juste sous le choix de l'audience : c'est l'audience qui fixe le coût, les deux se lisent ensemble.
- **Le nombre de destinataires** s'affiche sous la case et se met à jour quand l'audience change (Turbo Frame, pas de JavaScript de calcul).
- **Après publication**, la case devient un texte : on ne peut ni ajouter ni retirer l'avis d'une annonce publiée (ADR-0102 §4.4).
- **Le bilan** est un compte, jamais une liste de noms (memo, Q12).

## 3. Règles d'implémentation

**Structure — formulaire** (`app/views/communication/authored_messages/_form.html.erb`)
- Rendu **seulement si** le rôle de l'auteur figure dans `whatsapp.authors` et si `whatsapp.enabled` est vrai. Sinon rien (ni case grisée, ni explication).
- Placement : après le bloc « Audience » (et ses classes), avant « Illustration » (UDR-0075).
- Bloc `fieldset` `id="whatsapp_notice_field"` :
  1. `ui_checkbox_group` à une case, `name="message[whatsapp_notice]"`, libellé « Avertir aussi sur WhatsApp ».
  2. Aide (`text-sm text-mute`) : « Un message avec le lien de l'annonce, envoyé à ceux qui l'ont accepté. Jamais entre 20 h et 7 h. »
  3. `turbo_frame_tag "whatsapp_recipients_count"`, `src` = `GET /announcements/whatsapp_recipients?audience=…&school=…`, rechargé par l'action `change->whatsapp-recipients#reload` posée sur les champs d'audience. Contenu : « **214** personnes l'ont accepté dans cette audience. »
  4. Si le décompte dépasse le reste du plafond du mois : `ui_badge tone: :warning` « Plafond du mois : 120 avis restants. Les autres ne seront pas avertis. »
- Annonce déjà publiée (édition) : à la place de la case, une ligne en lecture seule « Avertie sur WhatsApp à la publication » ou « Sans avis WhatsApp ».

**Structure — « Mes annonces »** (`app/views/communication/authored_messages/_row.html.erb`)
- Si `whatsapp_notice` est vrai, une ligne `text-sm text-mute` sous la date, icône `chat-bubble-left-right` (`ui_icon variant: :mini`) :

| Situation | Texte |
|---|---|
| Programmée, ou publiée pendant le silence | « WhatsApp : envoi à 7 h » |
| En cours | « WhatsApp : envoi en cours » |
| Terminé | « WhatsApp : 214 avertis » · si échecs : « · 3 non joints » |
| Plafond atteint | « WhatsApp : 120 avertis · 94 non envoyés (plafond du mois) » avec `ui_badge tone: :warning` |
| Annonce retirée ou archivée pendant l'envoi | « WhatsApp : envoi arrêté, 80 avertis » |

- Les chiffres viennent de `Queries::Communication::WhatsappDeliveryStatsQuery`, une requête groupée pour toute la page (pas de N+1).

**Tokens**
- Couleurs du design system uniquement ; pas de vert WhatsApp. Tons `warning` de `ui_badge` pour le plafond.
- Le nombre en `font-semibold text-ink`, le reste en `text-mute`.

**Comportement**
- Contrôleur Stimulus `communication--whatsapp-recipients` : une seule action, `reload`, qui recompose `src` du frame à partir des champs d'audience. Aucun calcul côté navigateur.
- Le frame a un contenu de repli serveur (le décompte de l'audience initiale) : sans JavaScript, le nombre affiché est celui du premier rendu, et le formulaire reste publiable.
- Un enseignant qui forge `message[whatsapp_notice]=1` : le paramètre est ignoré par le contrôleur (liste blanche par rôle) **et** par la policy.

**États obligatoires**
- Vide : « Personne n'a encore accepté les annonces WhatsApp dans cette audience. » — la case reste cochable (rien ne partira).
- Chargement : le frame garde l'ancien nombre, `aria-busy="true"`.
- Erreur : décompte indisponible → « Nombre indisponible pour l'instant. » ; la publication n'est pas bloquée.
- Succès : le nombre.

**Accessibilité**
- La case a un libellé visible ; l'aide est reliée par `aria-describedby`.
- Le frame du décompte est `aria-live="polite"` : le nouveau nombre est annoncé quand l'audience change.
- Cibles ≥ 48 px (`min-h-tap`) sur la case et son libellé.

## 4. Conséquences

- Le formulaire d'annonce gagne un champ pour l'équipe et la direction ; celui de l'enseignant ne change pas tant que `whatsapp.authors` ne le contient pas.
- Une route de lecture de plus (`GET /announcements/whatsapp_recipients`) soumise à la même policy que la rédaction.
- Interdit : montrer à l'auteur la liste des destinataires ou de ceux qui n'ont pas été joints.

# UDR-XXXX : Écrans de l'équipe pour les points relais, les cartes et la caisse
<!-- index
titre: Points relais, cartes et caisse
statut: Proposé
adr-lie: XXXX-contexte-billing-cartes-activation
problematique: Permettre à l'équipe de créer et imprimer les cartes, de suivre ce que chaque point relais doit et de savoir quoi payer le vendredi, depuis un téléphone sur le terrain.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-07 |
| **Chantier** | `docs/chantiers/cartes-activation` |
| **ADR lié** | ADR-XXXX-contexte-billing-cartes-activation |
| **Remplacé par** | — |

---

## 1. Contexte

Le porteur est sur le terrain à moto, avec son téléphone. Deux fois par jour, un point relais lui verse de l'argent ; le vendredi, il paie les commissions. Il doit saisir un versement en 10 secondes, voir d'un coup d'œil qui lui doit combien, et imprimer une planche de cartes depuis un ordinateur avant de partir.

## 2. Décision

- Une entrée **« Caisse »** dans la navigation de l'équipe (`content_for :nav_key, "billing"`), qui ouvre la caisse ; points relais, lots et versements en partent.
- On reprend le modèle des écrans DRENA (UDR-0053, UDR-0054) : tableau + modale de création, menu ⋮ par ligne. Au téléphone, les tableaux défilent horizontalement (`overflow-x-auto`, colonne d'actions collante).
- La planche d'impression est une page à part, sans navigation, mise en page pour A4 (`@media print`).

## 3. Règles d'implémentation

**Écrans et routes** (namespace `Teams::Billing`, sous `scope "teams"` ; rôle `team`)

1. **Caisse** — `GET /teams/caisse` (`CashboxesController#show`, `app/views/teams/billing/cashboxes/show.html.erb`)
   - `ui_page_header title: "Caisse"`, actions : `ui_button "Saisir un versement"` (modale, icône `banknotes`), `ui_button "Points relais"` (`variant: :secondary`).
   - Trois blocs `ui_card` en colonne :
     a. **À payer ce vendredi** : semaine écoulée (vendredi → jeudi, dates écrites « du 6 au 12 novembre »), tableau point relais · activations · commission (200 F × activations) ; ligne total en `font-semibold`. Vide : « Aucune activation cette semaine-là. »
     b. **Points relais** : tableau nom · cartes remises · activées · annulées · en circulation · versé · **reste dû** (montant en `text-error` s'il est > 0, `text-success` s'il est ≤ 0) ; tri par reste dû décroissant ; clic sur le nom → fiche du point relais.
     c. **Écoles (commission cumulée)** : tableau école · abonnements · commission cumulée (1 000 F ×) ; mention « Versement à une date fixée plus tard ».
   - Sous le bloc a, un lien « Semaines précédentes » ouvre les 8 dernières semaines (même tableau, `<details>`).
2. **Points relais** — `GET /teams/points-relais` (index), `new`, `create`, `edit`, `update` (modale `turbo_frame: "modal"`, comme DRENA). Champs : nom (requis, 80 car.), lieu (requis, 120), téléphone (requis, format `07 00 00 00 00`), écoles (`ui_checkbox_group` filtré par DRENA, recherche texte), actif (case). Pas de suppression : on désactive.
3. **Fiche d'un point relais** — `GET /teams/points-relais/:id` : en-tête (nom, lieu, téléphone `tel:`, écoles en pastilles), les chiffres de la caisse pour lui seul, la liste de ses lots (date, quantité, prix, lien « Imprimer »), ses versements (date, montant signé, référence, motif, auteur), et `ui_button "Nouveau lot de cartes"` (modale : quantité 1 à 200, prix « 10 000 F » ou « Offert (0 F) » en `ui_radio_group`).
4. **Planche d'impression** — `GET /teams/lots/:id/planche` (`CardBatchesController#show`, layout `print`) : grille 3 colonnes × 7 lignes par A4 ; chaque carte 63 × 38 mm, bordure `border-line-strong` pointillée, logo, « Lnclass — abonnement jusqu'au 31 juillet 2027 », « 10 000 F » (ou « Offerte »), **code** en `font-mono text-xl tracking-widest` groupé `XXXX-XXXX-XXXX`, « N° 000021 » en `text-xs text-mute`, « Entre ce code dans Lnclass › Mon abonnement ». Un bouton « Imprimer » (`window.print()`, contrôleur Stimulus `print`) masqué à l'impression.
5. **Annuler une carte** — depuis la caisse, champ « N° de carte » (`GET /teams/cartes/annuler?serial=`) → fiche courte de la carte (numéro, point relais, état) et, si `issued`, formulaire motif (requis, 200 car.) + `ui_button "Annuler la carte"` (`variant: :danger`) avec confirmation (`data-turbo-confirm` « Le code ne passera plus jamais. Annuler la carte N° 000021 ? »). Si `activated` : texte « Une carte activée ne s'annule pas. » sans formulaire.
6. **Saisir un versement** — modale : point relais (`select`), montant (entier, peut être négatif, aide « Négatif pour corriger une erreur »), date et heure de réception (défaut : maintenant), référence Wave (facultative, 60 car.), motif (requis si le montant est négatif). Succès : la modale se ferme, la caisse se recharge (Turbo Stream `replace` des blocs `#cashbox_relays` et `#cashbox_week`), toast « Versement enregistré ».

**Tokens**
- Mêmes tableaux que DRENA : `rounded-card border border-line bg-white shadow-card`, en-têtes `text-xs text-mute`, lignes `divide-y divide-line`.
- Montants alignés à droite, `tabular-nums`, écrits « 10 000 F ».
- Couleur de rôle de l'équipe : `team` pour la pastille de navigation.

**Comportement**
- Modales via `turbo_frame: "modal"` et le composant `_modal` ; fallback sans JS : pages pleines `new`/`edit`.
- Formulaires invalides : `render :new, status: :unprocessable_content` dans la modale.
- Ids Turbo : `#relay_points` (tbody), `#cashbox_week`, `#cashbox_relays`, `#cashbox_schools`.

**États obligatoires**
- Vide : caisse sans point relais → `ui_empty_state` « Aucun point relais », bouton « Créer un point relais » ; point relais sans lot → « Aucun lot de cartes ».
- Chargement : boutons de soumission avec `data-turbo-submits-with`.
- Erreur : alerte `role="alert"` en tête de formulaire (modèle `_form` DRENA) ; carte introuvable → « Aucune carte ne porte ce numéro. ».
- Succès : toast, et la ligne ou le bloc remplacé par Turbo Stream.

**Accessibilité**
- Tableaux avec `th scope="col"` et une légende `sr-only` ; colonne d'actions avec libellé `sr-only`.
- Cibles ≥ 48 px ; focus visible ; confirmation d'annulation lisible par lecteur d'écran (`data-turbo-confirm`).
- La planche imprimée n'a pas d'exigence d'accessibilité (support papier) ; la page porte un `h1` `sr-only`.

## 4. Conséquences

- La navigation de l'équipe gagne une entrée « Caisse ».
- Un layout `print` minimal est créé ; il ne charge ni navigation ni JavaScript applicatif sauf le contrôleur `print`.
- Aucune suppression dans la caisse : toute correction est une écriture visible.

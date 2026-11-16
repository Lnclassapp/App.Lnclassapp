# UDR-0175 : Page Croissance — section « Élèves : entonnoir AARRR »
<!-- index
titre: Page Croissance : entonnoir AARRR des élèves (acquisition, activation, rétention, referral, revenu, non mesuré)
statut: Accepté
adr-lie: [0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md), [0062](../adr/0062-indicateurs-de-pilotage-lus-en-direct.md)
problematique: L'équipe ne sait pas où les élèves décrochent ; cinq étages AARRR en nombres et en parts, seul contre amené par sa classe, cohortes J1/J7/J30, revenu en bêta, et ce qu'on ne peut pas mesurer, sur la page Croissance existante. Prolonge UDR-0050
-->

| | |
|---|---|
| **Statut** | Accepté (décisions du porteur du 2026-11-16 : aha = premier exercice réussi, distinguer seul / par sa classe) |
| **Date** | 2026-11-16 |
| **Chantier** | [`docs/chantiers/entonnoir-aarrr`](../../chantiers/entonnoir-aarrr/prd.md) |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) · [ADR-0062](../adr/0062-indicateurs-de-pilotage-lus-en-direct.md) · prolonge [UDR-0050](0050-inviter-un-collegue-et-croissance.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe voit sur « Croissance » le parrainage des enseignants, mais rien du parcours des élèves. Le porteur affirme « activation et rétention à 0 » sans pouvoir dire à quel étage les élèves s'arrêtent, ni si la voie d'arrivée (seul ou par sa classe) change quelque chose.

## 2. Décision

- **Même page, pas de nouvelle entrée de navigation** : la page Croissance est déjà le « toit » des indicateurs de croissance ; la période 7 / 30 / 90 jours s'applique aussi aux élèves (cohorte = inscrits de la période).
- **Un tableau, pas un graphique** : à ces volumes, un entonnoir dessiné ment (une barre de 100 % pour 3 élèves). Chaque part est accompagnée de son effectif.
- **Les étages AARRR sont nommés en français** avec la lettre anglaise en étiquette, pour que l'équipe relie l'écran au cadre du porteur.
- **Ce qui n'est pas mesuré est écrit**, dans une carte dédiée, au lieu d'un zéro trompeur.

## 3. Règles d'implémentation

**Structure** (dans `app/views/teams/growth/show.html.erb`, après `<nav id="growth_periods">` et **avant** la grille existante ; rendu par le partial `app/views/teams/growth/_funnel.html.erb`, locals `funnel:` = `Queries::Identity::StudentFunnelQuery::Report`)

1. `<section id="growth_funnel" aria-labelledby="growth_funnel_title" class="mb-5 space-y-5">` (une pile, pas une grille : un élément de grille garde sa largeur minimale et le tableau ferait déborder la page à 390 px), titre `h2#growth_funnel_title` (`font-display text-xl font-medium text-ink`) « Élèves : entonnoir AARRR », sous-titre `text-sm text-mute` rappelant « inscrits sur la période, suivis jusqu'à aujourd'hui ».
2. Carte `ui_card id: "growth_funnel_steps"`, titre « Acquisition et activation ». Contenu : un `<table>` dans `<div class="overflow-x-auto">` :
   - en-têtes de colonnes (`<th scope="col">`) : Étage · Total · Seul · Par sa classe · Sans classe (cette dernière colonne seulement si au moins un élève sans classe) ;
   - lignes (`<th scope="row">`) : « Inscrits » (étiquette `A · Acquisition`), « Ont ouvert une notion », « Ont commencé un exercice », « Ont réussi un exercice » (étiquette `A · Activation`, ligne en `font-medium`), « En ont réussi 2 », « En ont réussi 5 » ;
   - chaque cellule : le nombre (`font-display tabular-nums text-ink`) puis, sauf pour « Inscrits », la part des inscrits de la même colonne en `text-xs text-mute` (« 33 % », espace insécable ; « — » si 0 inscrit) ;
   - sous le tableau, `p.text-sm.text-mute` : « Délai médian jusqu'au premier exercice réussi : 2 j » (« — » si aucun activé).
3. Carte `ui_card id: "growth_funnel_retention"`, titre « R · Rétention ». Tableau : Semaine d'inscription (« Sem. du 10 nov. », suivie en `text-xs text-mute` de « partielle : début de la période en cours de semaine » quand la semaine commence avant la période) · Inscrits · J1 · J7 · J30. Cellule Jn : « 50 % » puis `text-xs text-mute` « 1 / 2 » ; « — » si la cohorte n'est pas encore mesurable à Jn. Note `text-xs text-mute` sous le tableau : la définition de « actif à Jn » (PRD §3).
4. Grille `grid gap-5 lg:grid-cols-2` :
   - Carte `ui_card id: "growth_funnel_referral"`, titre « R · Referral » : une phrase « Mesuré plus bas : k enseignant, conversion par partage, cycle viral. » + lien ancre `#growth_k` (`text-brand-strong underline-offset-4 hover:underline`). Aucun chiffre répété (dire chaque chose une seule fois).
   - Carte `ui_card id: "growth_funnel_revenue"`, titre « R · Revenu » : liste `dl` de trois lignes — Cartes activées sur la période · Montant (« 20 000 FCFA ») · Élèves abonnés aujourd'hui ; si la bêta est ouverte, `ui_badge` ton `:neutral` « Bêta ouverte : aucun élève n'est invité à payer ».
5. Carte `ui_card id: "growth_funnel_unmeasured"`, titre « Non mesuré », sous-titre « La base ne garde pas ces traces » : `ul` de 5 puces — cours commencé ou terminé ; nombre et date de première connexion ; visites d'un écran et temps passé ; première ouverture de l'application ; temps de réponse par question.

**Tokens**
- Classes du design system existantes uniquement (`text-ink`, `text-mute`, `bg-mist`, `border-line`, `text-brand-strong`, `rounded-ln`) : aucune couleur littérale.
- **Aucun vert, aucun ambre** dans cette section : ce ne sont ni des réussites d'élève à féliciter ni des urgences (une couleur = un sens). Aucun rouge.
- Chiffres `tabular-nums` ; pourcentages arrondis à l'entier, espace insécable avant « % » ; texte ≥ 12 px (`text-xs` minimum).

**Comportement**
- Aucun Turbo Frame, aucun Stimulus : rendu serveur pur, la période se change par les liens existants (rechargement complet).
- Aucune donnée personnelle : aucun nom, aucun numéro.

**États obligatoires**
- Vide : 0 inscrit sur la période → dans chaque carte Acquisition/activation et Rétention, à la place du tableau, `ui_empty_state`-like `p.text-sm.text-mute` « Aucun élève inscrit sur la période. » ; Revenu reste affiché (ses chiffres ne dépendent pas des inscrits).
- Chargement : sans objet (rendu serveur).
- Erreur : celle de la page (refus de la politique, inchangé).
- Succès : tableaux remplis comme ci-dessus.

**Accessibilité**
- Tableaux avec `<caption class="sr-only">`, `scope="col"` / `scope="row"`.
- `overflow-x-auto` sur le conteneur du tableau : à 390 px, le tableau défile dans sa carte, jamais la page.
- Lien d'ancre et liens de période : cibles ≥ 44 px pour ces derniers (inchangé) ; focus visible par défaut.

## 4. Conséquences

- Toute nouvelle mesure de parcours élève s'ajoute à cette section, pas dans une nouvelle page.
- Un chiffre que la base ne permet pas de calculer va dans « Non mesuré », jamais en 0.
- Si une table d'événements est un jour décidée (journal du chantier, À trancher), les lignes correspondantes quittent « Non mesuré ».

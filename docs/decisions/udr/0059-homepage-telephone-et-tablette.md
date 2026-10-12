# UDR-0059 : Homepage — maquette du porteur sur téléphone et tablette, landing actuelle épurée sur ordinateur
<!-- index
titre: Homepage sur téléphone et tablette
statut: Accepté *(2026-10-02)*
adr-lie: [0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md), [0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md)
problematique: Sous 1 024 px : photo, badge, slogan « Forcément, tu comprends chap chap », deux entrées (modales de l'UDR-0012) et « Espace établissement » ; le badge « même sans internet » gardé (PWA en cours), pas d'invitation aux applications tant qu'elles ne sont pas publiées ; au-dessus, la landing sans la section « Rejoindre ». Amende UDR-0012
-->

| | |
|---|---|
| **Statut** | Accepté (2026-10-02, porteur) |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/interface-epuree`](../../chantiers/interface-epuree/memo.md) — grill Q9, Q11, Q12 ; maquette [`homepage-telephone.html`](../../chantiers/interface-epuree/maquettes/homepage-telephone.html) |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (polices et images servies par l'application) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (budget de poids) · [UDR-0012](0012-landing-et-modales-de-role.md) (landing, modales de rôle) · [UDR-0057](0057-ecrans-eleve-epures.md) (règle et deux familles) |
| **Amende** | [UDR-0012](0012-landing-et-modales-de-role.md) : sa §3 s'applique désormais **à partir de 1 024 px** seulement |
| **Remplacé par** | — |

---

## 1. Contexte

Sur téléphone, la landing de l'UDR-0012 empile six sections : héros, matières, « Pour qui ? », fonctionnalités, « Comment ça marche », « Rejoindre ». Un élève qui veut seulement se connecter doit comprendre où toucher au milieu d'une page de présentation pensée pour l'ordinateur. Le porteur a dessiné l'écran d'entrée qu'il veut sur téléphone :
- une photo d'élèves qui travaillent ;
- un badge ;
- une feuille blanche avec le slogan et les deux entrées.

## 2. Décision

1. **Sous 1 024 px (téléphone et tablette)**, la homepage est l'écran d'entrée de la maquette : rien à faire défiler, deux entrées, un lien. Les sections de présentation n'y figurent pas.
2. **À partir de 1 024 px**, la landing de l'UDR-0012 reste, avec une seule épuration (R1 et R6 de l'UDR-0057) : les deux entrées ne sont plus répétées en bas de page.
3. **Les deux entrées ouvrent les mêmes modales de rôle** (UDR-0012 §2.2 à 2.4) : aucun nouveau parcours. « Je suis élève » est `primary`, « Enseignant(e) » `secondary`.
4. **« Espace établissement » mène à la connexion**, car la direction se connecte par PIN comme les autres rôles (UDR-0052). Ce n'est pas une nouvelle entrée de rôle : aucune modale.
5. **La page ne promet que ce qui existe ou arrive** (UDR-0012 §4).
   - Le badge garde son texte complet, « De la 6ème à la Terminale, même sans internet » : la PWA est en cours (décision du porteur, 2026-10-02).
   - L'invitation aux applications mobiles (« Lnclass Élève · Lnclass Enseignant ») n'est pas rendue tant que les applications ne sont pas publiées (chantier `app-android`).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure (`homepage/index`)**
- Deux familles dans la même vue (UDR-0057) : `div.entry-screen.lg:hidden`, puis le contenu actuel, enveloppé dans `div.hidden.lg:block`.
- La famille téléphone et tablette est centrée dans `max-w-phone`, sur `bg-ink`. Elle occupe toute la hauteur visible (`min-h-dvh`), en colonne. Du haut vers le bas :
  1. **Visuel** `div.entry-media` (flex 1, au moins 300 px de haut) :
     - la photo `homepage/eleves.jpg`, en `object-cover`, cadrée en bas pour garder les deux visages ;
     - un dégradé sombre en haut, du haut jusqu'à 46 %, pour que le badge et l'heure système restent lisibles.
  2. **Badge** `div.entry-badge[role=note]` :
     - posé en haut à droite, tourné de 8°, 160 px (146 px sous 380 px, 136 px sous 340 px) ;
     - forme étoilée en SVG, fond `brand` ;
     - texte « De la » / **« 6ème »** (`font-display`, 34 px, `ink`) / « à la Terminale, » / « même sans » / « internet » ;
     - `aria-label` « De la 6ème à la Terminale, même sans internet ».
  3. **Feuille** `main.entry-sheet` : fond blanc, `rounded-t-sheet`, 28 px de chevauchement sur la photo, padding 24 px 16 px plus la marge sûre du bas, contenu centré.
     - **Slogan** `h1` (`font-display`, 800, sur deux lignes) :
       - « Forcément, tu comprends » (26 px) ;
       - « chap chap » (40 px, `brand`), souligné d'un trait ondulé `gold` (SVG décoratif, `aria-hidden`).
     - **Deux entrées** côte à côte (grille 1fr 1fr, écart 10 px), 54 px, libellés 17 px :
       - `render "role_modal", role: :student, placement: :entry, variant: :primary`, avec le libellé « Je suis élève » ;
       - `render "role_modal", role: :teacher, placement: :entry, variant: :secondary`, avec le libellé « Enseignant(e) ».
     - **Lien** « Espace établissement » vers `new_session_path`, en `brand`, 16 px, 700, flèche `arrow-right`, cible ≥ 44 px.
- Les modales `role-modal-<role>-entry` sont des instances de plus du partial existant. Seul le libellé du déclencheur change selon `placement:`.
- **Famille ordinateur** : `section#rejoindre` et le lien d'en-tête « Commencer » (`#rejoindre`) sont retirés. Le reste de l'UDR-0012 §3 est inchangé.

**Tokens et ressources**
- Tokens du `@theme` uniquement. Ajouts : `--color-gold` (existe déjà) pour le soulignement, `--radius-sheet` et `--container-phone` (UDR-0058 §3.4).
- **La photo** est servie par l'application, sans tiers, dans le budget de poids de l'ADR-0051 : JPEG progressif, 1 080 px de large au plus, et ≤ 150 Ko.
- **La photo de la maquette est générée par IA.** Le porteur la retient pour la production (2026-10-02). Elle ne représente aucun élève réel.
- Le dégradé du visuel et la forme du badge sont des classes de la feuille de style (`.entry-media::after`, `.entry-badge`), jamais un attribut `style`.

**Comportement**
- Page statique, sans frame ni stream (UDR-0012). Les modales s'ouvrent par le contrôleur `modal` du socle.
- Un visiteur connecté est toujours redirigé vers son accueil.

**États obligatoires**
- Sans objet : page statique. Si la photo ne charge pas, le fond `ink` du visuel reste, et rien ne se décale.

**Accessibilité**
- Un seul `h1` par famille rendue : le slogan sous `lg`, le titre du héros à partir de `lg`.
- La photo porte un `alt` : « Deux élèves font leurs exercices, chacun avec son téléphone posé sur la table ».
- Le texte du badge est lu une fois, par son `aria-label`. Son texte visible est `aria-hidden`.
- Contraste : le texte blanc du badge est en gras d'au moins 13,5 px sur `brand` (texte large). « 6ème » est en `ink`.

## 4. Conséquences

- L'UDR-0012 ne gouverne plus que la landing à partir de 1 024 px. Sur téléphone et tablette, les sections de présentation disparaissent : un élève sur téléphone n'a pas besoin qu'on lui présente Lnclass pour entrer.
- **L'invitation aux applications** sera rendue quand les applications Android seront publiées. C'est un amendement de cette UDR, porté par le chantier `app-android`.
- La connexion et la récupération du PIN, autres écrans d'entrée partagés (grill Q9), sont épurées par leur propre lot, selon la règle de l'UDR-0057. Elles n'ont pas de maquette.

## Amendement du 2026-10-03 — le slogan

*Décision du porteur (revue de la PR de [`refonte-homepage`](../../chantiers/refonte-homepage/memo.md)). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- Le slogan de l'application est **« Lnclass, tu comprends chap chap ! »**, partout. Dans l'écran d'entrée (§3, 3.), le `h1` devient « Lnclass, tu comprends » (26 px) puis « chap chap ! » (40 px, `brand`), souligné du même trait ondulé `gold`. « Forcément, tu comprends chap chap » de la maquette n'est plus la consigne.
- La famille ordinateur (UDR-0064) porte le même slogan en un seul `h1`.

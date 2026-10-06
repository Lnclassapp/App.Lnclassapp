# PRD — Refonte de la page d'accueil publique

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

La page d'accueil publique est refaite autour d'une seule décision, élève ou enseignant, visible sans défiler sur un petit téléphone ([memo](memo.md)). Elle garde les deux entrées de rôle et leurs modales (UDR-0012), ne promet que ce que la V1 livre, et perd 1,3 Mo de photo. Le domaine, les routes et le contrôleur ne changent pas.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur (non connecté) | lire la page ; ouvrir la modale élève et la modale enseignant ; suivre « Se connecter », « Rejoindre ma classe », « Créer un compte », « Créer mon compte enseignant » | — |
| Élève, enseignant, direction, équipe connectés | — | voir la page : renvoyés vers leur accueil (inchangé, `HomepageRedirectionTest`) |

Aucune policy : la page est statique et publique (`allow_unauthenticated_access`).

## 3. Parcours utilisateur

### Chemin nominal — l'élève

1. Il ouvre `/` sur son téléphone : logo, promesse, les deux entrées, sans défiler.
2. Il touche « Je suis élève » : la modale s'ouvre sans rechargement et nomme l'onglet.
3. Il touche « Rejoindre ma classe » : il arrive sur `/join` (UDR-0009).

### Chemin nominal — l'enseignant

1. Il ouvre `/`, défile jusqu'à « Enseignants » (ou touche « Je suis enseignant » dans le héros).
2. Il touche « Créer mon compte enseignant » : il arrive sur `/teacher-signup` (UDR-0044).

### Chemin nominal — la personne déconnectée

1. Elle ouvre `/` et touche « Se connecter » dans l'en-tête : `/login`.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Visiteur connecté | Redirigé vers son accueil (inchangé) |
| JavaScript absent | Les deux entrées du héros sont inertes ; « Se connecter » et « Créer mon compte enseignant » restent des liens ordinaires (inchangé) |
| Écran de 390 px ou de 360 px | Aucun défilement horizontal ; les deux entrées du héros tiennent dans le premier écran à 360 × 640 |
| Photo non chargée | Le texte alternatif décrit la scène ; la mise en page ne bouge pas (dimensions déclarées) |
| Lien du pied de page | Chaque ancre vise une section qui existe |

## 4. Critères d'acceptation

Chaque critère devient un test. Les tests existants TR-01 (modales, liens, boutons) et TR-02 (redirection) restent la preuve de ce qui ne change pas.

```gherkin
# RH-01 — Un écran, une décision
Étant donné un visiteur sur /
Alors il voit un seul h1, « Lnclass, tu comprends chap chap ! » (le slogan de l'application, décision du porteur du 2026-10-03)
Et l'en-tête porte exactement deux liens : le logo (« Lnclass, accueil », vers /) et « Se connecter » (vers /login)
Et la section « hero » porte les deux entrées « Je suis élève » et « Je suis enseignant »

# RH-02 — Les modales de rôle ne changent pas (TR-01)
Étant donné un visiteur sur /
Alors la modale « role-modal-student-hero » propose « Se connecter » (/login) et « Rejoindre ma classe » (/join)
Et la modale « role-modal-teacher-hero » propose « Se connecter » (/login) et « Créer un compte » (/teacher-signup)
Et chaque modale nomme l'onglet par son titre tant qu'elle est ouverte (« Tu es élève ? · Lnclass »), puis rend « Accueil · Lnclass »
Et ouvrir, fermer, puis suivre « Rejoindre ma classe » ne recharge jamais la page

# RH-03 — Visible sans défiler
Étant donné un téléphone de 360 × 640 px
Quand le visiteur ouvre /
Alors le bas des deux boutons d'entrée du héros est au-dessus du bord bas de la fenêtre

# RH-04 — Une photo légère
Étant donné la page /
Alors la photo du héros est servie depuis homepage/student.webp, en 960 × 640, avec son texte alternatif
Et le fichier pèse au plus 100 Ko
Et homepage/student.png n'existe plus dans le dépôt

# RH-05 — Les matières de la grille élève, rien de plus
Étant donné la page /
Alors la bande des matières liste, dans cet ordre, Mathématiques, Physique-Chimie, SVT, Français,
  Histoire-Géographie, EDHC, Philosophie (la grille de l'accueil élève, UDR-0058 §3)
Et les trois premières portent la teinte « science », les quatre suivantes la teinte « literature »
Et la page ne contient pas « et plus encore »

# RH-06 — Trois étapes
Étant donné la page /
Alors la section « comment » est une liste ordonnée de trois étapes : le code, rejoindre, apprendre

# RH-07 — Quatre promesses, quatre badges
Étant donné la page /
Alors la section « fonctionnalites » porte quatre cartes titrées (h3) : exercices corrigés, programme officiel,
  badges et progression, léger sur tous les téléphones
Et la carte des badges liste, dans cet ordre, Bronze, Argent, Or, Diamant

# RH-08 — Les enseignants sont vouvoyés
Étant donné la page /
Alors la section « enseignants » porte trois promesses et un lien « Créer mon compte enseignant » vers /teacher-signup
Et son texte ne contient ni « tu », ni « tes », ni « ton », ni « toi »

# RH-09 — Les deux entrées ne sont offertes qu'une fois (UDR-0059 §2.2)
Étant donné la page /
Alors il n'y a ni section « rejoindre » ni bouton « Commencer »
Et la page porte exactement deux modales de rôle, « role-modal-student-hero » et « role-modal-teacher-hero »
Et le pied de page liste les pages publiques en ligne, et elles seules (UDR-0063 §3.4)
Et l'enseignant se voit promettre des exercices à assigner, jamais des cours (UDR-0062 §4)

# RH-10 — Aucun lien sans route, aucun bouton sans action (TR-01, TR-03)
Étant donné la page /
Alors chaque lien est reconnu par le routeur ou vise une section de la page
Et chaque bouton porte une action
Et la page ne contient ni « Espace Etabl », ni « Inscrire mon établissement », ni « FCFA »

# RH-11 — Au téléphone, pas de défilement horizontal (FU-53)
Étant donné un écran de 390 px
Quand le visiteur ouvre /
Alors la page ne défile pas en largeur

# RH-12 — Design system et titre
Étant donné les sources de la page
Alors elles n'emploient que les tokens du @theme (test des tokens)
Et la page s'appelle « Accueil » par page_title

# RH-13 — Le déclencheur d'une modale se dimensionne
Étant donné ui_modal(trigger:, trigger_size: :lg, trigger_full: true)
Alors le bouton déclencheur mesure 56 px de haut et prend toute la largeur
Et sans ces options, il garde 48 px et sa largeur naturelle
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | — |
| Delivery | `HomepageController` inchangé ; `homepage/index` et `homepage/_role_modal` réécrites |
| UI | `components/_modal` et `ComponentsHelper#ui_modal` (option `trigger_full:` ; `trigger_size:` existe depuis l'UDR-0061) ; exemple sur `/design` ; locale `homepage/index.fr.yml` ; photo `homepage/student.webp` |

## 6. Décisions rattachées

- [UDR-0064](../../decisions/udr/0064-page-d-accueil-un-ecran-une-decision.md) — page d'accueil publique : un écran, une décision. Remplace la §3 « Structure » de l'UDR-0012 ; ses décisions 1 à 5 restent. Numérotée 0056 à l'ouverture du chantier, renumérotée à la fusion avec `Develop`, qui avait pris 0056 à 0063 entre-temps.
- Décisions livrées en parallèle sur `Develop` le 2026-10-02 et respectées par cette page : [UDR-0059](../../decisions/udr/0059-homepage-telephone-et-tablette.md) §2.2 (les entrées ne sont pas répétées en bas ; cette page est sa famille ordinateur, rendue à toutes les largeurs jusqu'au lot M2 d'`interface-epuree`), [UDR-0058](../../decisions/udr/0058-accueil-eleve.md) §3 (les matières de la grille élève), [UDR-0062](../../decisions/udr/0062-echeances.md) §4 (l'enseignant n'assigne que des exercices), [UDR-0063](../../decisions/udr/0063-pages-publiques-mission-confidentialite-cgu-cgv.md) §3.4 (pages publiques au pied).
- [UDR-0012](../../decisions/udr/0012-landing-et-modales-de-role.md), amendement du 2026-10-02 — renvoi vers l'UDR-0064.
- [UDR-0005](../../decisions/udr/0005-design-system-fondateur.md), amendement du 2026-10-02 — option `trigger_full:` de `ui_modal` (`trigger_size:` est arrivée par l'UDR-0061 pendant le chantier).
- Pas d'ADR : aucun port, aucune table, aucune dépendance, aucun contrat ne bouge. La CSP stricte (ADR-0049) est respectée : aucun script ni style en ligne.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Poids de la photo du héros | 1 307 Ko (PNG 1248 × 832) | ≤ 100 Ko | **21,5 Ko** (WebP 960 × 640) |
| Poids du HTML de `/` (ADR-0067 : < 150 Ko) | — *(non mesuré avant)* | < 150 Ko | 34,3 Ko (6,5 Ko gzip), 2 `<dialog>` *(après la fusion avec `Develop` : sans l'appel final, avec les pages publiques au pied)* |
| CSS compilée, gzip (ADR-0051 : ≤ 30 Ko) | 7,4 Ko (2026-09-25) | ≤ 30 Ko | 12,8 Ko |
| Bas du second bouton d'entrée, à 360 × 640 px | sous la fenêtre (en-tête 64 px + navigation, héros, photo avant les entrées) | ≤ 640 px | **514 px** (premier bouton : 446 px), mesurés dans Chromium 141 |

Mesures du 2026-10-02 : `curl` sur le serveur de développement, `bin/check-asset-budget`, Playwright sur Chromium 141.

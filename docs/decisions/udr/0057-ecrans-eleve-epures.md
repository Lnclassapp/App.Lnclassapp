# UDR-0057 : Écrans élève épurés — règle de sobriété et deux familles d'écrans

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/interface-epuree`](../../chantiers/interface-epuree/memo.md) — grill Q1 à Q12 |
| **ADR lié** | [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (budget de poids) · [UDR-0005](0005-design-system-fondateur.md) (tokens, aucune valeur arbitraire, pas de mode sombre) · [UDR-0006](0006-shell-applicatif-par-role.md) (shell) · [UDR-0054](0054-finitions-d-interface.md) (finitions) · [UDR-0058](0058-accueil-eleve.md) · [UDR-0059](0059-homepage-telephone-et-tablette.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Le porteur juge l'application trop chargée. Une ligne d'exercice de l'accueil élève montre sept informations et un bouton. Le nom de l'établissement et de la classe est dit deux fois sur le même écran. Des textes d'aide restent affichés en permanence. Aucune décision ne fixe ce qu'un écran peut montrer. Chaque UDR décide pour son seul écran, et la charge s'additionne.

L'élève est le public le plus nombreux. Il utilise souvent un Android d'entrée de gamme, avec un forfait data cher, en plein soleil. Les applications Android afficheront les pages du site telles quelles (ADR-0070, en attente) : ce qui reste chargé ici le restera sur le Play Store.

## 2. Décision

1. **Une règle chiffrée, commune à tous les écrans élève** et aux trois écrans d'entrée partagés (bienvenue, connexion, récupération du PIN). Elle est vérifiable écran par écran (grill Q2, Q3, Q9).
2. **Deux familles d'écrans selon la largeur** (grill Q11, Q12) :
   - **téléphone et tablette, sous 1 024 px** : les maquettes du porteur, là où elles existent (homepage, accueil élève) ;
   - **ordinateur, à partir de 1 024 px** : la mise en page actuelle, épurée selon la règle, sans nouvelle maquette.

   Le seuil est le palier `lg` du shell (UDR-0006), où la barre latérale remplace déjà la barre basse : une seule frontière dans toute l'application.
3. **Sur tablette, la maquette téléphone reste une colonne centrée de 36 rem au plus** (576 px), sur le fond `paper`. Étirée sur 1 000 px, une ligne de liste deviendrait illisible et les cartes perdraient leurs proportions.
4. **Épurer ne supprime aucune fonction** (grill Q4). Une information retirée d'une liste passe dans l'écran de détail, à un tap. Seul ce qui est **répété** disparaît.
5. **Ce qui repose sur une fonction absente n'est pas affiché** (grill Q8) : échéances, retards, durée d'un exercice, paiement, annonces, lecture audio, application mobile, hors connexion. Chaque élément revient avec sa fonction, par le chantier [`fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md), jamais sous forme de bouton factice.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**La règle (6 points, pour chaque écran)**

| # | Règle | Vérification |
|---|---|---|
| R1 | Une seule action principale (`primary` ou `brand`) visible par écran. Les autres actions sont `secondary`, `ghost` ou dans le menu ⋮. | Test de vue : au plus un bouton ou lien de variante `primary`/`brand` dans le `main` |
| R2 | Au plus 5 blocs de premier niveau visibles avant le premier défilement, à 390 × 844. | Test système : blocs enfants directs du `main` dont le haut est dans la fenêtre |
| R3 | Une liste montre au plus 3 lignes, puis « Voir plus », qui ajoute la suite sans recharger la page. | Test de vue sur chaque liste |
| R4 | Aucun texte d'aide affiché en permanence. Une explication passe par `ui_info_tip`, ou par l'écran de détail. | Revue de l'UDR de l'écran |
| R5 | Une seule couleur d'accent (`brand`), hors signal sémantique (`success`, `warning`, `error`). | `test/design/design_tokens_test.rb` (inchangé) |
| R6 | Une information n'apparaît qu'une fois par écran : pas de classe ou d'établissement redits, pas de statut redit à la fois en texte et en couleur sans raison d'accessibilité. | Revue de l'UDR de l'écran |

**Deux familles d'écrans**
- Le seuil est `lg` (64 rem, 1 024 px), le palier par défaut de Tailwind, déjà utilisé par le shell. Aucun autre palier n'introduit de troisième mise en page.
- Un écran qui a une maquette téléphone rend ses deux familles **dans la même vue**, par les classes responsives :
  - la famille téléphone et tablette est visible sous `lg` (`lg:hidden`) ;
  - la famille ordinateur est visible à partir de `lg` (`hidden lg:block`).
  
  Une famille ne charge jamais de donnée que l'autre n'a pas : le contrôleur et la query sont communs.
- Sous `lg`, la famille téléphone se centre dans `max-w-phone` (nouveau token `--container-phone: 36rem`), sur `bg-paper`.
- Un écran sans maquette garde une seule mise en page et applique la règle à ses deux tailles.

**Listes (toutes)**
- Une ligne = pastille ronde de la matière, titre (tronqué), sous-texte « Matière · Type », puis une colonne de droite qui porte **une** donnée : note, statut ou action.
- La ligne entière est un lien (lien étiré) quand elle mène à un détail. Son état pressé utilise `bg-mist`.
- « Voir plus » (`ui_button`, `ghost`, pleine largeur) révèle les lignes déjà rendues mais masquées (`hidden`), par le contrôleur Stimulus `reveal` (nouveau, générique). Il n'y a ni requête ni frame, sauf indication contraire de l'UDR de l'écran.

**Tokens**
- Tokens du `@theme` uniquement (UDR-0005). Les teintes des pastilles de matière et de la carte du haut entrent dans le `@theme` (UDR-0058 §3, « Tokens »). Aucun `#hex`, aucun `style=`, aucune valeur entre crochets, aucun `dark:` dans les vues.
- Une barre de progression est un `<progress>` natif, stylé dans la feuille (`.progress-bar`). Jamais une largeur posée par `style`.

**États obligatoires**
- Chaque liste a un état vide qui dit quoi attendre (`ui_empty_state`), jamais une section blanche.
- Chaque bloc différé a son squelette (`ui_loading_state variant: :skeleton`), de la même hauteur que le contenu final.

**Accessibilité**
- Cibles tactiles ≥ 44 px dans les maquettes téléphone (zone de la carte et des pastilles), ≥ 48 px ailleurs (UDR-0005).
- Un texte masqué par la famille inactive est aussi retiré de l'arbre d'accessibilité : `hidden` (`display: none`), jamais une simple opacité.
- « Voir plus » annonce le nombre de lignes ajoutées dans une région `aria-live="polite"`.

## 4. Conséquences

- Les UDR des écrans élève (0009, 0011, 0013, 0015, 0021, 0022, 0023) et des écrans d'entrée (connexion, récupération du PIN) seront amendées écran par écran, à mesure que leur lot applique la règle. Chaque amendement liste ce qui est retiré, et où cela va.
- Aucun nouvel écran élève n'est accepté s'il enfreint R1 à R6.
- Le palier `md` ne porte plus de changement de mise en page sur les écrans élève : seul `lg` sépare les deux familles.
- L'enseignant, la direction et l'équipe ne sont pas concernés, sauf sur les trois écrans d'entrée partagés. Leur tour viendra dans un chantier suivant, avec la même règle.

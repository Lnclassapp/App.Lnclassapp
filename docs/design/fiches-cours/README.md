# Handoff : Fiches de cours Lnclass + signalement d'erreurs

## Vue d'ensemble
Ce dossier contient trois fiches de cours interactives de niveau collège, créées pour Lnclass :
- **La propriété de Thalès** (Mathématiques, 3e)
- **Les lentilles** (Physique-chimie)
- **Le texte argumentatif** (Français)

Chaque fiche a la forme d'un cahier de 3 pages. On y trouve un cours, une manipulation interactive, des exercices corrigés automatiquement, un générateur d'exercices illimité et un lexique qui s'ouvre au clic sur un mot.

La fiche Thalès comporte aussi un **mode relecture enseignant**. L'enseignant y coche les mots ou expressions erronés, puis envoie un rapport à l'équipe Lnclass.

## À propos des fichiers de design
Les fichiers de ce dossier sont des **références de design réalisées en HTML** : des prototypes qui montrent l'apparence et le comportement voulus. Ce n'est **pas du code de production à copier tel quel**.

La tâche consiste à **recréer ces designs dans l'environnement existant du code Lnclass** (React, Vue, etc.), avec ses conventions et ses bibliothèques. S'il n'existe pas encore d'environnement, choisis le framework le plus adapté. Une suggestion : React avec un composant `<FicheLayout>` commun, et le contenu de chaque fiche sous forme de données.

Les fichiers `.dc.html` s'ouvrent dans un navigateur via un serveur local, avec `support.js` dans le même dossier. Dans chaque fichier :
- le gabarit (le HTML entre les balises `<x-dc>`) est écrit avec des styles inline et des emplacements `{{ valeur }}` ;
- la logique se trouve dans la classe `Component` du bloc `<script data-dc-script>` : `state`, puis `renderVals()`, qui calcule les valeurs injectées dans le gabarit.

`lnclass-signalement.js` est une exception : c'est un module JavaScript autonome, sans dépendance, qui peut servir tel quel ou de spécification.

## Niveau de fidélité
**Haute fidélité (hifi).** Les couleurs, la typographie, les espacements et les interactions sont définitifs. Reproduis-les au pixel près en t'appuyant sur les bibliothèques du code existant.

---

## Structure commune aux 3 fiches

### Mise en page
- **Fond de l'écran** : une couleur propre à chaque fiche (voir le tableau des thèmes). Les pages sont centrées en colonne, avec un écart d'environ 40 px entre elles.
- **Page** : couleur papier `#fbf6e9`, `position:relative`, `box-sizing:border-box`, ombre `0 1px 0 rgba(0,0,0,.05), 0 14px 40px rgba(R,G,B,.18)`. La teinte de l'ombre varie selon la fiche.
  - Thalès : 1000 × 1414 px minimum (ratio A4).
  - Lentilles et Texte argumentatif : 880 × 1245 px minimum.
- **3 pages** par fiche, avec l'attribut `data-screen-label="Page 1|2|3"`.
- **Papier Seyès** (option `seyes`, activée par défaut) : un quadrillage de cahier français dessiné en dégradés CSS sur le fond de la page. On y voit des lignes horizontales fines tous les 8 px environ, une ligne plus marquée tous les 32 px et une marge rouge verticale `oklch(0.6 0.17 20 / .55)`.

### Typographie
- **Titres, consignes et boutons** : `Kalam` (Google Fonts, graisses 400 et 700), écriture manuscrite.
  - h1 : 48 à 56 px, couleur principale, soulignée par un trait de 3 px dans la couleur d'accent.
  - h2 : 26 à 30 px, numérotée (« 1. L'énoncé »), dans la couleur d'accent.
- **Texte courant** : `Source Serif 4` (opsz 8..60, graisses 400 et 600, italique 400), repli sur `Georgia, serif`. Taille 16 à 18 px, interligne 1,5, `text-wrap: pretty`.
- **Encres** : texte principal `#23263a` (Thalès), `#1f2a33` (Lentilles) ou `#2a2224` (Texte argumentatif) ; texte secondaire `#4a4d63` ; texte atténué `#6a6d80`.

### Sections (h2) présentes dans chaque fiche
Les sections 1 à 5 forment le cours. Ensuite viennent « 6. Exercices d'application » (exercices corrigés) et « 7. Je m'entraîne » (générateur et score).

| Fiche | Sections 1 à 5 |
|---|---|
| Thalès | L'énoncé · Les deux configurations · Méthode : calculer une longueur · La réciproque · La contraposée |
| Lentilles | Deux familles de lentilles · Vocabulaire de la lentille convergente · L'image donnée par une lentille convergente · Construire l'image d'un objet · L'œil, un système optique |
| Texte argumentatif | Les éléments de l'argumentation · Convaincre ou persuader ? · Analyser un texte argumentatif · Les connecteurs logiques · Méthode : rédiger un paragraphe argumentatif |

### Composants communs
- **Encadré « propriété » ou « à retenir »** : fond `#fffdf8`, bordure de 2 px dans la couleur d'accent, `border-radius: 6px`, padding de 12 à 20 px.
- **Mot du lexique** : souligné en pointillés. Au clic, une fenêtre s'ouvre près du curseur (`position:fixed`, 310 px de large, `max-height: 70vh`). Elle affiche la définition et un exemple de la vie courante, puis se ferme quand on fait défiler la page ou qu'on clique ailleurs. Le bouton « Lexique » affiche tous les mots dans cette même fenêtre. Les textes sont dans la constante `GLOSS` de chaque fichier, sous la forme `{clé: [titre, définition, exemple]}`.
- **Bouton bascule « Explications simples : oui/non »** (option `simple`, activée par défaut) : affiche ou masque des reformulations simplifiées sous les notions. Couleur active `oklch(0.48 0.15 305)`, texte blanc ; couleur inactive : fond transparent, texte violet.
- **Exercice corrigé**, pour chaque exercice :
  - des champs de saisie ou des choix multiples ;
  - un bouton « Vérifier » ; sous chaque champ, un retour « à compléter », « juste » ou « à revoir », en vert `oklch(0.52 0.13 155)`, rouge `oklch(0.53 0.19 27)` ou gris ;
  - un message global : « Tout est juste, bravo ! » ou « Certaines réponses sont à revoir. » ;
  - des boutons repliables « Indice » et « Correction ». L'option `corrections` les affiche dépliés par défaut.
  - Pour les réponses numériques, la virgule est acceptée et la tolérance est de ±0,011.
- **« Je m'entraîne »** : un générateur d'énoncés aléatoires avec « Vérifier », « Voir la solution » et « Nouvel exercice ». La touche Entrée lance la vérification. Un score « ok / total » s'affiche, et chaque énoncé ne compte qu'une seule fois.

### Spécificités par fiche
- **Thalès**
  - Figure SVG interactive : on déplace les points A, B, C, M et N, et l'affichage indique la configuration (triangle ou papillon). Les longueurs AM, AN, MN, AB, AC et BC sont mises à jour en direct, ainsi que les rapports.
  - Le bouton « Libérer N (tester la réciproque) » s'alterne avec « Imposer (MN) // (BC) ». Le bouton « Réinitialiser » remet `INIT = {A:(70,165), B:(360,55), C:(345,285), kM:0.45, kN:0.45}`.
  - Exercice 6 : choix « parallèles » ou « non parallèles ».
  - Réponses attendues : `ANS = {e4AN:3.6, e4MN:4.2, e5AN:3, e5MN:4.5, e6r1:0.4, e6r2:0.4, e7BC:9}`.
- **Lentilles**
  - Simulateur SVG : on déplace l'objet et le foyer (variables d'état `d`, `h`, `f`). L'image est tracée en direct, avec les rayons, l'image virtuelle en pointillés, la nature de l'image et les applications (photo, projecteur, loupe).
  - Une grille peut être affichée ou masquée.
  - Exercice de construction : l'élève place le point image sur la figure, puis vérifie.
- **Texte argumentatif**
  - Surlignage par catégorie : des boutons thèse, argument, exemple, connecteur, etc. colorent les segments d'un texte d'exemple. Un clic sur un segment coloré affiche une explication.
  - Tableau des connecteurs logiques.
  - Exercice à trous avec 4 choix : la réponse se fige au premier clic.
  - Zone de rédaction libre avec une liste de vérifications automatiques (connecteurs trouvés, nombre de mots, nombre de paragraphes).

### Thèmes (couleurs)
| Fiche | Fond de l'écran | Principale (titres, liens) | Accent (h2, encadrés) |
|---|---|---|---|
| Thalès | `#e6dfcf` | `oklch(0.48 0.15 262)` (bleu) | `oklch(0.53 0.19 27)` (rouge) |
| Lentilles | `#dfe3e2` | `oklch(0.45 0.1 215)` (bleu-vert) | `oklch(0.58 0.17 45)` (orange) |
| Texte argumentatif | `#e5ddd6` | `oklch(0.42 0.13 15)` (bordeaux) | `oklch(0.5 0.1 70)` (ocre) |

Couleurs partagées : papier `#fbf6e9`, carte `#fffdf8`, bordure de champ `#cfd6ea`, bordure de carte `#e2d9c4`, succès `oklch(0.52 0.13 155)`, erreur `oklch(0.53 0.19 27)`. Les liens au survol prennent la couleur d'accent.

### Rayons, ombres et espacements
- Rayons : 4 px pour les champs, 6 px pour les encadrés, boutons et cartes, 8 à 10 px pour les panneaux, 20 à 26 px pour les pastilles flottantes.
- Ombres :
  - pages : voir plus haut ;
  - panneaux flottants : `0 10px 30px rgba(40,30,70,.25)` ;
  - bouton flottant : `0 6px 18px rgba(120,30,20,.35)`.
- Espacements : marges intérieures des pages de 56 à 72 px, écart entre blocs de 12 à 16 px, écart entre sections de 28 à 40 px.

---

## Mode relecture enseignant (signalement d'erreurs)
Implémenté dans `fiches/Fiche Thales.dc.html` (méthodes `rv*`) et, en version autonome réutilisable, dans `signalement-erreurs/lnclass-signalement.js`. **Il doit être disponible sur toutes les fiches.**

### Parcours
1. Un bouton « Signaler une erreur » flotte en bas à droite (`position:fixed`, à 20 px des bords, `z-index` élevé). Style : Kalam 17 px, bordure de 2 px rouge `oklch(0.53 0.19 27)`, fond `#fffdf8`. Au survol, il s'inverse : fond rouge, texte blanc.
2. Au clic, il devient un panneau « Mode relecture » : 350 px de large, `max-height: 78vh`, défilement vertical seulement.
3. **Cocher** : un clic sur un mot sélectionne le mot entier (`Selection.modify('move','backward','word')` puis `('extend','forward','word')`). Une sélection à la souris coche toute l'expression, dans la limite de 400 caractères. Les espaces de fin sont retirés.
4. Le passage coché est surligné : fond `oklch(0.9 0.12 90)`, texte `oklch(0.4 0.17 27)`, soulignement ondulé rouge. Le surlignage passe par la CSS Custom Highlight API (`::highlight(lnc-err)`). Sans cette API, on entoure le passage d'un `<span class="lnc-mark">`.
5. Un clic sur un passage déjà coché le retire. Le bouton × de la liste le retire aussi.
6. **Pendant la relecture**, les clics sur la fiche sont neutralisés (`preventDefault` et `stopPropagation` en phase de capture), sauf dans le panneau. On évite ainsi de déclencher les boutons, le lexique ou les figures.
7. **Chaque élément** de la liste affiche :
   - le texte coché entre guillemets français ;
   - son emplacement : « Page N · titre h2 de la section » ;
   - un champ « Correction proposée (facultatif) ».
8. Sous la liste, deux champs : « Commentaire général (facultatif) » (zone de texte) et « Votre nom et établissement (facultatif) ».
9. Le bouton **« Signaler à l'équipe Lnclass »** est désactivé (opacité 0,4) tant qu'aucun élément n'est coché. Au clic :
   - Si une adresse `endpoint` est configurée, le rapport est envoyé en `POST` JSON (schéma ci-dessous).
   - Sinon, ou en cas d'échec de l'envoi, un lien `mailto:` s'ouvre vers `reportEmail` (`contact@lnclass.com` par défaut, **à confirmer**). L'objet est « Signalement d'erreurs — <fiche> » et le corps contient le rapport texte.
   - Dans les deux cas, le rapport est copié dans le presse-papiers et un message de confirmation vert s'affiche.
10. Le lien « Tout effacer » vide la liste et le commentaire. « Quitter × » referme le panneau et revient au bouton ; les éléments cochés sont conservés.

### Format du rapport (texte)
```
Signalement d'erreurs — Fiche « La propriété de Thalès » (Mathématiques, 3e)
Date : <date fr-FR>
Enseignant : <nom>            (si renseigné)

N élément(s) signalé(s) :

1. « texte » — Page 1 · 1. L'énoncé
   Contexte : <phrase ou paragraphe, 220 caractères max>
   Correction proposée : <…>   (si renseignée)

Commentaire général : <…>     (si renseigné)
```

### Données envoyées à l'API (recommandé en production, plutôt que `mailto:`)
```json
{ "fiche": "La propriété de Thalès (Maths 3e)", "url": "https://…", "enseignant": "…", "commentaire": "…",
  "elements": [{ "texte": "sécantes", "emplacement": "Page 1 · 1. L'énoncé", "contexte": "…", "correction": "…" }],
  "rapport": "<texte complet>" }
```
À prévoir côté serveur : enregistrer chaque signalement dans une file que l'équipe éditoriale peut traiter, avec un statut « à traiter », « corrigé » ou « rejeté ».

### Variables d'état
`review` (booléen), `marks: [{id, text, ctx, where, comment}]`, `rvNote`, `rvName`, `sent`. Les objets `Range` sont stockés hors de l'état React (`this.ranges[id]`) et redessinés à chaque mise à jour.

### Téléphone et tablette (`fiches/Signalement Mobile Tablette.dc.html`)
- **1a — Téléphone** (390 × 844 px) : pastille flottante « Signaler » de 52 px de haut (cible tactile d'au moins 44 px) avec une icône « ! » cerclée, à 18 px du bord droit et 40 px du bas.
- **1b — Téléphone en mode relecture** :
  - un bandeau rouge en haut : « Mode relecture · touchez un mot pour le cocher » ;
  - le panneau devient un tiroir en bas de l'écran (pleine largeur, coins supérieurs arrondis à 20 px, poignée de 44 × 5 px, `max-height: 60vh`) ;
  - le bouton d'envoi fait 50 px de haut.
- **1c — Tablette en paysage** (1180 × 820 px) :
  - le bouton « Signaler une erreur » est intégré à la barre du haut, à droite (44 px de haut) ;
  - en mode relecture, le panneau occupe une colonne fixe de 360 px à droite et la fiche reste lisible à gauche (`grid-template-columns: minmax(0,1fr) 360px`).
- Le module autonome applique déjà le passage au tiroir sous 640 px de large (`@media`) et gère `touchend`.

---

## Options (props) de chaque fiche
| Prop | Type | Par défaut | Effet |
|---|---|---|---|
| `seyes` | boolean | `true` | Fond de page façon cahier Seyès |
| `corrections` | boolean | `false` | Corrections dépliées par défaut |
| `simple` | boolean | `true` | Explications simples affichées par défaut |
| `reviewTools` | boolean | `true` | Affiche le bouton « Signaler une erreur » (Thalès seulement pour l'instant) |
| `reportEmail` | string | `contact@lnclass.com` | Destinataire des signalements |

## Ressources
- Polices Google Fonts : Kalam et Source Serif 4.
- Aucune image : toutes les figures (Thalès, lentilles) sont dessinées en SVG et calculées à partir de l'état.
- Aucune icône externe.

## Fichiers
- `fiches/Fiche Thales.dc.html` : fiche Thalès complète, avec le mode relecture.
- `fiches/Fiche Lentilles.dc.html` : fiche Lentilles.
- `fiches/Fiche Texte argumentatif.dc.html` : fiche Texte argumentatif.
- `fiches/Signalement Mobile Tablette.dc.html` : maquettes du signalement sur téléphone et tablette.
- `fiches/support.js` : moteur d'exécution nécessaire pour ouvrir les `.dc.html` (à ne pas porter).
- `signalement-erreurs/lnclass-signalement.js` : module de signalement autonome (attributs `data-email`, `data-fiche`, `data-zone`, `data-endpoint`).
- `signalement-erreurs/demo.html` : page de démonstration du module.

## Points à confirmer avec l'équipe
- L'adresse de réception des signalements et l'API (`endpoint`).
- Le passage des fiches au format mobile : elles ont aujourd'hui une largeur fixe de 880 à 1000 px.
- L'ajout du mode relecture aux fiches Lentilles et Texte argumentatif.

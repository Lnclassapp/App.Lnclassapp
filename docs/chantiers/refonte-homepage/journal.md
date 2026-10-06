# Journal — Refonte de la page d'accueil publique

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | Grill mené en session autonome, sans le porteur, chaque hypothèse de produit marquée dans le memo | La demande tient en une ligne (« tu vas refaire la Homepage ») et la session ne peut pas attendre une réponse ; les hypothèses sont listées pour la revue de PR | Non |
| 2026-10-02 | La photo passe en WebP 960 × 640 (22 Ko) plutôt qu'en JPEG (51 Ko) | Le plancher des navigateurs (Chrome 111, Safari 16.4, ADR-0051) lit le WebP ; moitié moins d'octets pour la même image | Non — UDR-0064 |
| 2026-10-02 | Les matières sont écrites dans la vue, pas lues en base | La page reste sans requête ; le référentiel de production est créé à l'écran par l'équipe et peut différer : une ligne de locale à changer, pas une query | Non — memo (hypothèse à confirmer) |
| 2026-10-02 | Deux options de `ui_modal` (`trigger_size:`, `trigger_full:`) plutôt qu'un bouton écrit à la main dans la vue | Le déclencheur doit vivre dans le périmètre du contrôleur `modal` ; un bouton hors du composant ne pourrait pas ouvrir la `<dialog>` | Non — amendement UDR-0005 |
| 2026-10-02 | L'enseignant est vouvoyé sur la page, l'élève tutoyé | C'est le ton de l'application (`teacher_homes`, `teacher_registrations`) ; la page actuelle tutoyait l'enseignant | Non — UDR-0064 |
| 2026-10-02 | Le logo décoratif de l'appel final est masqué au téléphone plutôt que retiré partout *(sans objet depuis la fusion : l'appel final est retiré, UDR-0059)* | Le challenger l'a mesuré sous les deux boutons à 360 et 390 px ; sur grand écran il reste hors des boutons. La grille de design du fondateur refuse le filigrane sur l'accueil élève : le garder sur la page publique, même seulement sur grand écran, reste à trancher par le porteur | Non — UDR-0064 |

## Ce qui a dérapé

- **Le premier « rouge » n'était pas un rouge d'assertions.** Les tests RH ont été écrits avant la vue, mais l'ancienne vue ne rendait déjà plus (locale réécrite, photo supprimée) : tous les tests erraient sur le rendu, pas sur leurs assertions. Le vrai rouge/vert a été établi ensuite par les assertions elles-mêmes, qui nomment des sections (`#matieres`, `#enseignants`) et des comptes que l'ancienne page ne pouvait pas satisfaire. À refaire mieux : stasher la vue seule, garder locale et photo, pour voir les assertions tomber.
- **Le critère RH-03 était d'abord faux dans Selenium.** Une fenêtre Chrome headless de 360 × 640 ne laisse que 501 px au document : le test comparait les boutons à une fenêtre qui n'existe sur aucun téléphone. Le test émule désormais l'écran par le protocole DevTools (`Emulation.setDeviceMetricsOverride`), comme Playwright ; les mesures des deux outils coïncident alors (446 et 514 px pour 640).
- **Le héros a été resserré après la première capture** : chapeau en `text-base` avant `sm`, `py-10` au lieu de `py-12`. Les deux entrées finissaient à 534 px, soit 50 px sous la barre d'adresse d'un Android (584 px visibles sur 640) ; elles finissent à 514 px, soit 70 px de marge, et l'UDR-0064 a été corrigée dans le même commit.
- **La barre de debug du mode développement s'invitait dans les captures** (`#__debugbar`, immenses icônes sans style au pied de page). Retirée du DOM par le script de capture avant chaque prise ; les captures du dépôt sont prises sur le serveur de développement, pas en production.
- **Outillage du conteneur** : Ruby 3.3.6 seul, alors que le dépôt écrit `it` (Ruby 3.4) ; le chromedriver présent (147) ne pilotait pas le Chromium préinstallé (141). Ruby 3.4.9 par `rbenv install`, chromedriver 141 téléchargé depuis Chrome for Testing, `CHROME_BIN` et `CHROMEDRIVER_PATH` posés comme `bin/check-chrome` le prévoit.

## Ce qu'on a appris sur la codebase

- Le budget de poids de l'ADR-0051 ne couvre que `application.js` et `application.css` : une image de 1,3 Mo dans `app/assets/images` passe la CI sans bruit. Le test RH-04 borne la photo du héros ; un garde-fou général sur les images reste à décider (dette ci-dessous).
- Le conteneur de la session n'avait que Ruby 3.3.6 ; le dépôt écrit `it` (Ruby 3.4) jusque dans `config/ci.rb`. Ruby 3.4.9 installé par `rbenv install`, bundler 4.0.10 comme le `Gemfile.lock`, Yarn 4 par `corepack enable`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Un garde-fou de poids sur `app/assets/images` (aucune image servie à l'ouverture d'une page au-delà de 100 Ko, par exemple) | Relève de l'ADR-0051, qui ne couvre que JS et CSS : un amendement d'ADR, pas une ligne de ce chantier | à ouvrir (`optimize`) |
| Mode sombre de la page publique | Exclu de la V1 par l'UDR-0005 ; la grille de design synchronisée le prévoit : contradiction à trancher par le porteur | — |

## Rapport du challenger (2026-10-02)

Rôle distinct de l'auteur : un agent en lecture seule, qui **exécute** sans relire (tests, Chromium 141 piloté par Playwright 1.56, serveur de développement, HEAD `787c0d5`). Ses scripts, journaux et captures sont restés dans son espace de travail ; le verdict et les preuves sont repris ici.

| Critère du PRD rejoué | Verdict | Preuve |
|---|---|---|
| Tests unitaires et de vues (contrôleur, redirection, composants, titres, tokens) | PASS | 108 runs, 666 assertions, 0 échec |
| Tests système de la page | PASS | 4 runs, 19 assertions, 0 échec |
| Parcours nominal élève à 360 × 640 (RH-01, RH-02, RH-03) | PASS | entrées à 446 et 514 px pour 640 ; modale ouverte sans aucune requête, onglet « Tu es élève ? · Lnclass » ; « Rejoindre ma classe » atteint `/join` par Turbo, sans rechargement |
| Parcours nominal enseignant à 390 × 844 | PASS | section « Enseignants » atteinte, « Créer mon compte enseignant » (306 × 56 px) mène à l'inscription enseignant |
| Chemin d'erreur : JavaScript coupé | PASS | les deux entrées restent inertes sans quitter la page ; « Se connecter », le bouton enseignant et les ancres du pied restent des liens vivants |
| Chemin d'erreur : largeur 360 et 390, modale ouverte | PASS | aucun défilement horizontal ; la modale tient dans l'écran (296 px de haut à 390 × 844) |
| Poids (RH-04) | PASS | HTML 42,7 Ko (6,6 Ko gzip), WebP de 21 966 octets en 960 × 640 servi `image/webp`, PNG absent du disque, de l'index et de HEAD |
| Contenu (RH-01, RH-05, RH-07, RH-08, RH-10) | PASS | un seul `h1`, sept matières dans l'ordre et les teintes attendues, interdits absents, zéro tutoiement dans la section « Enseignants », badges Bronze · Argent · Or · Diamant |

**Ses cinq remarques de design, et ce qui en a été fait dans la même PR :**

1. *L'appel final est collé à la bande « Enseignants » (0 px mesuré à 360, 390 et 1 440).* Corrigé, puis sans objet (section retirée à la fusion, voir plus bas) : la section passe de `pb-16` à `py-16 md:py-24` ; 64 px de papier (96 sur grand écran) séparent la bande claire de la carte bleue.
2. *Au téléphone, le logo décoratif de l'appel final passe sous les deux boutons* (idem, sans objet depuis la fusion) (carré bleu foncé à bords nets derrière « Je suis élève » et « Je suis enseignant », chevauchement mesuré à 360 et 390). Corrigé : masqué sous `md` ; sur grand écran il reste à droite, hors des boutons.
3. *Bande des matières au téléphone : libellé seul sur son rang, puis des rangs irréguliers alignés à gauche.* Corrigé : au téléphone, le titre est centré sur sa ligne et les pastilles sont centrées (deux, trois, deux) ; dès `sm`, titre et pastilles s'alignent à gauche sur une ligne, comme avant.
4. *La pastille « Programme officiel, de la 6e à la Terminale » fait 316 px pour une colonne de 320 px à 360.* Gardée telle quelle : vérifiée à 320 px, elle passe sur deux lignes dans sa capsule, reste lisible, et les deux entrées restent dans le premier écran (bas à 466 et 534 px pour 568).
5. *La carte « Badge Or obtenu » frôle la bande des matières (20 px) ; le titre « Léger, sur tous les téléphones » tient sur deux lignes au téléphone.* Le premier point est corrigé (`pb-14` au téléphone : 36 px). Le second est accepté : un titre de carte qui passe à la ligne n'est ni tronqué ni ambigu.

**Anomalies qu'il a relevées :**

- La capture `accueil-modale-eleve--mobile.png` du dépôt avait été prise **pendant** l'animation d'ouverture (opacité 0,79 à 68 ms, 1 à 325 ms) : la feuille y était translucide. Le script de capture attend désormais la fin des animations de la modale (`getAnimations`) ; la capture a été refaite à opacité 1.
- Une violation CSP dans la console sur toutes les pages (`style-src`) : elle vient du script de la barre de debug du mode développement, pas de la page ; la barre de progression Turbo porte bien son nonce. Rien à faire.

**Ce que l'auteur a trouvé en revérifiant plus bas que lui :** à 320 px de large (Android d'entrée de gamme en 480 × 854), le bouton « Créer mon compte enseignant » (306 px) débordait de sa colonne de 280 px et faisait défiler la page en largeur de 6 px. Corrigé : pleine largeur au téléphone, bornée à `max-w-xs` à partir de `sm`.

**Re-vérification après corrections :** 104 tests unitaires et 10 tests système (page d'accueil, écrans étroits) verts ; mesures Playwright à 320, 360, 390 et 1 440 px : aucun défilement horizontal, logo masqué sous `md`, 64 px avant l'appel final, 36 px entre la carte du badge et la bande, entrées du héros inchangées (446 et 514 px pour 640). L'UDR-0064 est mise à jour dans le même commit ; ses tests n'ont pas eu à changer.

## Fusion avec `Develop` (2026-10-02, après le challenger)

La branche était partie de `Develop` du 1er octobre ; le 2 octobre, `Develop` a reçu les chantiers `interface-epuree`, `fonctions-espace-eleve` et `gestion-etablissement-direction` (470 fichiers), avec des décisions du porteur qui touchent directement cette page. La PR est passée en conflit ; la fusion a été faite dans la branche, sans réécrire l'historique, et le chantier s'est aligné sur ces décisions plutôt que de les contredire :

| Décision arrivée sur `Develop` | Ce que la page faisait | Ce qui a été fait |
|---|---|---|
| **UDR-0059** (acceptée) : les deux entrées ne sont plus répétées en bas de page ; sous 1 024 px, la homepage sera l'écran d'entrée dessiné par le porteur (lot M2 d'`interface-epuree`, à venir) | Un appel final répétait les deux entrées, avec un logo décoratif | L'appel final est retiré (deux modales au lieu de quatre, RH-09 réécrit) ; l'UDR-0064 se déclare famille ordinateur de l'UDR-0059, rendue à toutes les largeurs jusqu'au lot M2. Les remarques 1 et 2 du challenger (espace avant l'appel final, logo sous les boutons) n'ont plus d'objet |
| **UDR-0058** (acceptée) : la grille de l'accueil élève compte Maths, Physique-Chimie, SVT, Français, Histoire-Géo, EDHC ou Philosophie selon le cycle | Les sept matières du référentiel de développement, dont l'Anglais | La bande liste les matières de la grille élève : l'Anglais sort, EDHC entre (hypothèse du memo remplacée par une décision du porteur) |
| **UDR-0062 §4** : l'enseignant n'assigne plus que des exercices ; la landing ne promet plus de cours assignés (test sur `Develop`) | « Assignez-leur des cours, des fiches essentielles et des exercices » ; modale : « assigner du contenu » | « Assignez-leur des exercices du catalogue, avec les jours de vos séances » ; modale : « assigner des exercices » ; le test de `Develop` est repris au vouvoiement |
| **UDR-0063 §3.4** : le pied de la homepage liste les pages publiques en ligne (mission, confidentialité, CGU, CGV) | Un pied à trois liens | La seconde liste `public_pages` est reprise telle quelle (helper et tests de `Develop`), avec les cibles tactiles de la page |
| **UDR-0061** : `ui_modal` a déjà gagné `trigger_href:`, `trigger_size:` et `placement:` | Le chantier ajoutait `trigger_size:` et `trigger_full:` | Seul `trigger_full:` reste un ajout ; signature et partial de `Develop` conservés, l'amendement de l'UDR-0005 réduit d'autant |
| **UDR-0056 à 0063** prises par les autres chantiers | L'UDR du chantier portait le numéro 0056 | Renumérotée **UDR-0064** partout (fichier, index, en-têtes HITL, tests, amendements, chantier) |

**Preuve après fusion** : suite unitaire complète 3 075 tests, 0 échec, couverture 100 % lignes et branches ; tests système page d'accueil, design system, écrans étroits et carte d'aide : 49 tests, 0 échec ; rubocop 1 195 fichiers sans infraction ; brakeman sans avertissement ; captures refaites ; HTML de `/` 34,3 Ko (6,5 Ko gzip), deux modales, les quatre pages publiques au pied, entrées du héros toujours à 446 et 514 px pour 640.

Neuf fichiers en conflit, tous résolus en gardant les deux côtés : composant modale, vue et locale de la page, index des chantiers et des UDR, tests du contrôleur, du composant et du système. Leçon pour l'ouverture d'un chantier : **commencer par `git fetch` et repartir de `origin/Develop`**, puis relire l'index des UDR du jour avant de numéroter ; les deux auraient évité la collision et l'appel final construit pour rien.

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-02, en PR brouillon vers `Develop` (phase 5 : challenger passé le jour même, ses remarques corrigées dans la même PR, rapport ci-dessus ; acceptation de l'UDR-0064 et des hypothèses du memo par le porteur en revue) |
| **PR** | [#145](https://github.com/Lnclassapp/App.Lnclassapp/pull/145) |
| **ADR produits** | aucun |
| **UDR produits** | UDR-0064 (numérotée 0056 jusqu'à la fusion) ; amendements UDR-0012, UDR-0005 |

## Décisions du porteur en revue (2026-10-03)

| Question laissée ouverte | Réponse du porteur | Ce qui a été fait |
|---|---|---|
| L'Anglais, au référentiel de développement mais absent de la grille élève | « retire Anglais » | Déjà absent de la page. Retiré aussi du référentiel de développement et de test (seeds, fabrique, quatre tests qui comptaient sept matières) ; amendement de l'ADR-0034 |
| Le slogan, « Avec Lnclass… » sur ordinateur et « Forcément… » sur la maquette téléphone | « Lnclass tu comprends chap chap ! », rectifié sur l'app | `h1` de la page : « Lnclass, tu comprends chap chap ! » (virgule ajoutée, à retirer si le porteur la refuse) ; amendement de l'UDR-0059 pour l'écran d'entrée du lot M2 ; aucune autre occurrence dans l'application |
| Le mode sombre, prévu par la grille de design, exclu par l'UDR-0005 | « ajoute le mode sombre » | Il touche toute l'application, pas cette page : ouvert comme chantier distinct, `mode-sombre`, avec sa propre PR. Cette page n'a rien à changer, elle n'emploie que des tokens |

La branche a de nouveau absorbé `Develop` (13 commits de CI, sans conflit), dont la garde « 15 s de tests système par chantier » : cette PR ajoute environ une seconde (0,36 s pour RH-03, 0,63 s pour le déclencheur large du design system).

## Chapeau du héros (2026-10-03)

Le porteur a comparé trois chapeaux et retenu la proposition de l'agent : « Révise l'essentiel du cours, fais tes exercices avec la correction et prépare tes interros avec tes enseignants. » Elle garde les verbes et la correction de sa deuxième proposition, et la brièveté de la troisième ; « l'essentiel du cours » renvoie aux fiches essentielles, « interros » parle aux élèves. Les badges restent présentés plus bas (quatre promesses). À 360 × 640, les deux entrées restent dans le premier écran (test RH-03).

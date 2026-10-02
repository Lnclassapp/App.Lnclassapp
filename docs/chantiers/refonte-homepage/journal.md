# Journal — Refonte de la page d'accueil publique

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | Grill mené en session autonome, sans le porteur, chaque hypothèse de produit marquée dans le memo | La demande tient en une ligne (« tu vas refaire la Homepage ») et la session ne peut pas attendre une réponse ; les hypothèses sont listées pour la revue de PR | Non |
| 2026-10-02 | La photo passe en WebP 960 × 640 (22 Ko) plutôt qu'en JPEG (51 Ko) | Le plancher des navigateurs (Chrome 111, Safari 16.4, ADR-0051) lit le WebP ; moitié moins d'octets pour la même image | Non — UDR-0056 |
| 2026-10-02 | Les matières sont écrites dans la vue, pas lues en base | La page reste sans requête ; le référentiel de production est créé à l'écran par l'équipe et peut différer : une ligne de locale à changer, pas une query | Non — memo (hypothèse à confirmer) |
| 2026-10-02 | Deux options de `ui_modal` (`trigger_size:`, `trigger_full:`) plutôt qu'un bouton écrit à la main dans la vue | Le déclencheur doit vivre dans le périmètre du contrôleur `modal` ; un bouton hors du composant ne pourrait pas ouvrir la `<dialog>` | Non — amendement UDR-0005 |
| 2026-10-02 | L'enseignant est vouvoyé sur la page, l'élève tutoyé | C'est le ton de l'application (`teacher_homes`, `teacher_registrations`) ; la page actuelle tutoyait l'enseignant | Non — UDR-0056 |

## Ce qui a dérapé

- **Le premier « rouge » n'était pas un rouge d'assertions.** Les tests RH ont été écrits avant la vue, mais l'ancienne vue ne rendait déjà plus (locale réécrite, photo supprimée) : tous les tests erraient sur le rendu, pas sur leurs assertions. Le vrai rouge/vert a été établi ensuite par les assertions elles-mêmes, qui nomment des sections (`#matieres`, `#enseignants`) et des comptes que l'ancienne page ne pouvait pas satisfaire. À refaire mieux : stasher la vue seule, garder locale et photo, pour voir les assertions tomber.
- **Le critère RH-03 était d'abord faux dans Selenium.** Une fenêtre Chrome headless de 360 × 640 ne laisse que 501 px au document : le test comparait les boutons à une fenêtre qui n'existe sur aucun téléphone. Le test émule désormais l'écran par le protocole DevTools (`Emulation.setDeviceMetricsOverride`), comme Playwright ; les mesures des deux outils coïncident alors (446 et 514 px pour 640).
- **Le héros a été resserré après la première capture** : chapeau en `text-base` avant `sm`, `py-10` au lieu de `py-12`. Les deux entrées finissaient à 534 px, soit 50 px sous la barre d'adresse d'un Android (584 px visibles sur 640) ; elles finissent à 514 px, soit 70 px de marge, et l'UDR-0056 a été corrigée dans le même commit.
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

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-02, en PR brouillon vers `Develop` (phase 5 : rapport du challenger ci-dessous ; acceptation de l'UDR-0056 et des hypothèses du memo par le porteur en revue) |
| **PR** | [#145](https://github.com/Lnclassapp/App.Lnclassapp/pull/145) |
| **ADR produits** | aucun |
| **UDR produits** | UDR-0056 ; amendements UDR-0012, UDR-0005 |

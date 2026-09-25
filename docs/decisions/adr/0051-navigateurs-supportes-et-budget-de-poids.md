# ADR-0051 : Navigateurs supportés sans blocage, et budget de poids vérifié en CI

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-24 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-29**, bloque la V0 |
| **Complète** | [ADR-0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md) (public cible : Android d'entrée de gamme en 3G/4G, JavaScript minimal) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'[ADR-0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md) désigne le public : des élèves sur des **Android d'entrée de gamme**, en **3G ou 4G**, avec des données mobiles payées par la famille. Il ne fixe ni liste de navigateurs ni budget chiffré. L'ancienne application contredit ce public sur trois points (écarts C-36 et TR-35 de la feuille de route) :

1. **Elle refuse les téléphones du public.** `ApplicationController` pose `allow_browser versions: :modern`. Rails 8.1 traduit `:modern` par Chrome 120, Safari 17.2, Firefox 121 et Opera 106. En dessous, l'élève reçoit une **page 406** et ne peut rien faire. Or un Android 7 ne dépasse pas Chrome 119, et les navigateurs intégrés (WebView de Facebook, navigateurs de constructeurs) ont souvent plusieurs versions de retard.
2. **Elle est lourde.** Mesure du 2026-09-24, build actuel non minifié :

   | Ressource | Brut | gzip |
   |---|---|---|
   | JavaScript (`application.js`, un seul bundle pour toutes les pages) | 622 Ko | **132 Ko** |
   | CSS (`application.css`) | 191 Ko | **26 Ko** |

   Répartition du JavaScript minifié : Trix 200 Ko, Turbo 92 Ko, Stimulus 44 Ko, code applicatif 25 Ko, Action Text 15 Ko, canvas-confetti 11 Ko, Action Cable 10 Ko. **Trix, un éditeur de texte riche utilisé seulement par les enseignants, pèse plus que Turbo et Stimulus réunis, et chaque élève le télécharge.**
3. **Rien ne vérifie le poids.** Aucune CI ne mesure les fichiers produits : le bundle peut doubler sans que personne ne le voie.

Contrainte technique : **Tailwind v4**, retenu par l'ADR-0009, cible officiellement **Chrome 111, Safari 16.4 et Firefox 128**. Il s'appuie sur des fonctions CSS (couleurs `oklch`, `color-mix`, `@property`, cascade layers) qu'un navigateur plus ancien ignore : la page s'affiche, mais couleurs et espacements peuvent se dégrader.

## 2. Moteurs de décision

Par ordre d'importance :

1. **Aucun élève n'est bloqué** à l'entrée à cause de son téléphone.
2. Données mobiles et temps de chargement en 3G : chaque kilo-octet est payé par la famille.
3. Rester sur la pile retenue (Tailwind v4, Hotwire) sans maintenir une seconde feuille de style pour les vieux navigateurs.
4. Une règle qu'une machine vérifie : un budget que personne ne mesure n'existe pas.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder `allow_browser :modern` | Aucun effort ; tout navigateur admis rend Tailwind v4 à la perfection | Page 406 pour une partie du public cible ; contredit l'ADR-0009 |
| B — Plancher **bloquant** aligné sur Tailwind (Chrome 111, Safari 16.4, Firefox 128) | Moins de refus qu'aujourd'hui ; rendu garanti pour les admis | Refuse encore les Android 6, les navigateurs de constructeurs et de nombreuses WebView : même défaut en plus petit |
| **C — Plancher supporté et testé, non bloquant en dessous** | Personne n'est refusé ; l'équipe teste une cible claire ; l'élève sur un vieux téléphone est prévenu | Retenue — voir coûts consentis |
| D — Aucune liste, aucune détection | Rien à maintenir | Aucune cible de test ; l'élève ne sait pas pourquoi l'affichage est cassé |

## 4. Décision

> **Nous ne refusons l'accès à aucun navigateur.** Le code de statut 406 pour navigateur ancien disparaît.
>
> **Nous supportons et testons un plancher : Chrome 111, Safari 16.4, Firefox 128**, celui de Tailwind v4. Les navigateurs dérivés de Chromium (Samsung Internet, WebView Android, UC Browser…) sont jugés sur leur version de Chrome.
>
> **En dessous du plancher, la page est servie normalement (200)** avec un bandeau non bloquant : « Votre navigateur est ancien : l'affichage peut être dégradé. » L'élève peut continuer.
>
> **Nous tenons un budget de poids, vérifié en CI et bloquant** :
>
> | Ressource | Plafond (gzip) | Mesuré sur |
> |---|---|---|
> | JavaScript chargé à l'ouverture d'une page | **60 Ko** | le point d'entrée commun, minifié |
> | CSS | **30 Ko** | la feuille compilée, minifiée |
>
> **Les bibliothèques lourdes ou rares ne font pas partie du point d'entrée commun.** Trix, KaTeX et canvas-confetti sont chargés **uniquement sur les pages qui s'en servent**, par import dynamique. Aucune bibliothèque ne vient d'un CDN tiers (ADR-0049) : tout passe par le bundle.

Découpage :

| Élément | Livré en | Par |
|---|---|---|
| Plancher non bloquant + bandeau + tests | **V0** (`amorcage-depot`) | garde-fou de la feuille de route |
| Build minifié, découpé, et script de budget bloquant en CI | **V0** (`amorcage-depot`) | idem |
| Chargement à la demande de KaTeX | **V1** (TR-41, lots B / C) | premier écran qui affiche une formule |
| Chargement à la demande de Trix | à la vague qui réintroduit l'édition riche | premier écran enseignant qui en a besoin |

## 5. Conséquences

### 🟢 Positives

- Un élève sur un Android 6 ou dans la WebView de Facebook **entre** dans l'application au lieu d'une page d'erreur.
- Un élève télécharge **près de trois fois moins** de JavaScript qu'aujourd'hui dès la V0 : Trix et confetti sortent du chemin commun (mesure ci-dessous).
- Le budget est une porte de CI : une dépendance qui fait exploser le poids est refusée **avant** la fusion, pas découverte en 3G.
- Une cible de test unique et nommée, alignée sur ce que Tailwind garantit.

### 🔴 Coûts consentis

- **Sous le plancher, aucun rendu n'est garanti.** Couleurs `oklch` ignorées, mises en page approximatives : c'est le prix de Tailwind v4 sans seconde feuille de style. Le JavaScript peut aussi ne pas s'exécuter ; le rendu serveur et les formulaires HTML natifs restent alors le filet, sans que cet ADR en fasse une garantie.
- **Le bandeau doit s'afficher lisiblement partout**, y compris là où Tailwind échoue : il est stylé en CSS simple (couleurs hexadécimales, sans `oklch` ni `color-mix`), hors des utilitaires Tailwind.
- **La détection est imparfaite.** Elle repose sur l'en-tête `User-Agent` analysé par la gemme `useragent` (celle de `allow_browser`). Vérifié le 2026-09-24 : Samsung Internet et UC Browser sont bien lus comme Chrome, Googlebot est reconnu comme robot. En revanche, **Opera n'est pas surveillé** : la gemme lit la version d'Opera, pas celle de Chromium, et elle est incohérente (Opera Mobile récent → 82, Opera Mini récent → 4.0). Opera reçoit donc la page sans bandeau.
- **Découper le bundle impose une discipline** : un contrôleur Stimulus qui a besoin de KaTeX ou de Trix l'importe dynamiquement (`await import(...)`), jamais en tête de fichier.
- **60 Ko laisse une marge étroite.** Mesure du 2026-09-24 sur le code actuel, minifié et ciblé sur le plancher : tout le bundle 108 Ko gzip ; sans Trix ni Action Text 51 Ko ; sans confetti non plus, environ 47 Ko. Turbo et Stimulus seuls en pèsent 40. Il reste donc une douzaine de kilo-octets pour le code applicatif à venir. Relever un plafond exige un nouvel ADR qui remplace celui-ci, pas une modification du script.

### Question laissée ouverte

Le mode de rendu de KaTeX (dans le navigateur, chargé à la demande, ou **côté serveur**, ce qui ne laisse au client que la feuille de style et les polices) se tranche en V1 avec TR-41. Dans les deux cas, KaTeX n'entre pas dans le point d'entrée commun.

## 6. Notes d'implémentation

Pour le nouveau dépôt (Rails 8.1), à livrer par le chantier `amorcage-depot`.

**Plancher non bloquant.** `allow_browser` n'exécute son bloc que pour un navigateur surveillé et trop ancien. Si le bloc ne fait pas de rendu, la requête continue. Vérifié le 2026-09-24 dans le code d'actionpack 8.1.3.1, puis par un test jetable : Chrome 106 → 200 avec bandeau, Chrome 111 → 200 sans bandeau, requête sans `User-Agent` → 200 sans bandeau :

```ruby
# app/controllers/application_controller.rb
# ADR-0051 : plancher Tailwind v4, jamais bloquant — un navigateur ancien reçoit la page et un bandeau.
SUPPORTED_BROWSERS = { chrome: 111, safari: 16.4, firefox: 128, ie: false }.freeze
allow_browser versions: SUPPORTED_BROWSERS, block: -> { @outdated_browser = true }
```

```erb
<%# app/views/layouts/application.html.erb, juste après <body> %>
<% if @outdated_browser %>
  <div class="outdated-browser" role="status"><%= t("layouts.outdated_browser") %></div>
<% end %>
```

`.outdated-browser` est défini hors des utilitaires Tailwind, en CSS que tout navigateur comprend (`background:#fff4ce; color:#3d2e00; padding:.5rem 1rem`).

**Build.** esbuild minifié, découpé en morceaux chargés à la demande, ciblant le plancher. Le suffixe `.digested` empêche Propshaft d'ajouter une seconde empreinte au nom des morceaux, que le point d'entrée référence par leur nom exact (convention documentée par jsbundling-rails) :

```json
"build": "esbuild app/javascript/application.js --bundle --minify --splitting --chunk-names=[name]-[hash].digested --format=esm --target=chrome111,safari16.4,firefox128 --sourcemap --outdir=app/assets/builds --public-path=/assets"
```

```js
// app/javascript/controllers/math_controller.js — KaTeX n'est chargé que si ce contrôleur est présent sur la page
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    const { default: katex } = await import("katex")
    katex.render(this.element.textContent, this.element, { throwOnError: false })
  }
}
```

**Budget.** Un script lancé par `bin/ci`, après `yarn build` et `yarn build:css` :

```ruby
#!/usr/bin/env ruby
# bin/check-asset-budget — ADR-0051 : plafonds gzip du point d'entrée JS commun et de la CSS.
require "zlib"

BUDGET = { "app/assets/builds/application.js" => 60, "app/assets/builds/application.css" => 30 }.freeze

def gzip_kb(path) = Zlib.gzip(File.binread(path), level: Zlib::BEST_COMPRESSION).bytesize / 1024.0

over = BUDGET.filter_map do |path, limit_kb|
  size_kb = gzip_kb(path)
  puts format("%-40s %6.1f Ko gzip / %d Ko", path, size_kb, limit_kb)
  path if size_kb > limit_kb
end

Dir["app/assets/builds/*.digested.js"].each { |chunk| puts format("%-40s %6.1f Ko gzip (à la demande)", chunk, gzip_kb(chunk)) }

abort "ADR-0051 : budget dépassé pour #{over.join(', ')}" if over.any?
```

Les morceaux chargés à la demande (`*.digested.js`) sont affichés par le script pour information, sans plafond tant qu'aucun n'a été fixé.

## 7. Comment vérifier que la décision est respectée

Trois contrôles livrés en V0, **bloquants en CI** :

```ruby
# test/integration/supported_browsers_test.rb
require "test_helper"

class SupportedBrowsersTest < ActionDispatch::IntegrationTest
  OLD_ANDROID = "Mozilla/5.0 (Linux; Android 6.0; TECNO W3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.5249.126 Mobile Safari/537.36"
  FLOOR       = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Mobile Safari/537.36"

  test "a browser below the floor gets the page and a warning, never a 406" do
    get root_path, headers: { "User-Agent" => OLD_ANDROID }

    assert_response :ok
    assert_select ".outdated-browser"
  end

  test "a browser at the floor gets the page without warning" do
    get root_path, headers: { "User-Agent" => FLOOR }

    assert_response :ok
    assert_select ".outdated-browser", count: 0
  end
end
```

- `bin/check-asset-budget` dans `bin/ci`, après la compilation des assets.
- Test système (Chrome headless, donc au-dessus du plancher) sur les parcours de la vague : la cible supportée reste testée de bout en bout.

Aucune page ne renvoie plus `406` pour cause de navigateur : si `public/406-unsupported-browser.html` existe encore dans le nouveau dépôt, il est supprimé.

## Amendement du 2026-09-25

*Chantier `docs/chantiers/boucle-pedagogique`, retour du porteur du 2026-09-25. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **La vague qui réintroduit l'édition riche, c'est la V1.** La ligne « Chargement à la demande de Trix — à la vague qui réintroduit l'édition riche » du §4 se lit donc **V1**, lots B2 (gestion des cours) et B4 (gestion des fiches essentielles). V0 avait retiré Action Text (paquets, framework et table) faute d'écran qui s'en serve ; la V1 les remet.
- **Périmètre** : Action Text et Trix servent au contenu des **cours** et des **fiches essentielles**, comme dans l'ancienne application (`has_rich_text :content`). Les annonces de la V6 restent en texte simple (ADR-0045).
- **Chargement** : `trix` et `@rails/actiontext` sont chargés **uniquement sur les pages d'édition**, par import dynamique, depuis le contrôleur Stimulus `rich_text_editor` (identifiant `rich-text-editor`). Ils restent **hors du point d'entrée commun de 60 Ko** : aucun `import` statique de ces paquets n'est permis, et un test d'architecture le vérifie. La feuille de style de Trix (`trix.css`) est un fichier à part, ajouté au `<head>` par le même contrôleur : le budget CSS commun de 30 Ko n'est pas touché.
- **Sécurité** : Trix lit le nonce de `csp_meta_tag` et fonctionne sous la CSP stricte de l'ADR-0049, ce qu'un test système prouve. Le contenu est assaini **au rendu** par Action Text. Le HTML écrit par les imports JSON (`course_tree`, `essentials`, ADR-0039) est **assaini avant écriture**, avec la même liste blanche, et un test vérifie qu'un `<script>`, un attribut `on*` ou un lien `javascript:` n'arrive pas en base.
- **Pièces jointes** : aucune dans l'éditeur en V1, **décision du porteur** : c'est un éditeur de texte uniquement. Le contrôleur `rich_text_editor` annule l'événement `trix-file-accept` et masque le bouton de fichier ; aucun `direct_upload` n'est branché, ce qui évite d'ouvrir `connect-src` vers le bucket (ADR-0047, ADR-0049).
- Rien ne change pour le plancher des navigateurs, les plafonds du budget ou leur contrôle en CI.

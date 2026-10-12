# UDR-0078 : Bandeau d'installation (Android et iPhone), page « Pas de connexion », tuile « Ouvert depuis l'app installée »
<!-- index
titre: Bandeau d'installation (Android et iPhone), page « Pas de connexion », tuile « Ouvert depuis l'app installée »
statut: Proposé
adr-lie: [0082](../adr/0082-application-installable-sans-page-de-compte-sur-le-telephone.md), [0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md), [0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md)
problematique: Bandeau en tête du contenu du shell élève et enseignant, caché par défaut, montré par le contrôleur `install` (« Installer » sur Android, deux étapes sur iPhone), « Plus tard » 3 jours sur l'appareil ; page statique `offline.html` sans script, « Réessayer » recharge l'adresse demandée ; tuile pleine largeur dans « Sur la période » du pilotage. Amende UDR-0006 et UDR-0049
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-07 |
| **Chantier** | [`docs/chantiers/installation-pwa`](../../chantiers/installation-pwa/memo.md) |
| **ADR lié** | [ADR-0082](../adr/0082-application-installable-sans-page-de-compte-sur-le-telephone.md) · [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucun script en ligne) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (poids) |
| **Amende** | [UDR-0006](0006-shell-applicatif-par-role.md) (le shell porte le bandeau, élève et enseignant seulement) · [UDR-0049](0049-page-pilotage-de-l-equipe.md) (une tuile de plus dans « Sur la période ») |
| **Remplacé par** | — |

---

## 1. Contexte

Un élève ou un enseignant qui veut Lnclass sur son téléphone ne sait pas que son navigateur peut l'installer. Sur iPhone, l'installation passe par un menu caché (« Partager », puis « Sur l'écran d'accueil »). Sans réseau, l'app installée afficherait l'erreur du navigateur (« Vous êtes hors connexion », dinosaure), qui ne dit pas que c'est Lnclass ni quoi faire. L'équipe, enfin, ne sait pas si l'installation prend.

## 2. Décision

1. **Un bandeau en tête du contenu, pas une fenêtre** : il ne bloque pas la tâche de l'écran, il se ferme d'un geste et ne revient pas avant 3 jours sur ce téléphone. Il n'est **pas fixé** au-dessus de la barre basse : il défile avec la page, pour ne jamais masquer un bouton.
2. **Deux variantes, choisies par le navigateur, jamais par le serveur** : Android (le navigateur a annoncé que le site est installable) montre « Installer » ; iPhone (Safari, hors de l'app installée) montre le mode d'emploi en deux étapes, sans bouton « Installer », puisque rien ne peut installer à la place de l'utilisateur.
3. **Caché par défaut dans le HTML** (`hidden`) : sans JavaScript, ou sur un navigateur qui ne sait pas installer, rien ne s'affiche. Le serveur rend le même HTML à tous les élèves et enseignants : zéro requête, aucune variante en cache.
4. **La page « Pas de connexion » est statique**, sans logo d'image lourd ni police web : elle doit s'afficher depuis le téléphone, sans réseau, avec le seul bleu de marque.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Bandeau d'installation — `shared/navigation/_install_banner`

**Où** : `layouts/shell`, comme **premier enfant** de `div[data-bleed]` dans `main#main`, avant `yield`, seulement si `shell_user.role` vaut `"student"` ou `"teacher"`. Le partial reçoit `(role:)`.

**Structure** :

```
section#install_banner.lg:hidden.mb-5.rounded-card.border.border-line.bg-brand-soft.p-4
  [hidden]
  [aria-labelledby="install_banner_title"]
  [data-controller="install"]
  div.flex.items-start.gap-3
    img[src="/icon-192.png"][alt=""][width=48][height=48].size-12.shrink-0.rounded-ln
    div.min-w-0.flex-1
      p#install_banner_title.font-display.text-base.font-extrabold.text-ink    → t(".title.<role>")  (un p, pas un h2 : le bandeau précède le h1 de la page)
      p.mt-1.text-sm.text-mute                                                  → t(".body.<role>")
      ol.mt-2.grid.gap-1.text-sm.text-ink[data-install-target="ios"][hidden]   → 2 li, §3.1.2
      div.mt-3.flex.flex-wrap.gap-2
        ui_button t(".install"), variant: :secondary, size: :sm, icon: "arrow-down-tray",   (secondaire : le bandeau ne prend pas l'action principale de l'écran, UDR-0057 R1)
                  data: { install_target: "android", action: "install#prompt" }, hidden: true
        ui_button t(".later"), variant: :ghost, size: :sm,
                  data: { action: "install#later" }
```

**Textes** (`config/locales/shared/navigation.fr.yml`, clé `shared.navigation.install_banner`) :

| Clé | Élève (`student`) | Enseignant (`teacher`) |
|---|---|---|
| `title` | « Installe Lnclass sur ton téléphone » | « Installez Lnclass sur votre téléphone » |
| `body` | « Retrouve tes cours et tes exercices en un geste, depuis ton écran d'accueil. » | « Retrouvez vos classes en un geste, depuis votre écran d'accueil. » |
| `ios_share` | « Touche **Partager** » + `ui_icon "arrow-up-on-square", size: :sm` | « Touchez **Partager** » + même icône |
| `ios_add` | « Puis **Sur l'écran d'accueil** » + `ui_icon "plus-circle", size: :sm` | « Puis **Sur l'écran d'accueil** » + même icône |
| `install` | « Installer » | « Installer » |
| `later` | « Plus tard » | « Plus tard » |

#### 3.1.1 Contrôleur Stimulus `install` — `app/javascript/controllers/install_controller.js`

Cibles `android`, `ios`. Constantes : `STORAGE_KEY = "lnclass.install.later_until"`, `LATER_DAYS = 3`.

- **`connect()`** :
  1. Si `matchMedia("(display-mode: standalone)").matches` ou `navigator.standalone === true` → ne rien montrer, fin.
  2. Si `laterUntil() > Date.now()` → ne rien montrer, fin.
  3. Si iPhone ou iPad Safari (`/iPhone|iPad/` dans `navigator.userAgent`, et `!/CriOS|FxiOS|EdgiOS/`) → montrer la cible `ios` puis le bandeau (`this.element.hidden = false`).
  4. Sinon, écouter `beforeinstallprompt` sur `window` : `event.preventDefault()`, garder l'événement, montrer la cible `android` puis le bandeau.
  5. Écouter `appinstalled` sur `window` → cacher le bandeau.
- **`prompt()`** : appelle `deferred.prompt()`, attend `userChoice`. `accepted` → cacher. `dismissed` → même effet que `later()`. L'événement n'est utilisé qu'une fois.
- **`later()`** : écrit `Date.now() + 3 j` sous `STORAGE_KEY`, cache le bandeau, puis rend le focus à `main#main`.
- **`laterUntil()`** : lit `STORAGE_KEY` ; valeur absente, non numérique ou exception → `0`.
- Toute lecture ou écriture de `localStorage` est dans un `try/catch` ; une exception ne casse jamais la page (le bandeau peut alors revenir).
- **`disconnect()`** : retire les écouteurs `window`.
- En-tête HITL de 3 lignes, format du `theme_controller.js` ; `UDR : 0078 · ADR : 0082, 0049`.

#### 3.1.2 Mode d'emploi iPhone

`ol` à deux `li.flex.items-center.gap-2`, chacun : une pastille `span.grid.size-6.place-items-center.rounded-full.bg-white.text-xs.font-bold.text-brand-strong` avec « 1 » puis « 2 » (`aria-hidden="true"`), le texte (`ios_share`, puis `ios_add`), l'icône (`aria-hidden`). La liste ordonnée donne l'ordre aux lecteurs d'écran.

#### 3.1.3 États

| État | Rendu |
|---|---|
| Défaut (HTML servi, JS pas encore exécuté, ou pas de JS) | `hidden` : rien |
| Navigateur qui ne sait pas installer, app installée, « Plus tard » de moins de 3 jours, écran ≥ `lg` | rien |
| Android, installable | titre, texte, « Installer », « Plus tard » |
| iPhone Safari | titre, texte, les deux étapes, « Plus tard » |
| Fenêtre d'Android ouverte | inchangé jusqu'au choix |
| Installé (`accepted` ou `appinstalled`) | le bandeau disparaît |
| Erreur (`prompt()` rejette) | le bandeau disparaît comme « Plus tard » ; aucune alerte |

**Accessibilité** : la `section` est nommée par son titre ; « Installer » et « Plus tard » sont des `button` de `min-h-tap` (48 px) ; contraste `text-ink` sur `bg-brand-soft` et `text-mute` sur `bg-brand-soft` ≥ 4,5:1 dans les deux thèmes (à vérifier par le test du design system) ; aucune animation d'apparition ; le bandeau n'est pas une région `aria-live` (il apparaît au chargement, pas à la suite d'un geste). Mode sombre : tokens uniquement, aucune couleur littérale.

### 3.2 Page « Pas de connexion » — `public/offline.html` et `public/offline.css`

Fichiers statiques, **sans script**, sans police web, sans image autre que `/icon-192.png`.

```
<!DOCTYPE html>
html[lang="fr"]
  head : meta charset utf-8 ; meta viewport « width=device-width,initial-scale=1,viewport-fit=cover » ;
         meta color-scheme « light dark » ; meta theme-color « #00a0ff » ;
         title « Pas de connexion · Lnclass » ; link rel=stylesheet href=/offline.css
  body
    main.offline
      img[src="/icon-192.png"][alt="Lnclass"][width=72][height=72]
      h1 « Pas de connexion »
      p « Lnclass a besoin d'internet pour s'ouvrir. Vérifie ton réseau ou tes données mobiles, puis réessaie. »
      a.offline-retry[href=""] « Réessayer »
```

- `href=""` recharge l'adresse demandée, qui reste celle de la barre de l'app : « Réessayer » ramène l'élève exactement où il allait, sans JavaScript.
- Le texte tutoie : l'élève est le public principal ; la page est la même pour tous (pas de compte connu hors ligne).
- `offline.css` : variables en tête (`--bg #ffffff`, `--ink #1f2128`, `--mute #5f6470`, `--accent #00a0ff`, `--accent-strong #0070b3`) redéfinies sous `@media (prefers-color-scheme: dark)` (`--bg #0f1218`, `--ink #eef1f5`, `--mute #9aa3b0`, `--accent-strong #7fd0ff`) ; police `system-ui` ; `main` centré verticalement (`min-height: 100dvh`, grille, `place-content: center`), largeur max 22rem, marges latérales 16 px ; `h1` 21 px, graisse 800 ; `p` 15 px `--mute` ; lien `.offline-retry` en bouton plein `--accent-strong` / texte blanc (blanc sur `--accent` ne donne que 2,9:1, corrigé à l'exécution), hauteur min. 48 px, rayon 9999px, focus visible `outline: 3px solid var(--accent-strong)` décalé de 2 px ; logo `border-radius: 18px`.
- Aucun texte de compte, aucun nom, aucune classe.
- États : c'est elle-même l'état « erreur réseau » ; aucun chargement (fichier local) ; aucun état vide.

### 3.3 Tuile du pilotage — `teams/dashboards/_key_figures`

Dans la carte « Sur la période » (`#team_dashboard_period`), **après** la tuile `:assignments`, une tuile `li#figure_app_openers.col-span-2.rounded-ln.bg-mist.px-3.py-4.lg:col-span-4` (comme `#figure_schools`) :

- Titre `span.text-sm.text-mute` : « Ouvert depuis l'app installée ».
- `ul#team_dashboard_app_openers.mt-2.grid.gap-1.text-sm.text-ink.sm:grid-cols-2[aria-label="Ouvert depuis l'app installée, par rôle"]` : deux `li.tabular-nums` : « %{count} élève(s) », « %{count} enseignant(s) » (pluriels i18n `one`/`other`, `0` → « 0 élève »).
- `ui_info_tip` : « Comptes qui ont ouvert Lnclass depuis l'icône de leur téléphone sur la période. Un compte compte une fois. » avec le label « Ouvert depuis l'app installée » (comme les autres infobulles, qui nomment leur chiffre).
- La grille passe ainsi à 4 tuiles + une tuile pleine largeur sur `lg`.
- États : vide → « 0 élève », « 0 enseignant » (jamais masqué : un zéro dit que l'installation ne prend pas encore) ; chargement et erreur : ceux du tableau de bord existant (UDR-0049).

## 4. Conséquences

- Le shell élève et enseignant porte un bloc caché de plus dans chaque page ; il n'ajoute aucune requête.
- Le bandeau ne compte pas dans les blocs visibles avant le premier défilement (règle R2 de sobriété) : c'est une invitation passagère, qui se ferme d'un geste et ne revient pas avant 3 jours. Les tests système ignorent donc le vrai signal d'installation de Chrome ; seuls les tests du bandeau le simulent.
- Aucun autre écran ne propose l'installation : un futur bouton « Installer » ailleurs (profil, aide) réutilise le contrôleur `install` et ce mode d'emploi, sans nouvelle règle.
- Interdit : un bandeau d'installation fixé en bas d'écran, une fenêtre modale d'installation, un bandeau pour la direction, l'équipe ou les pages publiques, une mémorisation du choix sur le serveur.
- La page « Pas de connexion » ne suit pas les composants ERB ni la feuille de l'application : toute évolution du design system qui doit l'atteindre se recopie à la main dans `offline.css`, et le numéro de cache du programme d'arrière-plan augmente.

## Amendement du 2026-10-07 — une pop-up, sur l'accueil seulement

*Décision du porteur, après les captures du bandeau. En cas d'écart avec le texte ci-dessus, cette section fait foi.*

**Ce qui change**

1. **Une pop-up, plus un bandeau.** L'invitation est une `ui_modal` en feuille basse (`placement: :sheet`, `size: :sm`, UDR-0061 §3.3) : elle monte du bas sur téléphone. Elle remplace §2.1 et la structure de §3.1. L'interdit de §4 sur la fenêtre modale d'installation est levé.
2. **Sur l'accueil seulement** : `classroom/student_homes/show` et `classroom/teacher_homes/show` rendent `shared/navigation/install_banner` avec `role:` en dernier. Le shell ne le rend plus (UDR-0006 retrouve son texte). Aucune autre page n'en porte, « Ma classe » comprise.
3. **Téléphone seulement** : le contrôleur n'ouvre rien quand `(min-width: 64rem)` est vrai.

**Structure**

```
div[data-controller="install"][data-action="close->install#dismissed:capture"]
  ui_modal id: "install_banner", title: t(".title.<role>"), size: :sm, placement: :sheet
    div.flex.items-start.gap-3
      img[src="/icon-192.png"][alt=""].size-12.shrink-0.rounded-ln
      div.min-w-0.flex-1
        p.text-sm.text-mute                                  → t(".body.<role>")
        ol.mt-3.grid.gap-2.text-sm.text-ink[data-install-target="ios"][hidden]  → les deux étapes (§3.1.2, pastilles bg-brand-soft)
    footer
      ui_button t(".later"), variant: :ghost, data-action install#later
      ui_button t(".install"), variant: :primary, icon: "arrow-down-tray", hidden, data-install-target android, data-action install#prompt
```

Le titre est le `h2` de la modale (`#install_banner-title`) : il vit dans la couche supérieure, hors de l'ordre des titres de la page. La croix, Échap et le fond ferment la modale, comme toute `ui_modal`.

**Comportement (remplace §3.1.1)**

- `connect()` s'arrête sans rien ouvrir en mode `standalone`, sur un écran ≥ 64rem, ou si « Plus tard » date de moins de 3 jours.
- Sur Safari iPhone, il montre les deux étapes ; sur Android, il attend `beforeinstallprompt` et montre « Installer ». Il ouvre ensuite la modale par son contrôleur `modal`, une microtâche plus tard, le temps que ce contrôleur se connecte.
- Toute fermeture sans installation (« Plus tard », croix, Échap, fond) écrit `lnclass.install.later_until` = maintenant + 3 jours. L'événement `close` de la `<dialog>` ne remonte pas : on l'écoute en phase de capture.
- Après une installation acceptée, ou après `appinstalled`, la modale se ferme sans rien écrire.

**Conséquences**

- La règle R2 de sobriété n'est plus en jeu : la pop-up ne prend aucune place dans la page.
- La pop-up couvre l'accueil à la première visite sur téléphone, puis au plus une fois tous les 3 jours. C'est le prix de la visibilité, choisi par le porteur.

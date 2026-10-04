# UDR-0065 : Mode sombre — les tokens changent de valeur, les écrans ne changent pas

| | |
|---|---|
| **Statut** | Proposé *(2026-10-03 ; principe décidé par le porteur, palette à accepter en revue de PR)* |
| **Date** | 2026-10-03 |
| **Chantier** | [`docs/chantiers/mode-sombre`](../../chantiers/mode-sombre/prd.md) — critères MS-01 à MS-07 |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucune ressource tierce) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (plancher des navigateurs) · [UDR-0005](0005-design-system-fondateur.md) (tokens ; sa décision 4 est levée) · [UDR-0054](0054-finitions-d-interface.md) (§3.7, page imprimée) |
| **Remplacé par** | — |

---

## 1. Contexte

Un téléphone en thème sombre reçoit des pages claires. La grille de design du fondateur demande un mode sombre complet par les tokens ; l'UDR-0005 l'avait exclu de la V1. Le porteur l'a demandé le 2026-10-03.

## 2. Décision

1. **Le mode suit le réglage du système** (`prefers-color-scheme`), sur l'écran seulement. Pas d'interrupteur dans l'application.
2. **Les tokens changent de valeur, pas les écrans.** Un bloc unique de la feuille redéfinit chaque `--color-*` littéral du `@theme` et les trois ombres. Aucune vue n'écrit `dark:` ; l'interdiction de l'UDR-0005 reste.
3. **La règle d'inversion** : le texte (`ink`, `mute`) devient clair ; les surfaces (`white`, `paper`, `mist`, `line`) deviennent sombres ; un fond qui porte un texte blanc (`ink`, `team`, `school`, `error`, `success`, `warning`) devient clair ; un fond qui porte un texte `ink` (`brand`, `teacher`, `gold`) devient profond. `brand-strong`, couleur de lien et de texte, devient clair.
4. **Le voile d'une modale reste sombre** ; une page imprimée reste claire.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Feuille** — à la fin de `app/assets/stylesheets/application.tailwind.css`, hors couche :

```
@media screen and (prefers-color-scheme: dark) {
  :root { color-scheme: dark; --color-…: … ; --shadow-…: … }
  dialog::backdrop { background-color: rgb(0 0 0 / 0.6); }
}
```

| Token | Clair | Sombre |
|---|---|---|
| `white` (surfaces, cartes, champs) | `#ffffff` | `#171c24` |
| `ink` (texte) | `#262626` | `#eef1f5` |
| `mute` | `#5e5a54` | `#a3acb9` |
| `line` | `#e6e1d8` | `#2c3542` |
| `mist` | `#f2eee7` | `#222a35` |
| `paper` (fond de page) | `#faf8f4` | `#0f1218` |
| `brand` | `#00a0ff` | `#0070b3` |
| `brand-soft` | `#e5f5ff` | `#132c42` |
| `brand-strong` | `#0070b3` | `#7fd0ff` |
| `teacher` | `#ff8a00` | `#9a5000` |
| `school` | `#1b365d` | `#a9c4ee` |
| `team` | `#7b3aed` | `#c3a4ff` |
| `gold` | `#f39c12` | `#8c5c00` |
| `success` / `success-soft` | `#18723f` / `#e7f5ed` | `#6fd69a` / `#133a26` |
| `warning` / `warning-soft` | `#9a5200` / `#fff1dc` | `#ffbf73` / `#3a2a10` |
| `error` / `error-soft` | `#c8322b` / `#fdecea` | `#ff9a90` / `#3d1c1c` |
| ombres `card` · `lift` · `pop` | encre 4 % · 8 % · 20 % | noir 30 % · 40 % · 60 % |

`info` et `info-soft` renvoient à `brand-strong` et `brand-soft` : ils suivent sans ligne propre.

**Gabarit** — `layouts/application` déclare `<meta name="color-scheme" content="light dark">`, pour que le navigateur peigne le fond sombre avant la feuille.

**Comportement** — aucun JavaScript, aucun stockage ; le navigateur réévalue le thème quand le téléphone change de réglage.

**États obligatoires** — sans objet : chaque état des composants (vide, chargement, erreur, succès) suit ses tokens.

**Accessibilité** — chaque paire texte/fond des composants ≥ 4,5:1 dans les deux modes ; contour de focus ≥ 3:1 sur les surfaces sombres. Le test calcule les 25 paires en clair et 27 en sombre.

**Vérification** — `test/design/dark_mode_test.rb` (MS-01, 02, 05, 06, et le bloc réservé à l'écran) ; `test/system/design_system_test.rb` (MS-03, MS-04 dans un vrai navigateur) ; `test/design/design_tokens_test.rb` (MS-07).

## 4. Conséquences

- Un nouveau token de couleur entre avec sa valeur sombre, ou le test refuse.
- Un nouveau couple texte/fond dans un composant doit respecter la règle d'inversion (§2.3) ; s'il ne la suit pas, il entre dans la liste des paires du test.
- Interdit désormais : une couleur littérale dans la feuille hors des tokens et du bloc sombre, un voile ou une ombre teintés d'encre en sombre.
- Les captures de référence sont dans `docs/design/captures/mode-sombre/`.

## Amendement du 2026-10-03 — l'interrupteur clair / sombre

*Chantier [`docs/chantiers/interrupteur-theme`](../../chantiers/interrupteur-theme/prd.md). Demande du porteur du 2026-10-03. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi. La §2.1 (« pas d'interrupteur ») est levée.*

**Décision** — Un compte connecté choisit clair ou sombre ; le choix vaut pour toutes les pages de cet appareil, publiques comprises. Sans choix, l'application suit le téléphone.

**Emplacements**
- Écrans larges (`lg` et plus) : dans l'en-tête du shell, entre la pastille de rôle et l'avatar, un bouton icône `size-tap` (lune en clair, soleil en sombre), `role="switch"`, `aria-checked`, `aria-label` « Mode sombre ». Caché sous `lg`.
- Téléphone et tablette (sous `lg`) : dans « Mon profil », après la carte du PIN, une carte « Apparence » (`#profile_theme`) : libellé « Mode sombre », indication `text-sm text-mute` « Retenu sur cet appareil. », interrupteur `role="switch"` sur toute la ligne (`min-h-tap`), piste `h-7 w-12` `bg-mute` puis `bg-brand` coché, pastille `size-5 bg-white` qui glisse de `translate-x-5`. Cachée à partir de `lg`.
- Partial unique `shared/_theme_switch` (`variant: :icon | :card`). Les deux interrupteurs sont cachés (`hidden`) tant que le contrôleur `theme` n'a pas démarré.

**Comportement** — Le contrôleur `theme` pose `data-theme` (« light » ou « dark ») sur `<html>`, met la meta `color-scheme` à la même valeur, écrit le cookie `theme` (un an, `SameSite=Lax`, `Secure` en HTTPS) et prévient l'autre interrupteur de la page (`theme:changed`). Aucun rechargement. Le serveur relit le cookie (`ThemeHelper`, « light » ou « dark » seulement) et rend `data-theme` et la meta dès le HTML.

**Feuille** — Le bloc du téléphone devient `:root:not([data-theme="light"])` ; un second bloc `@media screen { :root[data-theme="dark"] }` porte exactement les mêmes valeurs. Impression toujours claire.

**Vérification** — `test/helpers/theme_helper_test.rb`, `test/controllers/theme_preference_test.rb` (IT-01, IT-02), `test/system/identity/profile_test.rb` (IT-03), `test/design/dark_mode_test.rb` (IT-04 : identité des deux blocs).

**Conséquence** — La page « Protection des données » mentionne ce second cookie (IT-05).

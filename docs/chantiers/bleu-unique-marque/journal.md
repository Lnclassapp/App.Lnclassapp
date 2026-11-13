# Journal — Bleu unique de marque

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-13 | Nouveau jeton `on-brand` (blanc, deux modes) au lieu d'élargir `band-ink` | `band-ink` est aussi l'encre du bandeau orange de l'enseignant, où le blanc ne fait que 2,2:1 | Non (UDR) |
| 2026-11-13 | `brand` identique en clair et en sombre ; `brand-strong` = texte seulement | Un jeton ne peut pas être à la fois fond à texte blanc et texte clair sur fond sombre ; c'est ce qui créait l'inversion | Non (UDR) |
| 2026-11-13 | Dégradés bleus → aplat `bg-brand` | Un seul bleu : le second ton n'existe plus | Non (UDR) |
| 2026-11-13 | Icônes PNG, favicon, JPEG et icônes Android élèves recolorées par script (mélange par pixel de trois couleurs pures), sans retouche manuelle | Fond, baobab et fentes sont des aplats ; le recoloriage est exact, sans halo | Non |
| 2026-11-13 | Exécuté par la session du chantier, sans `executant-lot` | Un lot unique de règles mécaniques mais à jugement par ligne (fond orange ou bleu, préfixe coché) ; la passation aurait perdu ce contexte | Non |

## À trancher

- [ ] 2026-11-13 · bleu-unique-marque · Le « logo d'origine » `lnclass/logo-lnclass.svg` est un « L » dans un rond (image intégrée) suivi du mot « Lnclass », pas le baobab ; il n'a pas de variante enseignant. Faut-il afficher ce « L » à la place du baobab ? — appliqué : le baobab reste, son fond passe en #0861E1 (logo, favicon, icônes PWA et Android élèves), le « L » et l'icône passent au même bleu sans être affichés ; autres : afficher le « L » pour tous (l'enseignant perd son baobab orange), ou le « L » pour l'élève et le baobab orange pour l'enseignant ; recommandé : garder le baobab (identité déjà installée sur les téléphones, variante enseignant existante).
- [ ] 2026-11-13 · bleu-unique-marque · Les icônes Android sont dans le dépôt mais l'app publiée ne change qu'au prochain build signé — appliqué : ressources mises à jour, aucun build lancé ; autres : publier un build ; recommandé : l'inclure au prochain build de la coque.

## Retouches

- Revue des tests (PR #581) : le test « fond bleu + texte blanc/noir » lisait une chaîne à la fois et laissait passer 7 formes réelles (`class_names("… text-white", "bg-brand")`, ERB imbriqué, apostrophes, `hover:`). Il lit maintenant l'instruction entière, toutes les chaînes ; il a trouvé la case de `classroom/teachings/_toggle` (coche `text-white`, sombre en mode sombre) → `text-on-brand`. Exception `/design` réduite à la seule pastille ; couleurs Android vérifiées une à une ; `subjects/generique.svg` (4 anciens bleus, hors de la liste) recoloré et ajouté à la liste.

## Ce qui a dérapé

- Remplacement global `band-ink` → `on-brand` dans les fichiers touchés : il a basculé à tort le panneau orange de l'inscription enseignant ; vu à la relecture du diff, corrigé. Leçon : `band-ink` n'est pas propre au bleu.
- Premier jeu de captures : connexions refusées par la limite de débit (une connexion par capture). Refait avec une connexion par rôle.
- Le test de garde (`brand_blue_test.rb`) a été écrit après le balayage, pas avant : il a tout de même trouvé cinq fonds `bg-brand-strong` que le balayage avait manqués (chaînes ERB imbriquées).

## Ce qu'on a appris sur la codebase

- `text-white` n'est pas du blanc : c'est la surface `white`, sombre en mode sombre. Tout texte posé sur une couleur fixe a besoin de son propre jeton.
- `logo/student.jpg` et `logo/parent.jpg` sont des copies de `logo/lnclass.jpeg`.
- `public/offline.css` est en cache chez l'élève : toute modification augmente `CACHE` dans `app/views/pwa/service-worker.js` (et les tests qui le citent).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Radios non cochées en sombre : rond plein gris | Constaté sur les captures, antérieur au chantier, hors bleu | à ouvrir si le porteur le juge utile |
| Illustration `subjects/generique.svg` en anciens bleus | Teinte de matière (UDR-0069), pas la marque | — |

## Clôture

| | |
|---|---|
| **Livré le** | — *(PR ouverte vers `Develop`)* |
| **PR** | #581 |
| **ADR produits** | — |
| **UDR produits** | UDR-0171 |

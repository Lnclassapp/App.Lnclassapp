# Memo — Installation proposée avant l'inscription, par le navigateur

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | prouvé |
| **Ouvert le** | 2026-11-25 |
| **Branche** | `fix/installation-avant-inscription` |
| **Programme** | — |

---

## Symptôme

Le porteur (2026-11-25) : « La demande d'installation sur mobile vient avant l'inscription, souvent sur la page root_path », « quand le navigateur n'est pas Chrome ».

## Reproduction

- Téléphone Android, visiteur non connecté, page d'entrée `/` (aussi `/login`, `/student-signup`) : le navigateur affiche sa propre invitation à installer Lnclass (mini-barre ou bandeau de Samsung Internet, Opera, Edge, Chrome).
- Test de reproduction : `test/system/identity/install_banner_test.rb` (l'annonce `beforeinstallprompt` simulée n'est retenue par personne sur `/`) et `test/integration/pwa_test.rb` CA-1 (la page d'entrée déclare la fiche d'application). Rouges avant le correctif.

## Portée

- Tout visiteur sur téléphone, depuis ADR-0082 (fiche d'application sur toutes les pages). Rendu seul : aucune donnée.

## Hors périmètre

- La pop-up d'installation de l'accueil connecté (UDR-0078, amendement du 2026-10-07) : inchangée.
- Safari iPhone : il n'invite jamais de lui-même ; rien à changer.

## Portes de sortie

- [x] Tests de reproduction rouges, puis verts.
- [x] `bin/ci-quiet` vert, ligne de preuve dans la PR.

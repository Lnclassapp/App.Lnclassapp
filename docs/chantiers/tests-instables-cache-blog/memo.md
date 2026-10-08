# Memo — Tests instables : cache de l'accueil de la direction et texte alternatif du blog

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-08 |
| **Branche** | `fix/tests-instables-cache-blog` |
| **Programme** | — |

---

## Le problème

Deux tests échouent par intermittence sous la charge de `bin/ci`, et passent quand on les relance seuls. Relevés pendant le chantier [`inscription-enseignant`](../inscription-enseignant/journal.md) (Lots D, F et G), sans lien avec lui. Le porteur a demandé leur correction le 2026-10-08.

### Symptômes

1. **`test/infrastructure/queries/school/direction_home_query_test.rb`**, test « AD-23: a second read within 5 minutes runs no query; … fresh at 5 min 01 s » : `Expected: 2  Actual: 1` (ligne 199). Vu 2 fois sur 6 passages complets de `bin/ci` (Lots F et G).
2. **`test/system/teams/blog_management_test.rb`**, création d'un article : le texte alternatif de la couverture est enregistré **tronqué** — « Une élève ré… », puis « …à sa tab » au lieu de « Une élève révise à sa table ». Vu 3 fois (Lot D, puis 2 passages sur 2 au Lot G) ; vert seul, et vert au passage complet suivant.

### Reproduction

1. Lancer `bin/ci` sur une machine chargée ; ou, de façon déterministe, faire durer la première lecture de l'accueil plus d'une seconde (à écrire au test de reproduction).
2. À établir par la recherche de cause (en cours) : frappe du texte alternatif de la couverture pendant que l'image du texte s'envoie.

### Portée

- Depuis le chantier `accueil-direction` (2026-10-04) pour (1) ; depuis le chantier `blog` pour (2).
- Acteurs touchés : aucun en production pour (1) (défaut du test). Pour (2) : **à trancher** — si un humain qui tape le texte alternatif pendant l'envoi d'une image perd des caractères, c'est un défaut de l'équipe (auteurs du blog), pas seulement du test.
- Données à réparer : non.

## Pour qui

Les contributeurs (une CI qui échoue au hasard coûte un `bin/ci` de 15 minutes et pousse à relancer jusqu'au vert) ; et, si (2) est un vrai défaut, l'équipe Lnclass qui écrit les articles du blog.

## Pourquoi maintenant

Ils ont fait échouer `bin/ci` pendant `inscription-enseignant` ; la CI GitHub saute ses jobs sur les PR, donc `bin/ci` local est la seule preuve avant fusion.

## Hors périmètre

- Deux lancements de tests simultanés dans le même dossier qui se partagent les bases des workers (cause du `PG::UndefinedColumn national_code` vu pendant `inscription-enseignant`) : outillage, noté au journal, pas un test instable.
- Pourquoi la CI GitHub saute ses jobs sur les PR.
- Tout autre test instable qu'on croiserait : journal, puis chantier suivant.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …

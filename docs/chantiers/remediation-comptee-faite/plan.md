# Plan d'exécution — Une remédiation compte comme exercice fait

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  ↓
  ├─► Lot A   ┐
  ├─► Lot B   ├─ en parallèle
  └─► Lot C   ┘
```

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats)
- **Fichiers**     : `db/migrate/…`
                     `app/domain/entities/<contexte>/…`
                     `app/domain/ports/<contexte>/…`
                     `config/routes.rb` · `config/locales/fr.yml` *(fichiers partagés)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/…`
- **Done quand**   : les contrats sont gelés et les lots verticaux peuvent démarrer sans se marcher dessus

---

## Lot A — [Cas d'usage complet]

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : …
- **Dépend de**    : Lot 0
- **Test associé** : …
- **Done quand**   : *(critère observable dans l'application, pas « le code est écrit »)*

---

## Lot B — [Cas d'usage complet]

- **Couche**       :
- **Fichiers**     :
- **Dépend de**    : Lot 0
- **Test associé** :
- **Done quand**   :

---

## Vérification de collision

> À remplir avant de lancer les lots en parallèle. Deux lots ne listent jamais le même fichier.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes.rb` | Lot 0 |
| `config/locales/fr.yml` | Lot 0 |

## Portes de sortie

- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat (tests lancés, parcours refait dans l'application)
- [ ] Pureté du domaine, rubocop, tests, parcours système : au vert
- [ ] ADR et UDR à jour et indexés
- [ ] `journal.md` complété

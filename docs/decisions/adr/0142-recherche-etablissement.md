# ADR-0142 : Une recherche publique bornée remplace les listes DRENA puis établissement
<!-- index
titre: Recherche d'établissement publique et bornée
statut: Accepté
problematique: Les deux listes DRENA puis établissement font se tromper les élèves ; comment trouver son établissement en tapant, sans exposer plus et sans changer les use cases ?
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-20 |
| **Chantier** | `docs/chantiers/recherche-etablissement` |
| **Remplace** | — (amende ADR-0029 §liste publique des établissements d'une DRENA, ADR-0050 débits, ADR-0085 §4.2 cascade élève) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le 2026-11-20 à Tiassalé, des élèves inscrits en classe ont choisi la mauvaise DRENA ou le mauvais établissement : deux listes natives (41 DRENA, puis des centaines d'écoles), sans recherche. Le porteur a tranché (programme `retours-terrain-tiassale`, D3) : un seul champ qui cherche parmi les 3 851 établissements actifs et affiche la DRENA à côté. Les points de vigilance du programme : établissements actifs seuls, côté serveur, 20 résultats au plus, tolérance aux accents et à l'ordre des mots (« ND paix tiassale »), repli sans JavaScript.

La liste par DRENA était publique (`GET /drenas/:id/schools`, 30 par minute et par adresse). Une classe de 40 élèves derrière une seule adresse (chantier `inscription-classe-meme-wifi`) dépasse 30 recherches en quelques secondes de frappe.

Les use cases `RegisterTeacher` et `JoinSchoolWithCode` exigent la DRENA et vérifient que l'établissement en fait partie.

## 2. Moteurs de décision

- Ne rien révéler de plus que la liste par DRENA : identifiant public, nom, DRENA ; jamais un établissement non actif.
- Ne pas toucher aux règles du domaine (inscription, rattachement) : le chantier change un choix d'interface.
- Tenir une classe sur un même wifi, sans ouvrir une énumération rapide.
- Rester sur PostgreSQL tel qu'il est (pg_trgm déjà là pour les recherches de l'équipe).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Charger les 3 851 établissements dans la page et filtrer en JavaScript | Aucun aller-retour | ~250 Ko de plus sur chaque inscription en 3G ; aucun repli sans JavaScript ; la liste entière exposée d'un coup |
| B — Recherche serveur, bornée, réponse HTML dans un Turbo Frame | Repli GET naturel ; la page reste légère ; même mécanisme que les autres listes | Un aller-retour par saisie (atténué : 300 ms d'attente, 2 lettres) |
| C — Retirer la DRENA des DTO et des use cases | Un contrat plus simple | Change le contrat de deux use cases et leurs tests pour un choix d'interface ; la DRENA déduite suffit |

## 4. Décision

> **Nous cherchons l'établissement côté serveur, dans une query de lecture publique et bornée, et nous déduisons sa DRENA à la livraison.**

1. **Query** `Queries::School::SchoolSearchQuery` : établissements `active` seulement. La saisie est normalisée comme `TextSearch` (minuscules, sans accents, `œ`/`æ` dépliés), coupée à 80 caractères et 6 mots. **Chaque mot** doit se trouver dans le nom, le sigle, le nom de la DRENA ou, pour un mot de 4 lettres au plus, les initiales du nom (« nd » ⊂ « cnddlp » de « Collège Notre-Dame de la Paix »). Ordre : les noms qui commencent par le premier mot, puis l'ordre alphabétique. **20 résultats** ; un 21e lu dit seulement « il y en a d'autres ». Moins de 2 caractères : aucune requête.
2. **Route publique** `GET /schools/search?q=&scope=` (`School::SchoolSearchesController`) : rend le cadre `school_results`, des boutons radio nommés `<scope>[school_public_id]`. Le `scope` est une liste fermée (les cinq formulaires hôtes) ; toute autre valeur vaut l'inscription élève.
3. **Débit** : 300 recherches par minute et par adresse, compteur propre (`school/search`). Une classe de 40 élèves fait environ 6 recherches chacun pour trouver son école ; une énumération reste bornée à 20 résultats par appel.
4. **DRENA déduite** : le concern `SchoolSearchField` retrouve l'établissement choisi (actif) et pose sa DRENA dans les paramètres avant le DTO. Les use cases rejugent tout, comme avant : un identifiant forgé ou devenu inactif est refusé par eux.
5. **Repli sans JavaScript** : `school_q` relu en GET par les pages hôtes ; chez l'enseignant, la recherche part d'un formulaire GET distinct, jamais avec le code secret.
6. L'ancienne route `GET /drenas/:id/schools` reste (application mobile `v1`, liens déjà ouverts) ; plus aucun écran web ne l'appelle.

## 5. Conséquences

### 🟢 Positives

- Un seul geste, la DRENA visible pour départager deux homonymes.
- Aucun use case, DTO ni port ne change ; aucune migration.
- Le même composant pour six écrans.

### 🔴 Coûts consentis

- Le filtre des initiales n'a pas d'index : la recherche lit les 3 851 lignes actives (quelques millisecondes, mesuré en test de performance existant des écrans lourds non concerné). Si la table décuple, il faudra une colonne d'initiales indexée.
- 300 par minute ouvre plus d'appels que 30 ; la réponse reste bornée et ne contient que ce que la liste par DRENA montrait déjà.
- La DRENA envoyée n'est plus un choix de la personne : la vérification « établissement de la DRENA » des use cases devient une redite côté web (elle reste utile à l'API `v1`).

## 6. Notes d'implémentation

```ruby
# app/infrastructure/queries/school/school_search_query.rb
words.each_with_index do |word, index|
  scope = scope.where("#{NAME} LIKE :p#{index} OR #{SIGLE} LIKE :p#{index} OR #{DRENA} LIKE :p#{index}" \
                      "#{" OR #{INITIALS} LIKE :p#{index}" if word.length <= INITIALS_MAX}", "p#{index}": "%#{word}%")
end
```

```ruby
# app/controllers/school/school_searches_controller.rb
rate_limit to: 300, within: 1.minute, scope: "school/search", by: -> { request.remote_ip }, with: -> { refuse_too_many }
```

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/queries/school/school_search_query_test.rb` : actifs seuls, 20 au plus, accents, ordre des mots, initiales.
- `test/controllers/school/school_searches_controller_test.rb` : public, scope fermé, 429 au-delà de 300, 40 × 6 passent.
- `grep -rn "drena_schools_path" app/views` ne renvoie plus rien.

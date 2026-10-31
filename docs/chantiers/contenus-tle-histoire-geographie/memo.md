# Memo — Les 10 premières leçons d'Histoire-Géographie de Tle (progression commune)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR) |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-tle-histoire-geographie` |
| **Programme** | `contenus-v3-tous-niveaux` (vague T8) |

---

## Le problème

Un élève de Terminale n'a aucune leçon d'Histoire-Géographie au format en vigueur : les 3 leçons rédigées (L'ONU, les fondements du développement économique de la Côte d'Ivoire, la bipolarisation) sont au format 1, retiré, copiées à l'identique dans 4 dossiers de série, et les 7 suivantes de la progression n'existent pas.

## Pour qui

- **Student** de Tle (toutes séries), qui révise avant une interrogation, un devoir ou le bac.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague T8 du programme, indépendante des autres vagues de Tle. Les sortes de figures d'HG existent (ADR-0117) : aucune sorte nouvelle.

## Hors périmètre

- Toute sorte ou paramètre de figure nouveau (aucun fond de carte « France » : la France se dessine sur le fond `world`).
- Les leçons au-delà des 10 premières, la 1ère (vague P9).
- L'import et la publication : les leçons restent en brouillon jusqu'à la relecture d'un enseignant.

## Ce que le grill a révélé

Grill court : le programme a tranché D1 à D5 ; le modèle est la vague HG 3ème (PR #374).

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Une leçon d'HG de Tle porte-t-elle une série ? | Non : la progression est commune, `valider.rb` n'attend pas de série en HG. | 10 fichiers, sans `series_name`, un cours par leçon pour toutes les séries. |
| Où ranger un cours sans série, alors que les v1 sont copiées dans `tle-a1/`, `tle-a2/`, `tle-c/`, `tle-d/` ? | Dans `lecons-traitees/tle/histoire-geographie/`, comme `1ere/` et `2nde/` pour l'HG. | Les 12 copies v1 sont retirées (D4) ; 4 copies d'un même cours sans série seraient 4 doublons à l'import. |
| La démo Saint-Michel lit l'HG dans `tle-d/` et la cherche en série D. | Elle lit aussi `tle/` et cherche un cours sans série sans série. | 1 fichier de `db/seeds/demo/` touché ; un cours sans série est déjà couvert pour une classe de Tle D (`LevelAudience`). |
| « Je m'entraîne » est-il contrôlé ? | `valider.rb` ne lit pas `practice` ; en 3ème, un test d'intégration le prouve. | Test `tle_histoire_geographie_je_m_entraine_test.rb`, copie de celui de 3ème. |
| Chiffres économiques (L2, L4, L6, L9) ? | Datés et sourcés dans le texte ; ordres de grandeur plutôt que chiffres fins. | Chaque chiffre au journal, à faire valider. |

## Cas limites identifiés

- Guerre froide, guerre d'Algérie, partis ivoiriens : faits et vocabulaire du programme, aucun jugement (neutralité comme en EDHC 3ème).
- Un chiffre sans source sûre : ordre de grandeur ou rien.

## Questions encore ouvertes

- Aucune.

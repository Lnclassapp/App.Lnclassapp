# ADR-0068 : Un import de cours complets reçoit jusqu'à 50 fichiers en un seul rapport, et l'écriture des arbres de contenu est accélérée sans changer ce qu'elle écrit
<!-- index
titre: Un import de cours complets reçoit jusqu'à 50 fichiers en un seul rapport, et l'écriture des arbres de contenu est accélérée sans changer ce qu'elle écrit
statut: Proposé — *amende 0039, 0047*
problematique: 50 fichiers, 50 Mo, 500 cours en tout ; refus par fichier ; `duplicate_in_files` d'un fichier à l'autre ; `import_reports.files` et `has_many_attached :sources` ; contenus riches sans conversion Action Text, questions et propositions par `COPY`, HTML analysé une fois ; suivi rechargé toutes les 1 s ; 500 cours en 20 s au plus (`script/bench/import_course_tree.rb`). Chantier `import-cours-multiple`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-30 |
| **Chantier** | [`docs/chantiers/import-cours-multiple`](../../chantiers/import-cours-multiple/memo.md) |
| **Amende** | [ADR-0039](./0039-format-d-import-du-contenu.md) (un fichier par import, rejet en bloc du fichier, suivi rechargé toutes les 3 s) · [ADR-0047](./0047-stockage-objet-s3-sur-railway.md) (une pièce jointe `source` par rapport) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le prompt de rédaction produit **un fichier par leçon** (`docs/contenus/prompt-redaction.md`), au format `lnclass.course-tree`. La progression 2026-2027 compte 1 056 leçons. L'ADR-0039 a fixé un fichier par import et un seul import en cours par type (index unique partiel). Pour 10 leçons, l'équipe enchaîne donc 10 envois, et chacun attend la fin du précédent. Le contournement actuel, qui fusionne les fichiers à la main avec `jq`, n'est pas à la portée de toute l'équipe.

La durée a été mesurée le 2026-09-29 sur la base de développement, par la vraie chaîne (StartImport puis le job), sur 200 cours générés à partir des 4 leçons de Tle D :

| Poste | Durée | Part |
|---|---:|---:|
| Contrôle du schéma JSON (`json_schemer`) | 1,8 s | 11 % |
| Règles métier (ContentNode, taxonomie, slugs) | 1,3 s | 8 % |
| Nettoyage du HTML (RichTextSanitizer, 600 contenus) | 3,1 s | 19 % |
| Insertion des contenus riches | 3,2 s | 19 % |
| Insertion des propositions (39 300 lignes) | 4,3 s | 26 % |
| Insertion des questions | 1,8 s | 11 % |
| Reste (cours, fiches, exercices, lecture, envoi) | 1,0 s | 6 % |
| **Total** | **16,5 s** | |

Soit 80 ms par cours, et environ 40 s pour 500 cours. Deux postes sont du travail fait deux fois :

- **Les contenus riches.** `insert_all` sur `ActionText::RichText` convertit chaque corps par le type `ActionText::Content`, ce qui analyse à nouveau un HTML que RichTextSanitizer vient d'analyser. La conversion seule coûte 3,25 s pour 600 contenus.
- **Le nettoyage.** RichTextSanitizer analyse le HTML une fois pour Loofah (élagage), puis une seconde fois pour la liste blanche de Rails. Une seule analyse donne un résultat identique (vérifié sur 50 contenus), en 2,7 s au lieu de 3,7 s.

Les propositions et les questions, elles, paient le coût d'`insert_all` ligne par ligne : conversion de chaque valeur, puis construction d'une requête de plusieurs mégaoctets. Pour les propositions, le SQL pur ne représente qu'une petite part du temps.

## 2. Moteurs de décision

1. **Un geste pour un dossier de leçons** : choisir N fichiers, lire un seul bilan.
2. **Ne rien changer aux règles de l'import** (ADR-0039) : doublons ignorés, jamais de mise à jour, un cours entier ou absent, tout en brouillon, validation complète avant la moindre écriture.
3. **Ce qui est écrit ne change pas d'un octet** : l'accélération se prouve en comparant les lignes écrites avant et après.
4. **Pas de nouvelle pièce mobile** : ni connexion en direct, ni processus supplémentaire, ni nouvelle gemme.
5. **Toucher le moins possible aux quatre autres types** : établissements, DRENA, fiches et exercices restent à un fichier.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — N fichiers = N rapports, traités à la file | Chaque rapport reste celui d'aujourd'hui | Il faut lever l'index « un import en cours par type ». N bilans à relire. Chaque fichier attend en plus la prise en charge du travail (jusqu'à 1 s). Refusé au grill |
| B — Fusionner les fichiers dans le navigateur avant l'envoi | Aucun changement serveur | Un fichier illisible ferait échouer tout l'envoi, les erreurs ne sauraient plus de quel fichier elles viennent, et le fichier conservé ne serait plus celui de l'équipe |
| **C — N fichiers = un rapport, un passage du moteur** | Un traitement, un bilan. Les adaptateurs des types ne changent pas | Le moteur apprend à lire une liste de documents, et le rapport à garder un bilan par fichier |
| D — Paralléliser la validation et le nettoyage entre processus | Environ 5 s de plus gagnées sur 500 cours | Un moteur plus complexe, plus de mémoire, rien de gagné sous 50 cours. Écarté au grill |
| E — Écrire les contenus riches en passant par le modèle Action Text, un par un | Callbacks et conversions d'Action Text respectés | 600 requêtes au lieu d'une. C'est l'inverse du but |

## 4. Décision

> **Nous acceptons jusqu'à 50 fichiers, 50 Mo au total et 20 Mo par fichier dans un import de cours complets. Ils forment un seul rapport, traité en un seul passage du moteur : un fichier illisible est refusé seul, le plafond de 500 cours vaut pour l'ensemble, et un cours présent dans deux fichiers est en erreur dans les deux. Le rapport garde un bilan par fichier. L'écrivain des arbres de contenu n'analyse plus le HTML qu'une fois, écrit les contenus riches sans conversion Action Text, et écrit questions et propositions par `COPY`. Le suivi se recharge toutes les secondes.**

**Registre des types.** `ImportKind::Definition` gagne `max_files` et `max_total_bytes` : 50 fichiers et 50 Mo pour `course_tree`, 1 fichier et 20 Mo pour les quatre autres types. Seul un type **sans cible** (`target_key: nil`) peut accepter plusieurs fichiers : le registre le vérifie à son chargement. `MAX_BYTES` (20 Mo) reste la limite **par fichier**.

**Envoi.** La forme d'un envoi (`Dtos::Catalog::ImportUploadInput`) porte une liste de fichiers `{ io, filename }`, de 1 à `max_files`. Chaque fichier finit par `.json` et pèse au plus 20 Mo, et la somme ne dépasse pas `max_total_bytes`. Sinon : 422, sans rapport. `checksum_sha256` du rapport est l'empreinte du fichier quand il n'y en a qu'un. Avec plusieurs fichiers, c'est l'empreinte SHA-256 de leurs empreintes jointes par `\n`, dans l'ordre d'envoi.

**Stockage.** `Orm::ImportReport` passe de `has_one_attached :source` à `has_many_attached :sources`. Une migration renomme les pièces jointes existantes (`active_storage_attachments.name` : `source` → `sources`). Le port `ImportFileStorePort` attache une liste de fichiers et relit une liste de `Entities::Catalog::ImportFile` (`name`, `content`), dans l'ordre d'envoi. Tous les fichiers sont conservés, comme le fichier unique aujourd'hui (ADR-0047).

**Moteur (`UseCases::Catalog::RunImport`).** Pour chaque fichier, dans l'ordre :

1. Lecture et enveloppe. JSON illisible, autre format ou autre version : **ce fichier** est refusé (`json_invalid`, `format_mismatch`, `version_unsupported`), et ses cours ne sont pas comptés. Le rapport n'est `rejected` que si **tous** les fichiers le sont. Pour un seul fichier, c'est exactement le rejet en bloc d'aujourd'hui.
2. Schéma, par fichier. Les erreurs sont rattachées à la racine de ce fichier.
3. Après tous les fichiers : si la somme des cours lisibles dépasse `max_roots`, le rapport est `rejected` (`too_many_roots`), sans écriture.
4. Validation métier de chaque cours (adaptateur inchangé), puis doublons, dans cet ordre : **déjà en base** → ignoré ; **répété dans le même fichier** → le second est ignoré ; **présent dans deux fichiers ou plus** → en erreur dans chacun (`duplicate_in_files`, `params: { other: "<nom de l'autre fichier>" }`). L'ordre des fichiers ne change pas le résultat.
5. Écriture par lots de 100, avec rejeu élément par élément : inchangée.

Une erreur porte le **nom d'affichage** de son fichier (`Entities::Catalog::ImportError#file`) dès que l'envoi compte plusieurs fichiers. Sinon ce nom vaut `nil`, et les chemins restent ceux d'aujourd'hui (`courses[1].material_name`). Deux fichiers du même nom s'affichent « cours.json » et « cours.json (2) », dans l'ordre d'envoi.

**Rapport.** `import_reports.files` (`jsonb`, défaut `[]`) liste, dans l'ordre d'envoi, pour chaque fichier : `name` (nom d'affichage), `byte_size`, `status` (`pending` à la création, puis `read` ou `rejected`), `reason` (`{ code, params }` si refusé), `imported`, `skipped`, `errors` (`Entities::Catalog::ImportFileReport`). Les noms sont posés **dès la création** du rapport (`ImportReportRepositoryPort#create(files:)`). L'historique et le suivi les lisent donc dans cette colonne, sans jointure sur les pièces jointes. Le bilan est écrit à la fin (`finish(files:)`). Une erreur de schéma sur la racine d'un fichier, ou une cible inconnue, refuse aussi ce seul fichier. Les compteurs globaux, `details` et `import_errors` ne changent pas de forme.

**Écriture accélérée (`Repositories::Catalog::ContentTreeWriter`), sans changer une ligne écrite :**

- Les contenus riches s'insèrent par un modèle d'écriture sans type Action Text sur `body` (`Orm::RichTextRow`, table `action_text_rich_texts`). Le corps stocké est la chaîne déjà assainie.
- Les exercices et les questions reçoivent des identifiants réservés d'avance (`nextval` sur leur séquence, en une requête). Exercices, questions et propositions s'écrivent ensuite par `COPY … FROM STDIN` dans la transaction du lot. Contraintes et index s'appliquent comme pour un `INSERT`. Une erreur de `COPY` est traduite dans les mêmes exceptions qu'`insert_all!` (`RecordNotUnique`, `CheckViolation`, `ValueTooLong`), pour que le moteur rejoue toujours le lot élément par élément. Les exercices ne figuraient pas dans le plan initial : ils ont été ajoutés au Lot B pour garder une marge sur une machine chargée.
- RichTextSanitizer analyse le HTML une seule fois : élagage Loofah (`:prune`), puis le filtre de la liste blanche de Rails (`Rails::HTML::PermitScrubber`), sur le même fragment.

**Suivi.** Le contrôleur Stimulus `teams--import-status` recharge le frame toutes les **1 s**, au lieu de 3 s, tant que l'import tourne. Il n'y a toujours ni WebSocket ni diffusion (ADR-0039 inchangé sur ce point).

## 5. Conséquences

### 🟢 Positives

- Une matière entière de leçons s'importe en un envoi, avec un bilan qui dit quel fichier renvoyer.
- 500 cours en 20 s au plus, au lieu d'environ 40 s. Tous les imports de cours complets en profitent, même d'un seul fichier.
- Le bilan d'un petit import s'affiche en 1 à 2 s. Tous les types de rapport en profitent, y compris la génération des classes manquantes.
- Les quatre adaptateurs de types ne changent pas : le moteur porte seul la notion de fichier.

### 🔴 Coûts consentis

- **Une migration de données Active Storage** : renommer `source` en `sources` sur les pièces jointes des rapports existants. Elle est sans risque aujourd'hui (aucune production), mais elle ne se rejoue pas à l'envers sans perte si un rapport a plusieurs fichiers.
- **`COPY` sort d'ActiveRecord.** Il faut encoder soi-même les valeurs, texte et booléens, au format `COPY`. Un caractère mal échappé (tabulation, retour à la ligne, `\`) corromprait une ligne. Un test dédié écrit ces caractères et les relit.
- **Deux chemins d'écriture des contenus riches** : le modèle Action Text pour les formulaires, `Orm::RichTextRow` pour l'import. S'ils divergent, le corps stocké diffère. Le test IM-13 compare octet par octet.
- **Un envoi de 50 Mo passe par Rails** avant d'aller au bucket, et non par un envoi direct du navigateur. C'est plus lent sur une connexion faible. La limite du proxy d'entrée de l'hébergeur n'est pas documentée : elle est vérifiée en recette, et abaissée si besoin.
- **Rafraîchir toutes les secondes triple les requêtes de suivi** tant qu'un import tourne. Elles sont légères (une ligne, un partial), et elles s'arrêtent à la fin.
- **La traduction des erreurs de `COPY` passe par une API privée d'ActiveRecord** (`connection.send(:translate_exception_class, …)`). Une montée de version de Rails peut la casser. Les tests des trois contraintes le verraient.
- **Le nettoyage en une seule analyse n'est pas identique dans des cas extrêmes.** Sur tout le contenu réel, le résultat est identique octet pour octet. Mais un test sur 20 000 HTML aléatoires a trouvé 16 écarts : un saut de ligne en tête de `<pre>`, que l'ancienne seconde analyse supprimait ; et des `<h2>` imbriqués après le retrait d'une balise non permise. Le DOM rendu par le navigateur est le même, sauf pour un `<pre>` suivi de trois sauts de ligne ou plus.
- **La règle `duplicate_in_files` ne vaut que d'un fichier à l'autre** : dans un même fichier, un doublon reste ignoré. C'est une asymétrie assumée, parce que deux fichiers sont sans doute deux versions d'une leçon.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/catalog/import_kind.rb
Definition = Data.define(:kind, :format, :version, :roots_key, :target_key, :target_required, :max_roots, :policy,
                         :max_files, :max_total_bytes) do
  def authorize(actor:) = policy.new.call(actor:)
  def multiple_files? = max_files > 1
end
# course_tree : max_files: 50, max_total_bytes: 50 * 1024 * 1024 ; les autres : 1 et MAX_BYTES.
# Garde au chargement : raise ArgumentError si un type a une cible et max_files > 1.
```

```ruby
# app/domain/entities/catalog/import_error.rb — le fichier est facultatif, nil pour un envoi d'un seul fichier
ImportError = Data.define(:path, :code, :params, :file) do
  def initialize(path:, code:, params: {}, file: nil) = …
end
ImportError::ELEMENT += %w[duplicate_in_files]
```

```ruby
# app/infrastructure/repositories/catalog/rich_text_sanitizer.rb — une seule analyse
SCRUBBER = Rails::HTML::PermitScrubber.new.tap do |scrubber|
  scrubber.tags = Rails::HTML5::SafeListSanitizer.allowed_tags
  scrubber.attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes
end
def self.call(html) = html && Loofah.html5_fragment(html).scrub!(:prune).scrub!(SCRUBBER).to_s
```

```ruby
# app/infrastructure/repositories/catalog/content_tree_writer.rb — questions et propositions par COPY
ids = connection.select_values("SELECT nextval('questions_id_seq') FROM generate_series(1, #{questions.size})")
connection.raw_connection.copy_data("COPY questions (id, exercise_id, position, content, explanation, question_type, created_at, updated_at) FROM STDIN") do
  rows.each { |row| connection.raw_connection.put_copy_data(CopyRow.encode(row)) }
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/catalog/import_kind_test.rb` : 50 fichiers et 50 Mo pour `course_tree` seulement ; un type avec cible et plusieurs fichiers lève une erreur.
- `test/domain/use_cases/catalog/run_import_test.rb` : refus par fichier, rejet quand tous les fichiers sont refusés, plafond global, `duplicate_in_files`, ordre des fichiers sans effet, chemins sans fichier quand il n'y en a qu'un (IM-02 à IM-06, IM-08).
- `test/infrastructure/repositories/catalog/content_tree_writer_characterization_test.rb` : les 4 leçons de Tle D écrites par l'écrivain donnent des lignes identiques à l'instantané pris **avant** l'optimisation (IM-13). Le test d'échappement `COPY` écrit tabulation, retour à la ligne, `\` et `$\frac{1}{2}$`.
- `script/bench/import_course_tree.rb` : 500 cours en 20 s au plus (IM-14). Hors CI, rejoué par le challenger, avec les chiffres reportés dans le PRD §7.

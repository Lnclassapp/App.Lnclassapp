# Memo — Accélération du flux : numéros de décision posés à la fusion, migrations en deux temps, retour arrière

| | |
|---|---|
| **Type de cycle** | refactoring (outillage et règles du processus, sans effet sur l'application) |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-20 |
| **Branche** | `refactor/acceleration-du-flux` |
| **Programme** | — |

---

## Le problème

L'[audit du 2026-10-20](audit.md) chiffre le flux, de la conception au déploiement. Ce chantier traite les trois pistes « Tout de suite », qui ne demandent aucune décision produit :

1. **Collisions de numéros** (audit §2.1). Un chantier prend le prochain numéro d'ADR ou d'UDR libre dès son ouverture. Deux chantiers ouverts en parallèle prennent donc le même numéro, et le second doit renuméroter avant de fusionner. Cela a coûté 5 commits de renumérotation, dont « ADR-0104 devient ADR-0105 » (`images-dans-les-cours`).
2. **Livraison sans retour possible** (audit §2.7). La PR #268 a recopié `teacher_profiles.material_id` vers `teacher_school_materials` et supprimé la colonne dans la même livraison. Si la recopie avait eu un défaut, revenir à l'image précédente aurait trouvé une base sans la colonne.
3. **Aucun plan de retour arrière écrit.** Le 2026-10-20, Railway a mis en pause les nouveaux déploiements. Rien ne dit comment revenir à une image antérieure, ni quoi faire quand le fournisseur est arrêté.

## Pour qui

Le porteur et les agents qui ouvrent, livrent ou déploient un chantier. Aucun acteur de l'application n'est concerné.

## Pourquoi maintenant

Les deux décisions qui restent (feature flags avec une PR par lot, et le sort de `Staging`) vont multiplier les chantiers parallèles et les livraisons. Les collisions de numéros et les suppressions sans retour possible grandissent avec elles.

## Hors périmètre

- Les feature flags et la règle « une PR par lot » (audit §2.2) : en attente d'une décision du porteur.
- Le test de fumée de `Staging` ou sa suppression (audit §2.3) : en attente d'une décision du porteur.
- Renuméroter les 106 ADR et 131 UDR existants : un numéro déjà posé ne bouge plus.
- Une gem de contrôle des migrations (`strong_migrations` ou autre) : la garde est un test du dépôt, comme `test/guards/`.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qui pose le numéro, et quand ? | `script/docs/build_index --number`, au commit de clôture du chantier, sur la branche, juste avant la fusion | Il n'y a plus de numéro à choisir à l'ouverture. Deux chantiers ne se croisent qu'à la fusion, et le second relance `--number` après avoir fusionné `Develop` |
| Comment un document cite une décision avant qu'elle ait son numéro ? | `ADR-XXXX-<slug>`, avec un lien vers `XXXX-<slug>.md` | `--number` réécrit ces références partout où elles apparaissent |
| Et si un `XXXX-` arrive sur `Develop` ? | `build_index --check` le refuse sur `Develop`, `Staging` et `main` | Il n'y a pas de fichier `XXXX-` dans l'historique des branches longues |
| Une suppression seule est-elle permise ? | Oui : la colonne a été vidée dans une livraison précédente | La garde ne refuse que l'ajout ou la recopie **et** la suppression dans la même livraison |
| Qu'est-ce qu'une livraison, pour la garde ? | Les migrations absentes de `origin/main` | C'est ce que le prochain passage vers `main` déploiera |
| Et un cas où les deux temps ne servent à rien (table neuve jamais lue) ? | Un commentaire `# migration-en-deux-temps: <raison>` lève la garde | L'exception est écrite dans la migration, et elle se relit |

## Cas limites identifiés

- Un chantier qui crée deux ADR et une UDR : chacun reçoit son numéro, dans l'ordre alphabétique des slugs.
- Une référence `ADR-XXXX-<slug>` dans un fichier hors de `docs/` (`app/`, `test/`, `.claude/`) : elle est réécrite aussi.
- Git ne peut pas comparer à `origin/main` (clone superficiel) : la garde des migrations joue sur toutes les migrations du dépôt, par sécurité, comme `config/ci.rb`.

## Questions encore ouvertes

- Les commandes Railway exactes du retour arrière (tableau de bord ou CLI) : à vérifier par le porteur, le lot C les signale comme telles.

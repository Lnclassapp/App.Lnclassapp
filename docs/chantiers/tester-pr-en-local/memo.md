# Memo — Tester une PR sur sa machine

| | |
|---|---|
| **Type de cycle** | feature (outillage du porteur, sans effet sur l'application) |
| **Statut** | livré |
| **Ouvert le** | 2026-10-21 |
| **Branche** | `feature/tester-pr-en-local` |
| **Programme** | — |

---

## Le problème

Le porteur veut essayer une PR avant de la fusionner, sur son ordinateur et sur son téléphone. Trois voies ont été écartées le 2026-10-20 et le 2026-10-21 :

- **Environnements de PR Railway** : une application et une base PostgreSQL par PR ouverte. Trop cher pour le porteur ; le mode serverless n'y change presque rien, car le worker Solid Queue dans Puma (ADR-0052) garde l'application éveillée.
- **Tunnel public depuis la session cloud de l'agent** : le proxy du conteneur ne laisse sortir que du HTTPS sur le port 443. Le tunnel Cloudflare obtient une URL qui répond 530.
- **Railway inaccessible** au porteur depuis le 2026-10-20.

## Ce que le chantier livre

`bin/tester-pr <numéro-de-PR | branche>` récupère le code tel qu'il est sur `origin`, détaché pour ne laisser aucune branche locale. Il installe les dépendances et joue les migrations de ce code (`bin/setup --skip-server`), sème les comptes fictifs (`bin/rails db:seed`), puis lance `bin/dev`.

- `--telephone` ouvre le serveur au réseau local (`BINDING=0.0.0.0`) et affiche l'adresse à taper sur le téléphone.
- `--reset` recrée la base de développement.
- `--demo` ajoute trois établissements de test (`db/seeds/demo/trois_etablissements.rb`, demande du porteur du 2026-10-21) : 3 classes par niveau de la 6ème à la Tle, de 35 à 45 élèves par classe, les 6 enseignants de chaque classe (EDHC au collège, philosophie au lycée), 2 enseignants bivalents par établissement, un enseignant dans les trois établissements et un dans deux. Insertions groupées : 4 secondes pour 2 555 élèves et 63 enseignants.
- `--activite` ajoute le Collège Saint Michel de `db/seeds/demo/saint_michel.rb`, dont les élèves ont déjà travaillé. Il passe par les vrais use cases et prend environ 20 minutes la première fois. Il était cassé sur `Develop` (argument `illustrations:` manquant, champ `visible_until` disparu) : réparé dans ce chantier.

## Hors périmètre

- Windows sans WSL : le script est en bash.
- Les environnements de PR Railway et le tunnel public : écartés, voir plus haut.

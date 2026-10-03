# ADR-0045 : Annonces de la V6a — publication programmée par job, audience filtrée à la lecture, rejets en base, pièces jointes validées

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-23**, bloque la V6 |
| **Remplace** | — |
| **Remplacé par** | — *(amendé par [ADR-0069](./0069-annonces-trois-auteurs-classes-ciblees-et-retrait.md) le 2026-10-03, accepté le même jour : §4 et §7)* |

---

## 1. Contexte et problématique

Dans l'ancien, les annonces (`messages`) ont quatre défauts :

- **Programmation inerte** : le statut `scheduled` existe, mais aucun job ne publie à l'heure prévue.
- **Audience ignorée** : `show` affiche n'importe quelle annonce à n'importe qui ; l'audience `teams` existe, mais pas `school_admin`.
- **Rejets fragiles** : ils sont stockés dans un cookie et se perdent en changeant d'appareil.
- **Pièces jointes sans contrôle** : images et audio sont sur le disque éphémère du conteneur, sans validation, et aucun index n'existe.

L'ADR-0010 promettait des notifications temps réel par Solid Cable, jamais écrites (**C-37**, part « temps réel »). La messagerie de classe et le temps réel sont retirés du plan le 2026-09-22.

## 2. Moteurs de décision

1. Une annonce n'est lue que par son audience, y compris par son URL.
2. Programmer une annonce produit une publication à l'heure dite.
3. « Ne plus afficher » vaut sur tous les appareils.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Filtre horaire à la lecture, sans job | Aucun job | L'état en base ment : `scheduled` reste affiché après l'heure |
| B — **Job récurrent qui publie** | L'état dit la vérité ; auditable | Un job de plus |

## 4. Décision

> **Nous publions les annonces programmées par un job récurrent, nous filtrons l'audience dans la query et dans la policy, nous stockons les rejets en base, et nous validons les pièces jointes stockées sur le bucket de l'ADR-0047.**

**Table `messages`** (contexte `communication`) :

| Colonne | Contrainte |
|---|---|
| `public_id` | ADR-0029 |
| `author_id` | `NOT NULL`, FK `users` |
| `title` | `string(120) NOT NULL` |
| `body` | `text NOT NULL`, texte simple rendu échappé |
| `audience` | `CHECK IN ('all','students','teachers','school_admins')` |
| `school_id` | FK `NULL` : `NULL` pour une annonce nationale |
| `status` | `CHECK IN ('draft','scheduled','published','archived')` |
| `published_at` | `datetime NULL` |

Contrainte : `CHECK (status NOT IN ('scheduled','published') OR published_at IS NOT NULL)`. Index `(status, published_at)` et `(school_id)`. Le slug de l'ancien n'est pas repris.

**Publication** :

- `Communication::PublishMessage` publie immédiatement, ou programme si `published_at` est dans le futur.
- Le job `Communication::PublishScheduledMessagesJob` tourne toutes les 5 minutes (`config/recurring.yml`, worker de l'[ADR-0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md)). Il fait passer `scheduled` à `published` quand `published_at <= now`, et journalise `message.published`.
- `Communication::ArchiveMessage` archive.

**Droits** (`Communication::PublishPolicy`) :

`team` : annonce nationale ou d'école, toute audience. `school_admin` : **son** école seulement, audience `students`, `teachers` ou `school_admins`. `teacher` et `student` : aucun droit.

**Lecture** (`Queries::Communication::InboxQuery` et `Communication::ReadPolicy`) : une annonce est visible si elle est `published`, si son audience couvre le rôle de l'acteur (`all` couvre tout le monde), et si `school_id` est `NULL` ou égal à l'école de l'acteur. L'école d'un élève est celle de sa classe principale active. `show` applique la même policy ; sinon, 404.

**Rejets** : table `message_dismissals` (`message_id` FK en `cascade`, `user_id` FK, `dismissed_at`), index unique `(message_id, user_id)`. Le cookie n'est pas repris.

**Pièces jointes** : Active Storage sur le bucket de l'ADR-0047. Au plus une image et un fichier audio par annonce.

| Type | Formats | Taille maximale |
|---|---|---|
| `image` | `image/png`, `image/jpeg`, `image/webp` | 2 Mo |
| `audio` | `audio/mpeg`, `audio/mp4` | 10 Mo |

Le type est déterminé par le contenu (Marcel, utilisé par Active Storage), pas par l'extension. Tout autre fichier donne `:invalid`.

**Hors périmètre** : messagerie de classe, notifications temps réel et envoi SMS.

## 5. Conséquences

### 🟢 Positives

- L'audience est respectée par l'URL comme par la liste.
- Les rejets suivent l'utilisateur d'un appareil à l'autre.
- Les pièces jointes survivent aux déploiements (ADR-0047).

### 🔴 Coûts consentis

- La publication programmée a jusqu'à 5 minutes de retard.
- Pas de mise en forme riche : le corps est du texte simple.
- Sans notification poussée, une annonce n'est vue qu'à la prochaine visite.

## 6. Notes d'implémentation

```yaml
# config/recurring.yml
production:
  publish_scheduled_messages:
    class: Communication::PublishScheduledMessagesJob
    schedule: every 5 minutes
```

## 7. Comment vérifier que la décision est respectée

- Test de job : une annonce `scheduled` dont `published_at` est passé devient `published` ; une annonce future reste `scheduled`.
- Tests d'intégration : un élève sur l'URL d'une annonce `teachers` reçoit 404 ; un `school_admin` de l'école A sur une annonce de l'école B, 404.
- Test de use case : un PDF déguisé en `.png` donne `:invalid`.

## 8. Remplace, complète, amende

- Ne remplace aucun ADR. Il **ferme** C-37 pour le temps réel, retiré du plan, et **corrige** le glossaire §6 (audiences, slug).

## 9. Points à confirmer par le porteur

- Pas d'audience `teams` : l'équipe voit tout.
- Le corps est en texte simple, sans éditeur riche.
- Tailles maximales : 2 Mo pour une image, 10 Mo pour un fichier audio.

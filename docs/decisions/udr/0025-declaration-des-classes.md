# UDR-0025 : Déclaration des classes — une bascule par classe, enregistrée à chaque clic, compteur par Turbo Stream, onboarding terminé par un bouton

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot D2, critères CL-09, TR-08 (remplacé), TR-02 |
| **ADR lié** | [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) (école principale, déclaration des classes) · [ADR-0041](../adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) (année scolaire) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Juste après son inscription (UDR-0024), un enseignant arrive sur « Quelles classes enseignez-vous ? » (`/teachers/classrooms`). Tant qu'il n'a pas terminé cette étape, son accueil le ramène ici. Dans l'ancienne application :

- les cases à cocher n'enregistraient rien : tout partait d'un coup avec « Terminer », et ce formulaire rechargeait la page (`turbo: false`). Une erreur faisait perdre la sélection ;
- le compteur et le bouton étaient tenus par un contrôleur Stimulus, qui pouvait afficher un autre nombre que celui enregistré ;
- la soumission **remplaçait** toutes les classes de l'enseignant, y compris celles d'un autre établissement ;
- les niveaux étaient triés par ordre alphabétique (« 1ère » avant « 6ème ») et les classes aussi (« 4ème 10 » avant « 4ème 2 ») ;
- l'onboarding se déduisait de `classrooms.empty?`. Un enseignant qui retirait toutes ses classes retombait dans l'onboarding. Sans école, il tournait en boucle entre `/` et `/teachers/classrooms` (TR-02) ;
- un écran `/teachers/setup` (TR-08) existait, mais aucun lien n'y menait.

## 2. Décision

1. **Une bascule par classe, enregistrée au clic.** Chaque classe est un bouton `aria-pressed` dans son propre petit formulaire : `POST` pour la déclarer, `DELETE` pour la retirer. La réponse Turbo Stream remplace la bascule (en morphing, le focus reste sur le bouton) et le compteur. Il n'y a ni rechargement de page ni Stimulus : le compteur vient du serveur, il dit toujours ce qui est enregistré.
2. **Pas de toast à chaque bascule.** Le changement d'état de la bascule et le compteur, annoncé par `aria-live`, suffisent. Un toast par clic empilerait des messages pendant qu'on coche six classes. C'est un écart assumé avec la règle Hotwire n° 3 du plan : le lot demande seulement « bascule et compteur ».
3. **Retirer une classe ne fait que ça.** La déclaration disparaît, mais les assignations de l'enseignant et les sessions des élèves restent.
4. **L'onboarding est un état enregistré** (`teacher_profiles.onboarding_completed_at`). « Terminer la configuration » l'enregistre et mène à l'accueil enseignant (`/teachers`), avec le toast « Vos classes sont enregistrées. Bienvenue dans votre espace ! ». Sans aucune classe déclarée, la page revient en 422 avec « Sélectionnez au moins une classe. ». Une fois l'onboarding terminé, la page reste accessible depuis la navigation pour changer ses classes. Le bouton y devient « Retour à l'accueil ».
5. **Seulement les classes que l'on peut déclarer** : les classes actives de l'école principale et de l'année scolaire en cours, groupées par niveau. Les niveaux sont triés par position, les classes par nom dans l'ordre naturel (« 6ème 2 » avant « 6ème 10 »). Une requête qui vise la classe d'une autre école ou une classe archivée reçoit 403, et rien ne change.
6. **Pas de « Tout cocher » par niveau.** Il demandait du JavaScript ou une écriture groupée. Déclarer se fait en un clic par classe, et un enseignant a rarement plus de six classes.
7. **TR-08 remplacé** : cet écran est l'unique onboarding enseignant. `/teachers/setup` n'est pas repris.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Route : `GET /teachers/classrooms` (`teacher_classrooms_path`), `allow_roles :teacher`. Sans école principale : redirection vers `pending_account_path`, l'écran de sortie, qui ne redirige jamais.
- `classroom/teaching_selections/index` : `ui_page_header`, avec pour titre « Quelles classes enseignez-vous ? » et pour sous-titre « Sélectionnez vos classes dans l'établissement … ». Viennent ensuite une `ui_card` par niveau (`_level_group`, titre `h2` = nom du niveau, sous-titre = « n classe(s) »), puis la barre de fin (`border-t`) : le compteur à gauche, l'action à droite.
- `_level_group` : `ul.grid` (1 colonne, 2 à partir de `sm`, 4 à partir de `lg`), un `li` par classe, qui rend `classroom/teachings/_toggle`.
- `_toggle` : `button_to classroom_teaching_path(public_id)`, formulaire `form#teaching_<public_id>`, méthode `delete` si la classe est déclarée, `post` sinon. Le bouton porte `aria-pressed`, le nom de la classe et une icône (`check-circle` pleine si déclarée, `plus-circle` sinon).
- `_counter` : `p#teaching_counter[aria-live=polite]`, « Aucune classe sélectionnée », « 1 classe sélectionnée » ou « n classes sélectionnées ».
- Action : `form#teacher-onboarding-form` (`POST /teachers/onboarding`) et son bouton « Terminer la configuration » (`ui_button` `brand` `lg`), tant que l'onboarding n'est pas terminé. Ensuite : « Retour à l'accueil » (`ui_button` `secondary`, lien vers `teacher_home_path`).

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement. Bascule : `rounded-ln border min-h-tap` ; déclarée : `border-brand bg-brand-soft`, icône `text-brand-strong` ; non déclarée : `border-line bg-white`, survol `hover:border-brand/40 hover:bg-mist`, icône `text-mute`. Erreur : `bg-error-soft text-error`. Aucune classe de l'ancienne application.

**Comportement**
- `create.turbo_stream.erb` et `destroy.turbo_stream.erb` font un `replace` de `teaching_<public_id>` (`method: morph`) et un `replace` de `teaching_counter`. Aucun toast.
- Repli sans Turbo : redirection vers `/teachers/classrooms` avec « 6ème 1 fait partie de vos classes. » ou « … ne fait plus partie de vos classes. ».
- Refus (autre école, classe archivée) : 403, toast « Accès interdit. » ; classe inconnue : 404.
- « Terminer » : succès → `303` vers `/teachers` ; aucune classe déclarée → la même page en 422, avec l'erreur au-dessus du bouton.

**États obligatoires**
- Vide : école sans classe active cette année → `ui_empty_state` « Aucune classe ouverte cette année », sans compteur ni bouton.
- Chargement : Turbo marque le formulaire soumis `aria-busy`.
- Erreur : `p#teacher-onboarding-error[role=alert]`, relié au bouton par `aria-describedby`.
- Succès : bascule et compteur à jour ; toast sur l'accueil après « Terminer ».

**Accessibilité**
- Chaque bascule est un vrai `<button>` avec `aria-pressed` : le lecteur d'écran annonce « 6ème 1, bouton bascule, activé ». Le focus reste sur le bouton après la réponse (morphing).
- Cibles tactiles ≥ 48 px (`min-h-tap`) ; parcours prouvé à 390 px.

## 4. Conséquences

- L'accueil enseignant (Lot D3) renvoie ici tant que `onboarding_completed_at` est nul. Il ne regarde jamais le nombre de classes déclarées.
- Aucune autre page ne déclare ni ne retire une classe : c'est l'unique point d'entrée de `teacher_classrooms` pour l'enseignant.
- Une école sans classe cette année bloque l'onboarding. C'est voulu : les classes viennent de l'import des établissements (ADR-0030), jamais de l'enseignant.

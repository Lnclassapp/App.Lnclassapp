# UDR-0012 : Landing — deux entrées de rôle, une modale chacune, aucun lien sans route

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) — *amendé par l'UDR-0059 le 2026-10-02* |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot A4, critères TR-01, TR-03 |
| **ADR lié** | [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (quatre badges) · [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (polices servies par l'application) · [UDR-0005](0005-design-system-fondateur.md) (tokens, `ui_modal`) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) · [UDR-0009](0009-rejoindre-une-classe.md) (porte de l'élève) |
| **Remplacé par** | — |

> ℹ️ **Amendée par l'[UDR-0059](0059-homepage-telephone-et-tablette.md)** (acceptée le 2026-10-02) : cette UDR ne gouverne plus que la landing **à partir de 1 024 px**, sans la section « Rejoindre ».

---

## 1. Contexte

La landing est la seule page publique. Un visiteur y arrive sans savoir par où entrer. Dans l'ancienne application :

- deux boutons, « Je suis élève » et « Je suis enseignant », ouvraient chacun une modale « Se connecter / S'inscrire » (TR-01), par deux contrôleurs Stimulus recopiés l'un de l'autre ;
- l'élève « s'inscrivait » par `/student-signup`, une cascade qui permettait de rejoindre une classe sans son code (ID-08) ;
- un bouton « Espace Etabl. » pointait vers la chaîne littérale `etabl`, qu'aucune route ne déclare (TR-03).

La première landing de la refonte, elle, portait l'identité visuelle (UDR-0005) mais promettait des parents, des établissements, des devoirs et des messages que la V1 ne livre pas, et ses boutons « Créer mon compte » ne menaient nulle part.

## 2. Décision

1. **Deux entrées, et seulement deux** : « Je suis élève » et « Je suis enseignant ». Ce sont les deux rôles qui peuvent entrer seuls en V1. Aucun espace établissement ni parent n'est proposé (TR-03 : V2).
2. **Chaque entrée ouvre une modale** (`ui_modal`, contrôleur Stimulus `modal` du socle) plutôt qu'une page : le visiteur choisit sans quitter la landing, et la modale ne demande aucun aller-retour serveur. Le contenu est statique ; il n'y a ni frame, ni stream.
3. **La modale élève** propose « Se connecter » et « Rejoindre ma classe ». L'élève n'a pas d'inscription autonome : le code de classe est sa seule porte (UDR-0009).
4. **La modale enseignant** propose « Se connecter » et « Créer un compte » (inscription enseignant, D1).
5. **Aucun lien vers une chaîne littérale** : chaque lien est un helper de route, ou une ancre vers une section de la page. Un test le vérifie à chaque exécution (reconnaissance par le routeur, ancre existante, aucun bouton sans action).
6. **Le contenu dit la V1** : le slogan de l'ancienne application (« Avec Lnclass, tu comprends chap chap ! »), les matières, les exercices corrigés, les quatre badges (ADR-0033), l'espace enseignant. La structure de l'ancienne page (héros, deux entrées, matières, quatre fonctionnalités) est reprise ; ses couleurs ne le sont pas.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `homepage/index` : en-tête (logo, ancres « Pour qui ? », « Fonctionnalités », « Comment ça marche », « Se connecter » → `new_session_path`, « Commencer » → `#rejoindre`), puis :
  - `section#hero` : pastille « Programme officiel, de la 6e à la Terminale », `h1`, chapeau, les deux entrées, la photo et sa carte « Badge Or obtenu » (icône `trophy` sur `bg-gold/20`) ;
  - bande des matières : `ui_subject_badge` par matière, teinte par **catégorie** (Maths, PC, SVT : `science` ; H-G : `other` ; Français, Philo : `literature`), puis « et plus encore » ;
  - `section#pour-qui` : deux cartes, Élèves et Enseignants ;
  - `section#fonctionnalites` : Exercices quotidiens, Programme officiel, Badges et progression, Espace enseignant ;
  - `section#comment` : trois étapes, du code de classe aux badges ;
  - `section#rejoindre` : les deux mêmes entrées ;
  - pied de page : les trois ancres.
- `homepage/_role_modal` (locals `role:` `:student` ou `:teacher`, `placement:` `:hero` ou `:join`, `variant:`) : `ui_modal(id: "role-modal-<role>-<placement>", size: :sm, trigger:, trigger_variant:)` → chapeau `text-mute`, « Se connecter » (`primary`, `lg`, pleine largeur, icône `arrow-right-end-on-rectangle`), la porte du rôle (`secondary`, `lg`, pleine largeur), une indication `text-xs text-mute`.
- Élève en `primary`, enseignant en `secondary`, dans les deux emplacements.

**Tokens**
- Composants `ui_*` et tokens du `@theme` uniquement. Aucune classe ni emoji de l'ancienne page (`btn-primary`, `card-ln`, `material_chip`, 📚 🎓 🏅).

**Comportement**
- Le bouton porte `data-action="modal#open"`, `aria-haspopup="dialog"` et `aria-controls` ; la `<dialog>` native fournit le piège du focus, Échap et le fond cliquable.
- Ouvrir, fermer ou changer de modale ne recharge jamais la page. Suivre un lien de la modale est une navigation Turbo ; la modale se referme avant la mise en cache.
- Un visiteur connecté n'arrive jamais sur la landing : il est envoyé vers son accueil (Lot 0d).

**États obligatoires**
- Sans objet : la page est statique, sans donnée ni erreur possible.

**Accessibilité**
- Un seul `h1` ; chaque modale est nommée par son titre (`aria-labelledby`).
- Cibles tactiles ≥ 48 px ; en 390 px, la modale est une feuille basse et la page ne défile pas en largeur.

## 4. Conséquences

- Toute nouvelle entrée de rôle (parent, établissement) passe par une nouvelle modale **et** une route existante ; le test des liens refuse sinon.
- La landing ne promet que ce que la V1 livre ; les rôles et fonctionnalités d'une vague future y entrent avec leur vague.
- Les contrôleurs `homepage-student-modal` et `homepage-teacher-modal` de l'ancienne application ne sont pas repris : le contrôleur `modal` du socle suffit.

## Amendement du 2026-10-02 — structure remplacée par l'UDR-0064

*Chantier [`docs/chantiers/refonte-homepage`](../../chantiers/refonte-homepage/prd.md), [UDR-0064](0064-page-d-accueil-un-ecran-une-decision.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- La **§3 « Structure »** (en-tête à ancres, « Commencer », section « Pour qui ? », fonctionnalités sur fond `ink`, « et plus encore ») est **remplacée** par la §3 de l'UDR-0064 : un en-tête réduit au logo et à « Se connecter », un héros qui tient dans le premier écran d'un téléphone, les matières de la grille élève (UDR-0058), trois étapes, quatre promesses, une section « Enseignants » vouvoyée, le pied avec les pages publiques en ligne (UDR-0063). Les deux entrées ne sont pas répétées en bas de page, comme l'UDR-0059 §2.2 le demande déjà. L'UDR-0064 décrit la famille ordinateur de l'UDR-0059 et s'affiche à toutes les largeurs jusqu'au lot M2 d'`interface-epuree`.
- Les **décisions 1 à 5 du §2** (deux entrées et seulement deux, une modale chacune, la porte de l'élève, la porte de l'enseignant, aucun lien sans route) **restent** et sont vérifiées par les mêmes tests. La décision 6 reste pour le contenu (la V1, le slogan, les quatre badges) ; sa « structure de l'ancienne page » n'est plus reprise.
- `_role_modal` : le déclencheur passe en `lg`, pleine largeur (`trigger_size:`, `trigger_full:`), et la modale nomme l'onglet par son titre (`document_title:`, UDR-0054 §3.1).
- Décision 6 : le slogan devient « Lnclass, tu comprends chap chap ! » (porteur, 2026-10-03).

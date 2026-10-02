# UDR-0063 : Pages publiques — Notre mission, Protection des données, Conditions d'utilisation, Conditions de vente

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md) — grill Q15, Q16 (ajouts du porteur) ; [PRD](../../chantiers/fonctions-espace-eleve/prd.md) ; brouillons des textes : [`pages-publiques.md`](../../chantiers/fonctions-espace-eleve/pages-publiques.md) |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucun traceur, CSP) · [UDR-0061](0061-carte-d-aide-et-faq.md) (motif de `/aide`, carte d'aide) · [UDR-0060](0060-connexion-et-recuperation-du-pin.md) (écrans d'entrée) · [UDR-0059](0059-homepage-telephone-et-tablette.md), [UDR-0012](0012-landing-et-modales-de-role.md) (homepage) · [UDR-0057](0057-ecrans-eleve-epures.md) (R1 à R6) |
| **Amende** *(proposé)* | UDR-0061 §3.1 (la FAQ renvoie à la protection des données et aux CGU) · UDR-0012 (pied de page de la homepage) |
| **Remplacé par** | — |

---

## 1. Contexte

Lnclass est en production sur lnclass.com depuis le 2026-09-27. Elle enregistre des données d'élèves de 11 à 18 ans (nom, numéro de téléphone, résultats), et aucune page ne dit lesquelles, pourquoi, ni qui les voit. Aucune page ne dit non plus ce que Lnclass est, ni les règles d'usage du service. Le paiement d'un abonnement arrive (chantier [`abonnement-mobile-money`](../../chantiers/abonnement-mobile-money/memo.md)) : il lui faudra des conditions de vente.

Le porteur a ajouté au chantier, le 2026-10-02 :

- **Q15** : deux pages, « Notre mission » et « Politique de protection des données » ;
- **Q16** : les conditions générales d'utilisation (CGU) et de vente (CGV). L'entité juridique est **« Lnclass Côte d'Ivoire »**, qui est aussi le responsable du traitement ; son adresse, son RCCM et son contact restent à fournir.

## 2. Décision

1. **Quatre pages publiques et statiques, sur le motif de `/aide`** (UDR-0061 §3.1) : layout `application` sans shell, logo, retour « Accueil », un seul `h1`, textes dans les locales. Lisibles sans compte, par un parent comme par un élève.
2. **Des adresses en français**, comme `/aide` : `/mission`, `/confidentialite`, `/conditions-utilisation`, `/conditions-vente`.
3. **Aucun fait inventé.** Les brouillons ([`pages-publiques.md`](../../chantiers/fonctions-espace-eleve/pages-publiques.md)) ne disent que ce que le code, le schéma et les ADR établissent. Ce qui relève du porteur ou d'un juriste est marqué « à fournir ».
4. **Une page n'est mise en ligne que complète** : sa route n'est dessinée et son lien n'apparaît qu'une fois son texte validé et ses données « à fournir » remplies. Aucun « à fournir » n'est jamais visible en production.
5. **Les CGV attendent l'offre.** Elles ne sont qu'un squelette tant que le chantier `abonnement-mobile-money` n'a pas fait son grill : leur lot dépend de ce chantier.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Routes et contrôleur

- Dans `config/routes/communication.rb`, à côté de `aide` :

| Route | Action | Nom |
|---|---|---|
| `GET /mission` | `communication/pages#mission` | `mission_path` |
| `GET /confidentialite` | `communication/pages#privacy` | `privacy_path` |
| `GET /conditions-utilisation` | `communication/pages#terms` | `terms_path` |
| `GET /conditions-vente` | `communication/pages#sales_terms` | `sales_terms_path` |

- `Communication::PagesController`, `allow_unauthenticated_access`, quatre actions sans logique : ni table, ni query, ni use case.
- Chaque route n'est ajoutée que par le lot qui met sa page en ligne (§2.4).

### 3.2 Mise en page commune — `communication/pages/_page.html.erb`

- Layout `application`, **sans le shell**.
- Colonne centrée, `max-w-prose`, de haut en bas :
  - le logo (motif UDR-0060) ;
  - `ui_back_link` « Accueil » vers `root_path` (un utilisateur connecté y est renvoyé vers son accueil, comme aujourd'hui) ;
  - un seul `h1` (`font-display`, 800) ;
  - pour la protection des données, les CGU et les CGV : « Mis à jour le <date> » (`text-sm text-mute`), date tenue dans la locale ;
  - **un sommaire** si la page a plus de cinq sections : `nav[aria-label="Sommaire"]` > `ol` de liens d'ancre vers chaque `h2` ;
  - les sections : `section[aria-labelledby]` > `h2` (`id` stable en kebab-case, ex. `#donnees-collectees`), puis des paragraphes et des listes.
- `page_title` : « Notre mission · Lnclass », « Protection des données · Lnclass », « Conditions d'utilisation · Lnclass », « Conditions de vente · Lnclass ».

### 3.3 Textes — `config/locales/communication/pages.fr.yml`

- Une clé par page (`mission`, `privacy`, `terms`, `sales_terms`) ; chaque section : `title` et `paragraphs` (tableau) ou `items` (liste).
- Ton : **vouvoiement** sur ces quatre pages. Elles s'adressent aussi aux parents, aux enseignants et aux établissements, et les CGU et la politique engagent l'entité ; l'espace élève garde le tutoiement.
- Les textes partent des brouillons validés de [`pages-publiques.md`](../../chantiers/fonctions-espace-eleve/pages-publiques.md). Un fait nouveau dans une page passe par une PR qui cite sa source (ADR, schéma, code).
- Test de garde : `test/i18n/public_pages_test.rb` échoue si `pages.fr.yml` contient « à fournir », « TODO », « XXX » ou « [ » suivi d'une majuscule.

### 3.4 Points d'entrée

- **Pied de page de la homepage** (`app/views/homepage/index.html.erb`, famille ordinateur ; la famille téléphone de l'UDR-0059 le reprend en phase 2 d'`interface-epuree`) : une seconde liste de liens `text-sm`, « Notre mission · Protection des données · Conditions d'utilisation · Conditions de vente », chacun présent seulement si sa page est en ligne.
- **Page `/aide`** (amendement proposé de l'UDR-0061 §3.1) : sous la liste des questions, une ligne `text-sm text-mute` « Vos données : <Protection des données> · <Conditions d'utilisation> ».
- **Carte d'aide** (UDR-0061 §3.3) : son pied porte « Notre mission · Confidentialité · Conditions d'utilisation ».
- Aucun lien depuis le shell connecté : ces pages ne sont pas une destination de navigation (UDR-0006).

### 3.5 États obligatoires

- Page statique : ni vide, ni chargement, ni erreur propres. Une page non encore en ligne n'a pas de route (404 du routeur).

### 3.6 Accessibilité

- Un seul `h1` ; une `h2` par section, sans saut de niveau ; ancres du sommaire focalisables, cible ≥ 48 px en hauteur de ligne.
- Liens dans le texte soulignés (pas seulement colorés).
- Longueur de ligne bornée par `max-w-prose` ; texte 16 px, interligne 1,6.
- Aucune image porteuse de sens.

### 3.7 Contrôle de la règle (UDR-0057), appliquée par analogie aux écrans d'entrée

| Règle | Application |
|---|---|
| R1 | Aucun bouton principal. |
| R2 | Logo, retour, `h1`, sommaire, première section : 5. |
| R3 | Ne s'applique pas : une page de texte n'est pas une liste de lignes ; replier un article d'une politique cacherait une obligation. |
| R4 | La page est elle-même l'explication, ouverte à la demande. |
| R5 | `brand` pour les liens seulement. |
| R6 | Une information dite une fois : la politique renvoie aux CGU plutôt que de les répéter, et inversement. |

## 4. Conséquences

- Quatre lots indépendants les uns des autres ; chacun ne touche que sa route, sa locale et sa vue, plus une ligne de pied de page (fichier partagé, au Lot 0 du plan).
- **Le lot CGV dépend du chantier `abonnement-mobile-money`** (offre, prix, durée, remboursement) ; il ne peut pas être mis en ligne avant lui.
- La politique de protection des données doit suivre le code : un chantier qui ajoute une donnée personnelle, un destinataire ou un sous-traitant met la page à jour dans sa PR, comme la FAQ (Q14).
- Le cadre ivoirien (loi n° 2013-450 relative à la protection des données à caractère personnel, autorité : ARTCI) est cité comme cadre applicable ; aucune page n'affirme une conformité, une déclaration ou une autorisation que le porteur n'a pas fournie.
- Interdit désormais : publier un texte juridique sans relecture du porteur ; afficher une donnée « à fournir ».

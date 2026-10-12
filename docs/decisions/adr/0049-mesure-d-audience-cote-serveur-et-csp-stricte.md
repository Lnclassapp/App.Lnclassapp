# ADR-0049 : Mesure d'audience côté serveur, sans script tiers, sous une CSP stricte
<!-- index
titre: Mesure d'audience côté serveur, sans script tiers, sous une CSP stricte
statut: Accepté
problematique: Aucun script, style, police ni iframe tiers ; CSP bloquante dès la V0 (scripts sous nonce, `object-src 'none'`, `frame-ancestors 'none'`) ; indicateurs métier agrégés lus côté serveur et affichés dans l'espace équipe en V4 ; aucun traceur ni bandeau de consentement. Tranche F-27 du programme de refonte.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-24 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-27**, bloque la V0 |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancienne application chargeait **Google Tag Manager** (`GTM-N8FK5T78`) et **Microsoft Clarity** (`fhs9um41ic`) sur toutes les pages de production (`shared/analytics/_analytics.html.erb:9,18`, inventaire TR-26) :

- identifiants **codés en dur**, sans variable d'environnement ;
- **aucun consentement** demandé ;
- **aucune Content Security Policy** : `config/initializers/content_security_policy.rb` est entièrement commenté (inventaire transverse §6) ;
- le contenu réel du conteneur GTM est **inconnu** : sa configuration vit chez Google, pas dans le dépôt.

Trois faits propres à Lnclass rendent ce statu quo intenable dans le nouveau projet :

1. **Le public est majoritairement mineur** (élèves de collège et de lycée). Clarity enregistre des sessions (replay) ; la loi ivoirienne n° 2013-450 sur la protection des données à caractère personnel (autorité : ARTCI) s'applique. *Le cadrage juridique précis reste à faire valider par une personne compétente : cet ADR choisit la voie qui ne dépend pas de cette validation.*
2. **Le public utilise des Android d'entrée de gamme en 3G** ([ADR-0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md)) : chaque script tiers coûte du temps de chargement et des données mobiles payées par la famille. F-29 (ADR-0051) fixera un budget JavaScript.
3. **Une CSP stricte et GTM sont incompatibles par construction** : GTM sert précisément à injecter des scripts arbitraires décidés hors du dépôt.

Enfin, lors du cadrage du 2026-09-24, le porteur du produit a confirmé que **personne ne consulte les données GTM ni Clarity** : les retirer ne fait perdre aucune décision en cours.

## 2. Moteurs de décision

Par ordre d'importance :

1. Protection des mineurs : ni replay, ni profilage publicitaire, ni transfert de navigation à un tiers.
2. Sécurité : une CSP qui interdit tout script qui n'est pas servi par l'application elle-même.
3. Poids réseau nul pour la mesure, compatible avec le budget F-29.
4. Mesurer ce qui éclaire les décisions d'une plateforme éducative : inscriptions, activation, exercices terminés, rétention — plutôt que des pages vues.
5. Aucun bandeau de consentement à maintenir, faute de traceur à consentir.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder GTM + Clarity, identifiants en variables d'environnement, bandeau de consentement | Mesure la plus riche (audience, replay, balises marketing) ; aucun développement | Replay de sessions de mineurs ; dizaines de Ko de JS tiers ; CSP à ouvrir à Google et Microsoft, donc CSP de façade ; bandeau à maintenir ; **aucun usage actuel** des données |
| B — Outil léger sans cookie (Plausible hébergé, Umami auto-hébergé) | Script de 1 à 2 Ko ; pas de cookie ; un seul domaine dans la CSP | Mesure des pages vues, pas des indicateurs métier ; un fournisseur ou un service de plus ; reste possible **plus tard**, par un nouvel ADR, si un besoin d'audience apparaît |
| **C — Mesure côté serveur uniquement** | Aucun script tiers ; CSP la plus stricte ; aucun cookie ajouté ; indicateurs métier lus dans les données que l'application possède déjà | Retenue — voir coûts consentis |
| D — Aucune mesure en V0 | Rien à construire | Laisse le lancement sans aucun indicateur ; C coûte à peine plus en V0 (la CSP) et donne un cadre aux vagues suivantes |

## 4. Décision

> **Nous ne chargeons aucun script, aucune feuille de style, aucune police ni aucun cadre (iframe) provenant d'un tiers.** Tout ce que le navigateur exécute est servi par l'application.
>
> **Nous appliquons dès le premier déploiement une Content Security Policy stricte**, en mode bloquant : `default-src 'self'`, scripts sous nonce, aucun `'unsafe-inline'` ni `'unsafe-eval'` pour les scripts, `object-src 'none'`, `frame-ancestors 'none'`.
>
> **Nous mesurons l'usage côté serveur**, à partir des données métier que l'application enregistre déjà (comptes, rattachements, sessions d'exercices, assignations). Les indicateurs sont **agrégés**, lus par des queries CQRS, et affichés dans l'espace équipe. Aucun traceur, aucun cookie autre que celui de session, aucune adresse IP conservée à des fins de mesure.
>
> **Nous ne posons donc aucun bandeau de consentement.** L'introduction d'un outil de mesure navigateur, quel qu'il soit, exige un nouvel ADR qui remplace celui-ci.

Découpage :

| Élément | Livré en | Par |
|---|---|---|
| CSP stricte + interdiction des ressources tierces + test qui les vérifie | **V0** (`amorcage-depot`) | garde-fou n° 6 de la feuille de route |
| Indicateurs métier dans l'espace équipe | **V4** (`pilotage-equipe`, avec TR-10) | query de lecture du contexte `identity` / `school` |

## 5. Conséquences

### 🟢 Positives

- Aucune donnée de navigation d'un mineur ne quitte l'application.
- Zéro octet de JavaScript tiers : la mesure ne consomme rien du budget F-29.
- La CSP est réelle : une injection HTML ne peut pas exécuter de script, et une dépendance ajoutée « en passant » depuis un CDN échoue immédiatement en développement.
- Pas de bandeau : un écran de moins sur un petit téléphone, et rien à maintenir.
- Les indicateurs portent sur ce qui compte pour le produit (élèves actifs, exercices terminés), pas sur des proxys.

### 🔴 Coûts consentis

- **Aucune mesure d'audience anonyme** : ni sources de trafic, ni pages de sortie, ni visiteurs non inscrits. On ne saura pas combien de visiteurs voient la page d'accueil sans s'inscrire.
- **Aucun replay** : les blocages d'interface se découvriront par les tests système, les retours d'utilisateurs et les indicateurs d'abandon, pas par l'observation.
- **Les indicateurs se construisent** : ils ne sont pas offerts par un outil ; ils arrivent en V4 seulement.
- **Contraintes de développement** : pas de `<script>` en ligne sans nonce, pas de `onclick=`, pas de CDN (KaTeX et toute bibliothèque passent par le bundle, cohérent avec F-29). Les attributs `style="…"` restent autorisés (`style-src-attr 'unsafe-inline'`) parce que KaTeX en produit ; c'est la seule concession, et elle ne permet pas d'exécuter de code.

## 6. Notes d'implémentation

Pour le nouveau dépôt (Rails 8.1), à livrer par le chantier `amorcage-depot`.

```ruby
# config/initializers/content_security_policy.rb
# ADR-0049 : aucune ressource tierce, scripts sous nonce, CSP bloquante dès la V0.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self
    policy.style_src       :self
    policy.style_src_attr  :unsafe_inline # attributs style="…" produits par KaTeX — aucun code exécutable
    policy.img_src         :self, :data, :blob
    policy.font_src        :self
    policy.connect_src     :self          # Turbo, Action Cable (Solid Cable) sur la même origine
    policy.media_src       :self, :blob
    policy.object_src      :none
    policy.frame_src       :none
    policy.frame_ancestors :none
    policy.base_uri        :self
    policy.form_action     :self
  end

  config.content_security_policy_nonce_generator  = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
```

Le layout doit poser `<%= csp_meta_tag %>` (Turbo le lit pour ses propres éléments) et tout `javascript_include_tag` / `javascript_importmap_tags` prend `nonce: true`.

Les indicateurs de V4 se lisent depuis les tables existantes, sans table de suivi dédiée. Exemple de forme attendue (contrat de retour F-01 : objets `Data`, jamais une relation) :

```ruby
# app/infrastructure/queries/school/engagement_query.rb (V4)
module Queries
  module School
    class EngagementQuery
      Weekly = Data.define(:week, :active_students, :completed_sessions)

      def call(since:)
        Orm::ExerciseSession.completed
          .where(completed_at: since..)
          .group("date_trunc('week', completed_at)")
          .pluck(Arel.sql("date_trunc('week', completed_at)"), Arel.sql("COUNT(DISTINCT student_id)"), Arel.sql("COUNT(*)"))
          .map { |week, students, sessions| Weekly.new(week:, active_students: students, completed_sessions: sessions) }
      end
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

Deux tests, livrés en V0, **bloquants en CI** :

```ruby
# test/integration/content_security_policy_test.rb
require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "every page is served under a strict CSP that trusts no third party" do
    get root_path

    csp = response.headers["Content-Security-Policy"]
    assert csp, "la CSP doit être bloquante (pas Report-Only)"
    assert_match(/default-src 'self'/, csp)
    assert_match(/object-src 'none'/, csp)
    assert_match(/frame-ancestors 'none'/, csp)
    script_src = csp[/script-src [^;]*/]
    refute_match(/unsafe-inline|unsafe-eval|https?:/, script_src)
  end
end
```

```ruby
# test/views/no_third_party_resources_test.rb
require "test_helper"

class NoThirdPartyResourcesTest < ActiveSupport::TestCase
  # Balises qui chargent une ressource depuis une autre origine, et hôtes de traçage connus.
  THIRD_PARTY = %r{<(script|link|iframe|img|source|video|audio)\b[^>]*\b(src|href)=["']?(https?:)?//|googletagmanager|clarity\.ms|cdn\.jsdelivr|unpkg\.com|cdnjs}i

  test "no view or layout loads a script, style, font or frame from another origin" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].select { |f| File.read(f).match?(THIRD_PARTY) }
    assert_empty offenders, "ADR-0049 : ressource tierce interdite dans #{offenders.join(', ')}"
  end
end
```

Un lien sortant (`<a href="https://…">`) reste permis et n'est pas signalé (expression vérifiée le 2026-09-24 sur six cas : lien sortant et script local acceptés ; script et feuille de style CDN, iframe, GTM refusés). Si le test signale un faux positif, on affine l'expression, on ne le désactive pas.

## Amendement du 2026-09-26 — un nonce par session

**Constat.** Le nonce était tiré à chaque requête. Une navigation Turbo Drive garde le document, donc la CSP reçue avec sa première page, mais remplace `meta[name=csp-nonce]` par celui de la nouvelle page. Trix lit cette balise pour ses `<style>` en ligne : après une seule navigation, ils étaient refusés (`style-src-elem`), l'éditeur perdait son habillage et son champ de lien caché interceptait les clics. Parcours cassé : se connecter, accueil équipe, « Nouveau cours ». Le défaut restait invisible tant que l'accueil équipe de test forçait un rechargement complet.

**Décision, validée par le porteur.**

1. **Un nonce par session**, tiré au hasard et gardé dans la session : `request.session[:csp_nonce] ||= SecureRandom.base64(16)`. On ne reprend pas l'identifiant de session (forme proposée par le guide Rails) : il peut être vide pour un visiteur neuf, et il n'a pas à figurer dans le HTML.
2. **Une nouvelle session recharge le document.** La connexion, l'inscription (enseignant, élève par code) et la déconnexion appellent `reset_session`, donc tirent un nouveau nonce. `Authentication` pose alors un drapeau de flash. Si la page d'arrivée est demandée par Turbo (en-tête `X-Turbo-Request-Id`), elle porte `<meta name="turbo-visit-control" content="reload">` et Turbo recharge le document entier, avec la bonne CSP ; le flash est gardé une requête de plus, et le toast s'affiche sur la page rechargée. Un chargement hors Turbo reçoit déjà la bonne CSP : rien à recharger. Le second facteur ne renouvelle pas la session et n'a pas besoin de rechargement.
3. **Les erreurs restent sans rechargement** : un formulaire refusé (422) est re-rendu par Turbo comme avant ; seul le succès recharge.

**Ce qui ne change pas.** La CSP reste bloquante, sans `'unsafe-inline'` ni `'unsafe-eval'` pour les scripts, sans hôte tiers. Un nonce stable pendant une session reste imprévisible pour un tiers, et il change à chaque connexion.

**Preuves.** `test/integration/content_security_policy_test.rb` (nonce stable dans la session, nouveau à la connexion et à la déconnexion, rechargement unique avec son toast) et `test/system/shared/csp_turbo_navigation_test.rb` (connexion, accueil, « Cours », « Nouveau cours » : la barre de Trix est habillée, le texte se saisit, aucune violation de CSP).

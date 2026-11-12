# ADR-0130 : Les modèles de langage passent par un port unique, servi par OpenRouter
<!-- index
titre: Modèles de langage par OpenRouter
statut: Accepté
problematique: Comment appeler des modèles de langage (Kimi, DeepSeek, Gemini) depuis l'application sans s'y lier, ni bloquer une requête, ni dépendre d'une gemme
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le chantier `crm-ecoles` (« Lnclass Intelligent ») introduit les premiers appels à des modèles de langage : fiche de briefing avant appel, compte rendu dicté (audio), brouillon de relance WhatsApp, rapport pédagogique pour la direction. Le porteur veut pouvoir utiliser Kimi, DeepSeek ou Gemini et en changer sans réécrire le code ; d'autres agents viendront ensuite.

L'application n'appelle aujourd'hui **aucune** API HTTP externe : pas de Faraday, pas de client HTTP, aucun secret lu hors de `ENV`. Un appel à un modèle dure de 2 à 30 secondes : le faire pendant une requête web bloquerait un processus Puma et laisserait l'utilisateur devant une page figée.

Le compte rendu dicté lit un **fichier envoyé par un utilisateur** (enregistrement audio) : `CLAUDE.md` impose d'écrire la menace avant le code.

## 2. Moteurs de décision

- Changer de modèle ou de fournisseur = changer une variable, pas du code.
- Aucune requête web n'attend un modèle.
- Pas de nouvelle gemme pour un seul appel HTTP JSON.
- Les tests ne touchent jamais le réseau.
- Tracer chaque génération (modèle, durée, jetons) pour suivre le coût.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Un adaptateur par fournisseur (Moonshot, DeepSeek, Google) | Accès direct, sans intermédiaire | Trois API, trois clés, trois formats ; l'audio de Gemini a son propre format |
| B — OpenRouter, API compatible OpenAI, une clé | Un seul format pour tous les modèles, audio compris pour les modèles qui l'acceptent ; le modèle se choisit par une chaîne | Un intermédiaire de plus (latence, disponibilité, marge sur le prix) |
| C — Gemme `ruby-openai` ou `ruby_llm` | Client prêt à l'emploi | Dépendance pour un seul `POST` JSON ; surface et mises à jour à suivre |

## 4. Décision

> **Nous déclarons dans le domaine un port `Ports::Crm::LanguageModelPort` à une méthode (`complete`), servi en production par un seul adaptateur `Crm::OpenRouterLanguageModel` (sur le modèle de `Communication::DrawingReader`, `app/infrastructure/communication/`) écrit avec `Net::HTTP` (bibliothèque standard). Chaque assistant appelle le modèle depuis un job Solid Queue, jamais depuis une requête web ; le résultat est stocké dans `crm_generations` et l'écran l'attend par sondage. Le modèle de chaque usage se règle par variable d'environnement.**

**Contrat du port**

```ruby
# complete(messages:, model:, max_tokens:, json: false, audio: nil) → Shared::Result
#   messages : [{ role: "system"|"user", content: String }]
#   audio    : { data: String (octets), format: "webm"|"ogg"|"mp4" } ou nil
#   succès   : Shared::Result.success({ text:, model:, input_tokens:, output_tokens:, duration_ms: })
#   échecs   : Shared::Result.failure(:unavailable, errors: { reason: :not_configured | :timeout | :provider_error | :invalid_response })
#              (ERROR_CODES de Shared::Result est une liste fermée, non étendue : la raison voyage dans errors[:reason])
```

**Configuration** (variables Railway, lues une fois dans `config/initializers/language_models.rb` vers `Rails.configuration.x.language_models`) :

| Variable | Rôle | Exemple de valeur |
|---|---|---|
| `OPENROUTER_API_KEY` | Clé ; absente → raison `:not_configured`, boutons remplacés par « Assistant non configuré » | — |
| `OPENROUTER_MODEL_TEXT` | Briefing, brouillon, rapport | `deepseek/deepseek-chat` |
| `OPENROUTER_MODEL_AUDIO` | Compte rendu dicté | `google/gemini-2.5-flash` |

Délai : 5 s pour ouvrir la connexion, 30 s pour la réponse (90 s pour une requête avec audio), aucune nouvelle tentative automatique (l'utilisateur réessaie). Les 90 s viennent de l'essai réel du 2026-11-09 : une dictée a échoué à 31,7 s avec `google/gemini-2.5-flash`, alors qu'une dictée peut durer 3 min.

**Table `crm_generations`** : `public_id`, `school_id`, `kind` ∈ {`briefing`, `dictation`, `whatsapp_draft`, `pedagogy_report`}, `status` ∈ {`pending`, `done`, `failed`}, `requested_by_id`, `follow_up_id` (nul), `input_fingerprint` (SHA-256 des entrées), `content` (texte ou JSON), `error_code`, `model`, `input_tokens`, `output_tokens`, `duration_ms`. Le port `GenerationRepositoryPort` marque l'échec par `mark_failed(public_id:, error_code:, duration_ms:)` (et non `fail`, qui masquerait `Kernel#fail`). Index unique partiel `(school_id, kind) WHERE status = 'pending'` : une seule génération en cours par école et par type. Un briefing dont l'empreinte des entrées est inchangée réutilise le dernier `done`.

**Sondage** : l'état `pending` rend un frame Turbo que le contrôleur Stimulus `generation-poll` recharge toutes les 2 s, 45 s au plus (120 s pour une dictée), puis affiche l'état d'erreur.

**Menace écrite d'abord — enregistrement vocal**

| Menace | Parade |
|---|---|
| Fichier énorme qui sature disque ou mémoire | Refus au-delà de 10 Mo avant lecture complète (`content_length`), puis vérification de la taille réelle |
| Fichier qui n'est pas de l'audio | Type détecté par Active Storage (octets magiques, Marcel), liste blanche `audio/webm`, `audio/ogg`, `audio/mp4` ; l'extension et le type annoncé par le navigateur ne font pas foi |
| Durée annoncée mensongère | Le serveur ne décode jamais l'audio ; la taille plafonne la durée réelle |
| Analyseur audio vulnérable côté serveur | Aucun : l'audio n'est ni décodé, ni transcodé, ni analysé par l'application ; il est transmis tel quel au fournisseur |
| Fichier conservé et réexposé | Stocké privé, jamais servi par URL ; purgé dès la fin du job, en succès comme en échec |
| Données personnelles dans les notes envoyées au modèle | Les champs libres (`note`, `next_step`, `reason`) partent masqués par `Entities::Crm::Redaction` : numéros ivoiriens (« [numéro] ») et noms des contacts de l'école, archivés compris (« [contact] »). Les noms d'élèves ne peuvent pas être filtrés : le formulaire d'échange demande de ne pas les écrire |
| Accès d'un autre rôle | Route et use case derrière `ManageCrmPolicy` |
| Réponse du modèle qui injecte du HTML ou des instructions | Sortie toujours affichée comme texte échappé ; JSON du compte rendu validé par un schéma fermé (types et longueurs du formulaire) ; aucun outil n'est donné au modèle, il ne peut rien déclencher |

## 5. Conséquences

### 🟢 Positives

- Passer de DeepSeek à Kimi ou à Gemini = changer `OPENROUTER_MODEL_TEXT`.
- Les futurs agents réutilisent le port ; un autre fournisseur = un autre adaptateur, sans toucher au domaine.
- Aucun processus web n'attend un modèle ; une panne du fournisseur n'affecte que les assistants.
- Coût suivi par génération (`model`, jetons).

### 🔴 Coûts consentis

- Un intermédiaire (OpenRouter) dont la panne coupe tous les assistants.
- Un client HTTP maison à maintenir (en-têtes, délais, erreurs).
- Le sondage coûte une requête toutes les 2 s pendant une génération.
- Le support de l'audio dépend du modèle choisi : à vérifier au lot du compte rendu dicté ; à défaut, une transcription séparée sera nécessaire.
- Le port est déclaré dans `crm` ; s'il sert un autre contexte, il devra remonter dans un espace partagé (`shared`).

## 6. Notes d'implémentation

```ruby
# app/infrastructure/crm/open_router_language_model.rb
module Crm
  class OpenRouterLanguageModel
    ENDPOINT = URI("https://openrouter.ai/api/v1/chat/completions")

    def initialize(api_key: Rails.configuration.x.language_models.api_key, http: Net::HTTP)
      @api_key, @http = api_key, http
    end

    def complete(messages:, model:, max_tokens:, json: false, audio: nil)
      return Shared::Result.failure(:unavailable, errors: { reason: :not_configured }) if @api_key.blank?
      # POST JSON, open_timeout 5, read_timeout 30 ; Net::ReadTimeout → raison :timeout ;
      # code ≠ 2xx → raison :provider_error ; corps sans choices[0].message.content → raison :invalid_response
    end
  end
end
```

Tests : `test/support/fake_language_model.rb` implémente le port (réponses programmées, échecs simulés) ; l'adaptateur est testé avec un faux `http` injecté, jamais le réseau.

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/crm/open_router_language_model_test.rb` : succès, clé absente, délai dépassé, 500, corps invalide.
- `test/jobs/crm/*_job_test.rb` : un job en échec marque la génération `failed` avec son `error_code` et purge l'audio.
- `grep -rn "OpenRouter\|Net::HTTP" app/domain` doit rester vide (le domaine ne connaît que le port).
- `test/controllers/teams/crm/dictations_controller_test.rb` : 12 Mo et `audio/wav` refusés sans appel au modèle (CA-26).

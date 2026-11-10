# ADR-XXXX (modèles de langage) : la clé OpenRouter et le modèle de chaque usage, lus une fois ici depuis l'environnement.
# Changer de modèle = changer une variable Railway, pas du code. Clé absente : le port répond :not_configured et les
# assistants affichent « Assistant non configuré ». Le domaine ne lit jamais ENV : il reçoit le modèle à l'appel.
Rails.application.config.x.language_models.tap do |models|
  models.api_key = ENV["OPENROUTER_API_KEY"].presence
  models.model_text = ENV["OPENROUTER_MODEL_TEXT"].presence || "deepseek/deepseek-chat"
  models.model_audio = ENV["OPENROUTER_MODEL_AUDIO"].presence || "google/gemini-2.5-flash"
end

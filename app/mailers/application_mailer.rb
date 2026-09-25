# 🔌 INFRASTRUCTURE · ApplicationMailer
# Rôle : mailer parent de l'application
# ADR  : 0001
class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
end

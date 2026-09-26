# ADR-0049 : no third-party resource, scripts under nonce, blocking CSP from V0.
# Amendment of 2026-09-26: one nonce per session. A Turbo Drive visit keeps the document, hence the CSP of its first
# page, but swaps meta[name=csp-nonce]: a nonce drawn per request made Trix's <style> tags fail after any visit.
# A new session (sign-in, sign-out) draws a new nonce, and Authentication reloads the document then.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self
    policy.style_src       :self
    policy.style_src_attr  :unsafe_inline # style="…" attributes produced by KaTeX — no executable code
    policy.img_src         :self, :data, :blob
    policy.font_src        :self
    policy.connect_src     :self          # Turbo, Action Cable (Solid Cable) on the same origin
    policy.media_src       :self, :blob
    policy.object_src      :none
    policy.frame_src       :none
    policy.frame_ancestors :none
    policy.base_uri        :self
    policy.form_action     :self
  end

  config.content_security_policy_nonce_generator  = ->(request) { request.session[:csp_nonce] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end

# ADR-0049 : no third-party resource, scripts under nonce, blocking CSP from V0.
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

  config.content_security_policy_nonce_generator  = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end

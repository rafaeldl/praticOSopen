/// Compile-time feature flags.
///
/// The WhatsApp bot is off while the MCP connector takes over its role. The
/// backend routes under /bot stay in place — they are the shared business
/// logic the connector runs on. Flip this back to true to restore the bot UI.
const bool kWhatsAppBotEnabled = false;

/// AI assistant in the new order screen (Foto / "Falar o que fazer").
///
/// Off by default: store builds never show the buttons. Pilot builds turn it
/// on with `--dart-define=AI_ORDER_ASSIST=true`; the server also refuses
/// unless the company is in the pilot (`companies/{id}/settings/ai.enabled`).
/// See docs/AI_ORDER_ASSIST.md.
const bool kAiOrderAssistEnabled =
    bool.fromEnvironment('AI_ORDER_ASSIST', defaultValue: false);

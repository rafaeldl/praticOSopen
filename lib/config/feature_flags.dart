/// Compile-time feature flags.
///
/// The WhatsApp bot is off while the MCP connector takes over its role. The
/// backend routes under /bot stay in place — they are the shared business
/// logic the connector runs on. Flip this back to true to restore the bot UI.
const bool kWhatsAppBotEnabled = false;

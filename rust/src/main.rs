mod api;
mod frb_generated;
mod internal;

use crate::api::plugin::models::auth::{AuthEventObject, AuthEventType};
use crate::api::plugin::models::core::{PluginAbility, PluginConfiguration};
use crate::api::plugin::plugin::SpotubePlugin;
use crate::frb_generated::StreamSink;
use tokio::io::sink;
use tokio::time::Instant;

async fn plugin(plugin_js: String) -> anyhow::Result<()> {
    let mut plugin = SpotubePlugin::new();
    let config = PluginConfiguration {
        entry_point: "TestingPlugin".to_string(),
        abilities: vec![PluginAbility::Metadata],
        apis: vec![],
        author: "KRTirtho".to_string(),
        description: "Testing Plugin".to_string(),
        name: "Testing Plugin".to_string(),
        plugin_api_version: "2.0.0".to_string(),
        repository: None,
        version: "0.1.0".to_string(),
    };
    let sender = plugin
        .create_context(
            plugin_js,
            config.clone(),
            "https://localhost:3000".to_string(),
            "1234567890_secret".to_string(),
            "/home/krtirtho/.local/share/spotube".into(),
        )
        .await?;

    tokio::spawn(async move {
        while let Some(event) = plugin.event_rx.take().unwrap().recv().await {
            println!("Auth event: {:?}", event);
            if event.event_type != AuthEventType::Logout {
                break;
            }
        }
    });
    println!(
        "Is Authenticated: {}",
        plugin.auth.is_authenticated(&sender).await?
    );


    tokio::time::sleep(tokio::time::Duration::from_secs(10)).await;
    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let js_code_path = std::env::args().nth(1);
    if js_code_path.is_none() {
        panic!("Please provide the path to the plugin JS code as a command line argument.");
    }
    let js_code_path = js_code_path.unwrap();
    let plugin_js = tokio::fs::read_to_string(js_code_path).await?;

    plugin(plugin_js).await?;
    Ok(())
}

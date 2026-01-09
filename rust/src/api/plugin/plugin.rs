use crate::api::plugin::commands::PluginCommand;
use crate::api::plugin::executors::{
    execute_albums, execute_artists, execute_audio_source, execute_auth, execute_browse,
    execute_core, execute_playlist, execute_search, execute_track, execute_user,
};
use crate::api::plugin::models::auth::{AuthEventObject, AuthEventType};
use crate::api::plugin::models::core::{PluginAbility, PluginConfiguration};
use crate::api::plugin::senders::{
    PluginAlbumSender, PluginArtistSender, PluginAudioSourceSender, PluginAuthSender,
    PluginBrowseSender, PluginCoreSender, PluginPlaylistSender, PluginSearchSender,
    PluginTrackSender, PluginUserSender,
};
use crate::frb_generated::StreamSink;
use crate::internal::apis;
use crate::internal::apis::{form, timezone, webview, yt_engine};
use anyhow::anyhow;
use flutter_rust_bridge::frb;
use llrt_modules::module_builder::ModuleBuilder;
use llrt_modules::{
    abort, buffer, console, crypto, events, exceptions, fetch, navigator, timers, url, util,
};
use rquickjs::prelude::Func;
use rquickjs::{async_with, AsyncContext, AsyncRuntime, CatchResultExt, Error, Object};
use std::thread;
use tokio::sync::mpsc;
use tokio::sync::mpsc::{Receiver, Sender};
use tokio::task;
use tokio::task::LocalSet;

#[derive(Debug, Clone)]
pub struct OpaqueSender {
    pub sender: Sender<PluginCommand>,
}

// #[frb(ignore)]
async fn create_context(
    server_endpoint_url: String,
    server_secret: String,
    plugin_slug: String,
    local_storage_dir: String,
) -> anyhow::Result<(AsyncContext, AsyncRuntime)> {
    let runtime = AsyncRuntime::new()?;

    let mut module_builder = ModuleBuilder::new();

    module_builder = module_builder
        .with_global(abort::init)
        .with_global(buffer::init)
        .with_global(console::init)
        .with_global(crypto::init)
        .with_global(events::init)
        .with_global(exceptions::init)
        .with_global(fetch::init)
        .with_global(navigator::init)
        .with_global(url::init)
        .with_global(timers::init)
        .with_global(util::init)
        .with_global(form::init)
        .with_global(webview::init)
        .with_global(yt_engine::init)
        .with_global(timezone::init);

    let (module_resolver, module_loader, global_attachment) = module_builder.build();
    runtime
        .set_loader((module_resolver,), (module_loader,))
        .await;

    let context = AsyncContext::full(&runtime).await?;

    async_with!(context => |ctx| {
        apis::init(&ctx, server_endpoint_url, server_secret).catch(&ctx).map_err(|e| anyhow!("Failed to initialize APIs: {}", e))?;
        apis::local_storage::init(&ctx, plugin_slug, local_storage_dir).catch(&ctx).map_err(|e| anyhow!("Failed to initialize LocalStorage API: {}", e))?;
        global_attachment.attach(&ctx).catch(&ctx).map_err(|e| anyhow!("Failed to attach global modules: {}", e))?;
        anyhow::Ok(())
    })
        .await?;

    Ok((context, runtime))
}
#[frb(ignore)]
async fn js_executor_thread(
    rx: &mut Receiver<PluginCommand>,
    context: &AsyncContext,
) -> anyhow::Result<()> {
    while let Some(command) = rx.recv().await {
        if let PluginCommand::Shutdown = command {
            return anyhow::Ok(());
        }

        let context = context.clone();
        task::spawn_local(async move {
            let result = match command {
                PluginCommand::Artist(commands) => execute_artists(commands, &context).await,
                PluginCommand::Album(commands) => execute_albums(commands, &context).await,
                PluginCommand::AudioSource(commands) => {
                    execute_audio_source(commands, &context).await
                }
                PluginCommand::Auth(commands) => execute_auth(commands, &context).await,
                PluginCommand::Browse(commands) => execute_browse(commands, &context).await,
                PluginCommand::Core(commands) => execute_core(commands, &context).await,
                PluginCommand::Playlist(commands) => execute_playlist(commands, &context).await,
                PluginCommand::Search(commands) => execute_search(commands, &context).await,
                PluginCommand::Track(commands) => execute_track(commands, &context).await,
                PluginCommand::User(commands) => execute_user(commands, &context).await,
                PluginCommand::Shutdown => unreachable!(),
            };

            if let Err(e) = result {
                eprintln!("Error executing command: {:?}", e);
            }
        });
    }
    Ok(())
}

pub struct SpotubePlugin {
    pub artist: PluginArtistSender,
    pub album: PluginAlbumSender,
    pub audio_source: PluginAudioSourceSender,
    pub auth: PluginAuthSender,
    pub browse: PluginBrowseSender,
    pub core: PluginCoreSender,
    pub playlist: PluginPlaylistSender,
    pub search: PluginSearchSender,
    pub track: PluginTrackSender,
    pub user: PluginUserSender,
    event_tx: Sender<AuthEventObject>,
    pub event_rx: Option<Receiver<AuthEventObject>>,
}

impl SpotubePlugin {
    #[frb(sync)]
    pub fn new() -> Self {
        let (event_tx, event_rx) = mpsc::channel(32);

        Self {
            artist: PluginArtistSender::new(),
            album: PluginAlbumSender::new(),
            audio_source: PluginAudioSourceSender::new(),
            auth: PluginAuthSender::new(),
            browse: PluginBrowseSender::new(),
            core: PluginCoreSender::new(),
            playlist: PluginPlaylistSender::new(),
            search: PluginSearchSender::new(),
            track: PluginTrackSender::new(),
            user: PluginUserSender::new(),
            event_tx,
            event_rx: Some(event_rx),
        }
    }

    pub async fn auth_state(&mut self, sink: StreamSink<AuthEventObject>) -> anyhow::Result<()> {
        let mut receiver = self
            .event_rx
            .take()
            .ok_or_else(|| anyhow::anyhow!("[SpotubePlugin][auth_state] Receiver already consumed"))?;

        tokio::spawn(async move {
            while let Some(event) = receiver.recv().await {
                if let Err(e) = sink.add(event) {
                    eprintln!("Failed to send auth event to stream sink: {:?}", e);
                    break;
                }
            }
        });

        Ok(())
    }

    pub async fn create_context(
        &self,
        plugin_script: String,
        plugin_config: PluginConfiguration,
        server_endpoint_url: String,
        server_secret: String,
        local_storage_dir: String,
    ) -> anyhow::Result<OpaqueSender> {
        let (command_tx, mut command_rx) = mpsc::channel(32);
        let (init_tx, init_rx) = tokio::sync::oneshot::channel::<anyhow::Result<()>>();
        let sender = self.event_tx.clone();

        let _thread_handle = thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();
            let local = LocalSet::new();
            if let Err(e) = local.block_on(&rt, async {
                let ctx_res = create_context(
                    server_endpoint_url,
                    server_secret,
                    plugin_config.slug(),
                    local_storage_dir,
                ).await;

                if let Err(e) = ctx_res {
                    let _ = init_tx.send(Err(e));
                    return anyhow::Ok(());
                }

                let (ctx, _runtime) = ctx_res.unwrap();

                let begin_injection = "console.log(globalThis);globalThis.module = {exports: {}};";

                let end_injection = "globalThis.pluginInstance = new module.exports.default();";
                let script = format!("{}\n{}\n{}", begin_injection, plugin_script, end_injection);

                let script_eval_res = async_with!(ctx => |cx| {
                    cx.eval::<(), _>(script.as_str())
                        .catch(&cx).map_err(|e| anyhow!("Failed to evaluate supplied plugin script: {}", e))
                }).await;

                if let Err(e) = script_eval_res {
                    let _ = init_tx.send(Err(e));
                    return anyhow::Ok(());
                }

                let on_auth_event_res = async_with!(ctx => |ctx|{
                    let globals = ctx.globals();
                    let callback = Func::new(move |event: Object| -> rquickjs::Result<()>{
                        let sender_clone = sender.clone();
                        let event_type_js: rquickjs::String = event.get("eventType")?;
                        let event_type = serde_json::from_value::<AuthEventType>(serde_json::Value::String(event_type_js.to_string()?));
                        if let Ok(event_type) =  event_type {
                            tokio::spawn(async move{
                                if let Err(e) = sender_clone.send(AuthEventObject{event_type}).await {
                                    eprintln!("Error sending auth event: {:?}", e);
                                }
                            });
                            Ok(())
                        } else {
                            Err(Error::FromJs{
                                from: "event.eventType",
                                to: "AuthEventType",
                                message: Some("Failed to deserialize eventType".to_string())
                            })
                        }
                    });

                    if plugin_config.abilities.contains(&PluginAbility::Authentication) {
                        if let Err(e) = globals.get::<_, Object>("pluginInstance")?.get::<_, Object>("auth")?.set(
                            "onAuthEvent", callback
                        ) {
                            eprintln!("Error setting auth event handler: {:?}", e);
                        }
                    }

                    Ok::<(), Error>(())
                })
                    .await
                    .map_err(|e| anyhow!("[onAuthEvent] {e}"));

                if let Err(e) = on_auth_event_res {
                    let _ = init_tx.send(Err(e));
                    return anyhow::Ok(());
                }

                let _ = init_tx.send(Ok(()));

                if let Err(e) = js_executor_thread(&mut command_rx, &ctx).await {
                    eprintln!("JS executor error: {}", e);
                }
                anyhow::Ok(())
            }) {
                eprintln!("[PluginInitializationError]: {}", e);
            }
        });

        init_rx
            .await
            .map_err(|e| anyhow!("Failed to receive initialization result: {}", e))??;

        Ok(OpaqueSender { sender: command_tx })
    }

    pub async fn close(&self, tx: OpaqueSender) -> anyhow::Result<()> {
        tx.sender.send(PluginCommand::Shutdown).await?;
        Ok(())
    }
}

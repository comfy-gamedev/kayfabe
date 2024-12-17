use std::{borrow::Cow, collections::HashMap, fmt::Debug, mem::take, sync::Arc};

use serde::{Deserialize, Serialize};
use tokio::sync::{broadcast, Mutex, RwLock};

use crate::SocketMessage;

pub const HOST_ID: i32 = 1;

/// Top-level app state.
pub struct AppState {
    /// Currently active lobbies. Lobbies are active for the lifetime of the host's websocket connection.
    pub active_lobbies: RwLock<HashMap<LobbyKey, Mutex<LobbyInfo>>>,
}

impl Debug for AppState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("AppState")
            .field(
                "active_lobbies",
                &self.active_lobbies.try_read().map_or_else(
                    |_| Cow::Borrowed("<locked>"),
                    |x| Cow::Owned(format!("{} lobbies", x.len())),
                ),
            )
            .finish()
    }
}

pub type AppStateRef = Arc<AppState>;

pub trait AppStateExt {
    /// Add a new lobby. Returns a guard that will remove the lobby when dropped.
    async fn add_lobby(
        &self,
        host_uuid: String,
        desktop_uuid: String,
        host_tx: broadcast::Sender<ChannelMessage>,
    ) -> LobbyInfoGuard;

    /// Add a new client to a lobby. Returns a guard that will remove the client when dropped.
    fn add_lobby_client(
        &self,
        lobby_info: &mut LobbyInfo,
        client_tx: broadcast::Sender<ChannelMessage>,
    ) -> LobbyClientGuard;
}

impl AppStateExt for AppStateRef {
    async fn add_lobby(
        &self,
        host_uuid: String,
        desktop_uuid: String,
        host_tx: broadcast::Sender<ChannelMessage>,
    ) -> LobbyInfoGuard {
        tracing::info!("Adding lobby {}/{}", host_uuid, desktop_uuid);

        let mut active_lobbies = self.active_lobbies.write().await;

        let lobby_key = LobbyKey::new(&host_uuid, &desktop_uuid);
        let lobby_info = LobbyInfo::new(desktop_uuid, host_tx);

        active_lobbies.insert(lobby_key.clone(), Mutex::new(lobby_info));

        LobbyInfoGuard {
            app_state: self.clone(),
            lobby_key,
        }
    }

    fn add_lobby_client(
        &self,
        lobby_info: &mut LobbyInfo,
        client_tx: broadcast::Sender<ChannelMessage>,
    ) -> LobbyClientGuard {
        let client_id = lobby_info.next_client_id;
        lobby_info.next_client_id += 1;

        tracing::info!(
            "Adding client {} to {}/{}",
            client_id,
            lobby_info.desktop_uuid,
            lobby_info.desktop_uuid
        );

        lobby_info
            .clients
            .insert(client_id, LobbyClient { tx: client_tx });

        let lobby_key = LobbyKey::new(&lobby_info.desktop_uuid, &lobby_info.desktop_uuid);

        LobbyClientGuard {
            app_state: self.clone(),
            lobby_key,
            client_id,
        }
    }
}

/// Guard that will remove the lobby when dropped.
pub struct LobbyInfoGuard {
    app_state: AppStateRef,
    lobby_key: LobbyKey,
}

impl Drop for LobbyInfoGuard {
    fn drop(&mut self) {
        let app_state = self.app_state.clone();
        let lobby_key = take(&mut self.lobby_key);
        tokio::spawn(async move {
            tracing::info!("Removing lobby {}", lobby_key.key);
            let mut active_lobbies = app_state.active_lobbies.write().await;
            active_lobbies.remove(&lobby_key);
        });
    }
}

/// Guard that will remove the client from the lobby when dropped.
pub struct LobbyClientGuard {
    pub app_state: AppStateRef,
    pub lobby_key: LobbyKey,
    pub client_id: i32,
}

impl Drop for LobbyClientGuard {
    fn drop(&mut self) {
        let app_state = self.app_state.clone();
        let lobby_key = take(&mut self.lobby_key);
        let client_id = self.client_id;
        tokio::spawn(async move {
            tracing::info!("Removing client {} from lobby {}", client_id, lobby_key.key);
            let active_lobbies = app_state.active_lobbies.read().await;
            if let Some(mutex) = active_lobbies.get(&lobby_key) {
                let mut lobby_info = mutex.lock().await;
                lobby_info.clients.remove(&client_id);
            }
        });
    }
}

#[derive(Clone)]
pub struct LobbyInfo {
    pub desktop_uuid: String,
    pub host_tx: broadcast::Sender<ChannelMessage>,
    pub clients: HashMap<i32, LobbyClient>,
    next_client_id: i32,
}

impl LobbyInfo {
    pub fn new(desktop_uuid: String, tx: broadcast::Sender<ChannelMessage>) -> Self {
        Self {
            desktop_uuid,
            next_client_id: 2,
            host_tx: tx,
            clients: HashMap::new(),
        }
    }
}

#[derive(Clone)]
pub struct LobbyClient {
    pub tx: broadcast::Sender<ChannelMessage>,
}

/// An opaque key representing a lobby.
#[derive(Default, Clone, Hash, Eq, PartialEq)]
pub struct LobbyKey {
    key: String,
}

impl LobbyKey {
    pub fn new(host_uuid: &str, desktop_uuid: &str) -> Self {
        Self {
            key: format!("{}/{}", host_uuid, desktop_uuid),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelMessage {
    /// Sender client ID or HOST_ID if sent by the host.
    pub sender_id: i32,
    pub message: SocketMessage,
}

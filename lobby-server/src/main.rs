use std::{collections::HashMap, net::SocketAddr, sync::Arc};

use anyhow::{anyhow, bail, ensure, Result};
use appstate::HOST_ID;
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        Path, State,
    },
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Router,
};
use futures_util::{sink::SinkExt, stream::StreamExt};
use tokio::sync::{broadcast, RwLock};
use tower_http::trace::TraceLayer;
use tracing::instrument;

use crate::appstate::{AppState, AppStateExt, AppStateRef, ChannelMessage, LobbyKey};
use crate::spawn::spawn_paired;
use crate::websocket::{SocketMessage, SocketMessageData, WebSocketExt};

mod appstate;
mod spawn;
mod websocket;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let app_state = Arc::new(AppState {
        active_lobbies: RwLock::new(HashMap::new()),
    });

    let app = Router::new()
        .route("/", get(root))
        .route("/lobby_ws", get(lobby_ws_handler))
        .route("/join/:host_uuid/:desktop_uuid", get(join_ws_handler))
        .layer(TraceLayer::new_for_http())
        .with_state(app_state);

    let port: u16 =
        std::env::var("PORT").map_or_else(|_| 3000, |x| x.parse().expect("Failed to parse PORT"));

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    tracing::info!("Listening on {}", addr);

    axum::serve(listener, app.into_make_service())
        .await
        .unwrap();
}

async fn root() -> Response {
    (StatusCode::OK, "Hello, world!\n").into_response()
}

#[instrument]
async fn lobby_ws_handler(ws: WebSocketUpgrade, State(app_state): State<AppStateRef>) -> Response {
    ws.on_upgrade(|socket| async move {
        let _ = handle_lobby_socket(socket, app_state).await;
    })
}

#[instrument(err, skip(socket))]
async fn handle_lobby_socket(mut socket: WebSocket, app_state: AppStateRef) -> Result<()> {
    // Wait for the first message from the host.
    let Some(initial_message) = socket.next_message().await else {
        // Host disconnected before anything happens. A bit strange, but not an error.
        tracing::info!("Host disconnected before anything happened.");
        return Ok(());
    };

    let initial_message = initial_message?;

    tracing::info!("Initial message: {:?}", initial_message);

    // The initial message should always be a ServerAnnounce.
    let SocketMessageData::ServerAnnounce {
        host_uuid,
        desktop_uuid,
    } = initial_message.data
    else {
        bail!("Invalid initial message");
    };

    let lobby_key = LobbyKey::new(&host_uuid, &desktop_uuid);

    let (host_tx, mut host_rx) = broadcast::channel::<ChannelMessage>(8);

    // Need to hold onto this guard object for the lifetime of the lobby.
    let _lobby_guard = app_state
        .add_lobby(host_uuid, desktop_uuid, host_tx.clone())
        .await;

    let (mut socket_sender, mut socket_receiver) = socket.split();

    spawn_paired(
        async move {
            // Pump messages from the channel (sent from a client) to the socket.
            while let Ok(msg) = host_rx.recv().await {
                tracing::debug!("Host receiving message: {:?}", msg);

                let msg = SocketMessage {
                    id: msg.sender_id,
                    data: msg.message.data,
                };

                socket_sender
                    .send(serde_json::to_string(&msg)?.into())
                    .await?;
            }

            Ok(())
        },
        async move {
            // Pump messages from the socket (sent from this host) to the target client's channel.
            while let Some(msg) = socket_receiver.next_message().await {
                let msg = msg?;

                tracing::debug!("Host sent message: {:?}", msg);

                let active_lobbies = app_state.active_lobbies.read().await;

                let lobby_info = active_lobbies
                    .get(&lobby_key)
                    .ok_or(anyhow!("lobby not found"))?
                    .lock()
                    .await;

                if let Some(client_info) = lobby_info.clients.get(&msg.id) {
                    client_info.tx.send(ChannelMessage {
                        sender_id: HOST_ID,
                        message: msg,
                    })?;
                }
            }
            Ok(())
        },
    )
    .await
    .into_inner()?
}

#[instrument]
async fn join_ws_handler(
    ws: WebSocketUpgrade,
    State(app_state): State<AppStateRef>,
    Path((host_uuid, desktop_uuid)): Path<(String, String)>,
) -> Response {
    let lobby_key = LobbyKey::new(&host_uuid, &desktop_uuid);

    let (client, client_rx, lobby_tx) = {
        let active_lobbies = app_state.active_lobbies.read().await;

        let Some(lobby_info) = active_lobbies.get(&lobby_key) else {
            return (StatusCode::NOT_FOUND, "Lobby not found").into_response();
        };

        let (client_tx, client_rx) = broadcast::channel::<ChannelMessage>(8);

        let mut lobby_info = lobby_info.lock().await;

        (
            app_state.add_lobby_client(&mut lobby_info, client_tx.clone()),
            client_rx,
            lobby_info.host_tx.clone(),
        )
    };

    let client_id = client.client_id;

    ws.on_upgrade(move |socket| async move {
        let _ = handle_join_socket(socket, app_state, client_id, client_rx, lobby_tx).await;
    })
}

#[instrument(err, skip(socket))]
async fn handle_join_socket(
    socket: WebSocket,
    app_state: AppStateRef,
    client_id: i32,
    mut client_rx: broadcast::Receiver<ChannelMessage>,
    lobby_tx: broadcast::Sender<ChannelMessage>,
) -> Result<()> {
    let (mut socket_sender, mut socket_receiver) = socket.split();

    socket_sender
        .send(Message::Text(serde_json::to_string(&SocketMessage {
            id: HOST_ID,
            data: SocketMessageData::ClientAnnounce { client_id },
        })?))
        .await?;

    spawn_paired(
        async move {
            // Pump messages from the channel (sent from the lobby) to the socket.
            while let Ok(msg) = client_rx.recv().await {
                tracing::debug!(
                    "Client {} receiving message from host: {:?}",
                    client_id,
                    msg
                );

                let msg = SocketMessage {
                    id: msg.sender_id,
                    data: msg.message.data,
                };

                socket_sender
                    .send(serde_json::to_string(&msg)?.into())
                    .await?;
            }

            Ok(())
        },
        async move {
            // Pump messages from the socket (sent from this client) to the lobby's channel.
            while let Some(msg) = socket_receiver.next_message().await {
                let msg = msg?;

                tracing::debug!("Client {} sent message: {:?}", client_id, msg);

                ensure!(msg.id == HOST_ID, "Invalid message, id should be HOST_ID.");

                lobby_tx.send(ChannelMessage {
                    sender_id: client_id,
                    message: msg,
                })?;
            }

            Ok(())
        },
    )
    .await
    .into_inner()?
}

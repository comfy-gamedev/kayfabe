use anyhow::{anyhow, Result};
use axum::extract::ws::Message;
use futures_util::{Stream, StreamExt};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SocketMessageData {
    ServerAnnounce {
        host_uuid: String,
        desktop_uuid: String,
    },
    ClientAnnounce {
        client_id: i32,
    },
    Offer {
        sdp: String,
    },
    Answer {
        sdp: String,
    },
    IceCandidate {
        candidate: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SocketMessage {
    /// The target or source of the message. The host's ID is always 0.
    pub id: i32,
    /// Message data.
    pub data: SocketMessageData,
}

pub trait WebSocketExt {
    /// Returns the next message from the socket, or `None` if the socket has been closed.
    ///
    /// Returns an `Err` if the message text cannot be deserialized.
    async fn next_message(&mut self) -> Option<Result<SocketMessage>>;
}

impl<T: Stream<Item = Result<Message, axum::Error>> + Unpin> WebSocketExt for T {
    async fn next_message(&mut self) -> Option<Result<SocketMessage>> {
        while let Some(msg) = self.next().await {
            match msg {
                Err(err) => return Some(Err(anyhow!(err))),
                Ok(Message::Text(msg)) => {
                    return Some(serde_json::from_str(&msg).map_err(|e| anyhow!(e)))
                }
                Ok(Message::Binary(_)) => {
                    return Some(Err(anyhow!("Binary messages not supported")))
                }
                Ok(Message::Close(_)) => return None,
                _ => continue,
            }
        }
        None
    }
}

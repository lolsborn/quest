---
Number: QEP-054
Title: Real-Time Web Framework (WebSockets + LiveView)
Author: Claude Code
Status: Draft
Created: 2025-10-16
---

# QEP-054: Real-Time Web Framework (WebSockets + LiveView)

## Overview

Expand Quest's web framework to include complete WebSocket support and a Phoenix LiveView-inspired reactive framework for building real-time web applications. This enables developers to build interactive, real-time features with minimal JavaScript, where server-side Quest code automatically synchronizes UI state with connected clients.

## Status

**Draft** - Design phase

## Goals

- Complete WebSocket API for bidirectional real-time communication
- Phoenix LiveView-inspired framework for reactive server-rendered UIs
- Automatic DOM patching and state synchronization
- Event handling with server-side validation
- Minimal client-side JavaScript required
- Excellent developer experience for building dashboards, chats, collaborative tools
- Seamless integration with existing Quest web server (QEP-051)

## Motivation

### Current State

Quest has a basic WebSocket registry (stub in [src/server.rs:48-97](../src/server.rs#L48-L97)) but no usable API for developers. Building real-time features requires:

- Manual WebSocket message handling
- Custom protocol design
- Complex client-side JavaScript
- State synchronization logic
- Race condition handling

### Real-World Use Cases

**1. Live Dashboards** - Real-time metrics, charts, system status
```quest
# Today: Complex polling, full page refreshes, manual updates
# Future: Auto-updating components, live data streaming
```

**2. Chat Applications** - Real-time messaging, presence, typing indicators
```quest
# Today: Long polling, WebSocket from scratch, manual DOM updates
# Future: Built-in broadcast, automatic UI sync
```

**3. Collaborative Tools** - Multi-user editing, live cursors, shared state
```quest
# Today: Complex conflict resolution, manual syncing
# Future: Automatic state distribution, built-in presence
```

**4. Live Forms** - Real-time validation, auto-save, multi-step wizards
```quest
# Today: AJAX requests, manual error display
# Future: Server-validated input, instant feedback
```

**5. Admin Panels** - Live logs, background job monitoring, notifications
```quest
# Today: Page refreshes, manual polling
# Future: Push updates, automatic rendering
```

## Design Philosophy

### Phoenix LiveView Inspiration

Phoenix LiveView revolutionized web development by making real-time UIs simple:

**Key Insights:**
1. **Server renders HTML** - Single source of truth, no API duplication
2. **Minimal diffs sent** - Only changed HTML sent over WebSocket
3. **Stateful connections** - Server holds session state per socket
4. **Events trigger renders** - User events → server handlers → automatic re-render
5. **Optimistic updates** - Client predicts changes while server processes

**Why This Works:**
- Eliminates client-state management complexity (no Redux/MobX needed)
- Server-side validation is authoritative
- Easy to reason about (just Quest code, no API contracts)
- Natural for Quest's scripting philosophy

### Quest LiveView Design

Adapt LiveView concepts to Quest's strengths:

- **Type-focused** (not macro-based like Phoenix)
- **Template-driven** (use existing `std/html/templates`)
- **Function-based events** (leverage Quest functions)
- **Dict-based state** (natural for Quest)
- **Progressive enhancement** (works with/without JS)

## Architecture

### Three-Layer Approach

```
┌─────────────────────────────────────────┐
│  Layer 1: Low-Level WebSocket API      │  ← Direct WebSocket control
│  (std/web/ws)                           │     for custom protocols
├─────────────────────────────────────────┤
│  Layer 2: Channels API                  │  ← Pub/sub messaging,
│  (std/web/channels)                     │     rooms, broadcasting
├─────────────────────────────────────────┤
│  Layer 3: LiveView Framework            │  ← Reactive UI components,
│  (std/web/liveview)                     │     automatic state sync
└─────────────────────────────────────────┘
```

**Layer 1** - For developers building custom real-time protocols (game servers, streaming)
**Layer 2** - For chat apps, notifications, pub/sub messaging
**Layer 3** - For reactive dashboards, forms, collaborative UIs (highest level)

## Layer 1: WebSocket API (std/web/ws)

### Basic WebSocket Handler

```quest
use "std/web" as web
use "std/web/ws" as ws

# Define WebSocket handler
web.websocket("/ws", fun (socket)
    # Called when connection opens
    socket.on_open(fun ()
        puts("Client connected: " .. socket.id())
        socket.send("Welcome!")
    end)

    # Called when message received
    socket.on_message(fun (data)
        puts("Received: " .. data)
        socket.send("Echo: " .. data)
    end)

    # Called when connection closes
    socket.on_close(fun (code, reason)
        puts("Client disconnected: " .. socket.id())
    end)

    # Called on error
    socket.on_error(fun (error)
        puts("WebSocket error: " .. error)
    end)
end)

fun handle_request(request)
    # Regular HTTP handler
    {"status": 200, "body": "Hello"}
end
```

### WebSocket Object API

```quest
# Socket instance methods (available in handlers)

socket.id()                    # Unique connection ID (UUID)
socket.send(message: Str)      # Send text message to this client
socket.send_bytes(data: Bytes) # Send binary message
socket.close(code: Int = 1000, reason: Str = "")  # Close connection
socket.state()                 # "open", "closing", "closed"

# Metadata
socket.get(key: Str)           # Get connection metadata
socket.set(key: Str, value)    # Store connection metadata
socket.remote_ip()             # Client IP address
socket.path()                  # WebSocket endpoint path
socket.headers()               # HTTP headers from upgrade request
```

### Broadcasting to Multiple Clients

```quest
use "std/web/ws" as ws

# Send to specific connection
ws.send_to(connection_id: Str, message: Str)

# Send to all connections on a path
ws.broadcast("/ws/chat", "New message!")

# Send to connections matching filter
ws.broadcast_if("/ws", fun (socket)
    socket.get("room") == "general"
end, "Hello room!")

# Get all active connections
let connections = ws.get_connections("/ws")
let i = 0
while i < connections.len()
    let socket = connections[i]
    puts("Connection: " .. socket.id())
    i = i + 1
end
```

### Example: Simple Chat Server

```quest
use "std/web" as web
use "std/web/ws" as ws

let users = {}  # Track usernames by socket ID

web.websocket("/chat", fun (socket)
    socket.on_open(fun ()
        socket.send("Enter your username:")
    end)

    socket.on_message(fun (data)
        let user_id = socket.id()

        # First message is username
        if not users[user_id]
            users[user_id] = data
            socket.send("Welcome, " .. data .. "!")
            ws.broadcast("/chat", "[" .. data .. " joined]")
        else
            # Broadcast chat message
            let username = users[user_id]
            let message = username .. ": " .. data
            ws.broadcast("/chat", message)
        end
    end)

    socket.on_close(fun (code, reason)
        let username = users[socket.id()]
        if username
            ws.broadcast("/chat", "[" .. username .. " left]")
            users = users.remove(socket.id())
        end
    end)
end)

fun handle_request(request)
    if request["path"] == "/"
        {"status": 200, "body": render_chat_page()}
    end
end

fun render_chat_page()
    html.render("chat.html")
end
```

**Client HTML (chat.html):**
```html
<!DOCTYPE html>
<html>
<body>
    <div id="messages"></div>
    <input id="input" type="text" />
    <script>
        const ws = new WebSocket('ws://localhost:3000/chat');
        const messages = document.getElementById('messages');
        const input = document.getElementById('input');

        ws.onmessage = (event) => {
            messages.innerHTML += '<p>' + event.data + '</p>';
        };

        input.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                ws.send(input.value);
                input.value = '';
            }
        });
    </script>
</body>
</html>
```

## Layer 2: Channels API (std/web/channels)

### Channels Concept

Channels provide a higher-level abstraction over WebSockets:

- **Topics** - Named channels (e.g., "room:lobby", "user:123", "game:456")
- **Join/Leave** - Explicit subscription model
- **Presence** - Track who's in a channel
- **Broadcast** - Send to all subscribers
- **Push** - Send to specific subscriber

### Channel Definition

```quest
use "std/web/channels" as channels

# Define channel handler
channels.channel("room:*", fun (socket, topic, params)
    # Called when client joins this channel
    socket.on_join(fun (payload)
        let room_id = topic.split(":")[1]
        puts("User joined room: " .. room_id)

        # Authorize join
        if not is_authorized(socket, room_id)
            return {"error": "Unauthorized"}
        end

        # Track presence
        socket.set("user_id", payload["user_id"])
        socket.set("username", payload["username"])

        # Notify others
        channels.broadcast(topic, "user_joined", {
            "user_id": payload["user_id"],
            "username": payload["username"]
        })

        # Return initial state
        return {
            "messages": get_room_messages(room_id),
            "users": get_room_users(room_id)
        }
    end)

    # Handle custom events
    socket.on("new_message", fun (payload)
        let message = payload["message"]
        let user_id = socket.get("user_id")

        # Save message
        save_message(room_id, user_id, message)

        # Broadcast to all in room
        channels.broadcast(topic, "new_message", {
            "user_id": user_id,
            "username": socket.get("username"),
            "message": message,
            "timestamp": time.now().iso()
        })

        return {"ok": true}
    end)

    socket.on("typing", fun (payload)
        # Broadcast to others (not self)
        channels.broadcast_from(socket, topic, "user_typing", {
            "user_id": socket.get("user_id")
        })
        return {"ok": true}
    end)

    socket.on_leave(fun ()
        channels.broadcast(topic, "user_left", {
            "user_id": socket.get("user_id")
        })
    end)
end)
```

### Client-Side Channel Usage

```javascript
// Client connects to channel
const socket = new Socket('/ws');
socket.connect();

const channel = socket.channel('room:lobby', {
    user_id: 123,
    username: 'Alice'
});

// Join channel
channel.join()
    .receive('ok', (data) => {
        console.log('Joined!', data);
        renderMessages(data.messages);
        renderUsers(data.users);
    })
    .receive('error', (reason) => {
        console.log('Join failed:', reason);
    });

// Listen for events
channel.on('new_message', (msg) => {
    addMessage(msg);
});

channel.on('user_joined', (data) => {
    addUser(data);
});

channel.on('user_left', (data) => {
    removeUser(data);
});

// Send events
document.getElementById('send').onclick = () => {
    const msg = document.getElementById('input').value;
    channel.push('new_message', { message: msg });
};
```

### Presence Tracking

```quest
use "std/web/channels" as channels
use "std/web/presence" as presence

channels.channel("room:*", fun (socket, topic, params)
    socket.on_join(fun (payload)
        # Track presence
        presence.track(socket, topic, {
            "user_id": payload["user_id"],
            "username": payload["username"],
            "joined_at": time.now().unix()
        })

        # Get current presence list
        let users = presence.list(topic)

        # Broadcast presence diff
        channels.broadcast(topic, "presence_state", users)

        return {"users": users}
    end)

    socket.on_leave(fun ()
        presence.untrack(socket, topic)
        let users = presence.list(topic)
        channels.broadcast(topic, "presence_state", users)
    end)
end)
```

## Layer 3: LiveView Framework (std/web/liveview)

### LiveView Concept

LiveView enables building reactive UIs with server-side rendering:

1. **Initial HTTP request** → Server renders full HTML page
2. **WebSocket upgrade** → Connection established
3. **User interactions** → Events sent to server
4. **Server updates state** → Minimal HTML diff sent back
5. **Client patches DOM** → UI updates automatically

**No React/Vue/Svelte needed!** Just Quest code and HTML templates.

### Basic LiveView Example

```quest
use "std/web/liveview" as lv

# Define LiveView component
let CounterView = lv.component(fun ()
    # Initial state
    let state = {"count": 0}

    # Render function
    fun render(assigns)
        lv.template("""
            <div>
                <h1>Count: <%= count %></h1>
                <button phx-click="increment">+</button>
                <button phx-click="decrement">-</button>
                <button phx-click="reset">Reset</button>
            </div>
        """, assigns)
    end

    # Event handlers
    fun handle_event(event, payload, socket)
        if event == "increment"
            socket.assign("count", socket.get("count") + 1)
        elif event == "decrement"
            socket.assign("count", socket.get("count") - 1)
        elif event == "reset"
            socket.assign("count", 0)
        end
        return socket
    end

    return {
        "state": state,
        "render": render,
        "handle_event": handle_event
    }
end)

# Mount LiveView at route
lv.mount("/counter", CounterView)

fun handle_request(request)
    # Fallback for non-LiveView routes
    {"status": 404, "body": "Not found"}
end
```

**That's it!** No JavaScript needed. LiveView handles:
- WebSocket connection
- Event binding
- DOM diffing/patching
- State synchronization

### LiveView with Forms

```quest
use "std/web/liveview" as lv

let RegistrationView = lv.component(fun ()
    let state = {
        "username": "",
        "email": "",
        "password": "",
        "errors": {}
    }

    fun render(assigns)
        lv.template("""
            <form phx-submit="register" phx-change="validate">
                <h2>Register</h2>

                <input
                    type="text"
                    name="username"
                    value="<%= username %>"
                    phx-debounce="300" />
                <% if errors.username %>
                    <span class="error"><%= errors.username %></span>
                <% end %>

                <input
                    type="email"
                    name="email"
                    value="<%= email %>"
                    phx-debounce="300" />
                <% if errors.email %>
                    <span class="error"><%= errors.email %></span>
                <% end %>

                <input
                    type="password"
                    name="password"
                    value="<%= password %>" />
                <% if errors.password %>
                    <span class="error"><%= errors.password %></span>
                <% end %>

                <button type="submit">Register</button>
            </form>
        """, assigns)
    end

    fun handle_event(event, payload, socket)
        if event == "validate"
            # Live validation as user types
            socket.assign("username", payload["username"])
            socket.assign("email", payload["email"])
            socket.assign("password", payload["password"])

            let errors = validate_registration(payload)
            socket.assign("errors", errors)

        elif event == "register"
            # Final submission
            let errors = validate_registration(payload)

            if errors.empty()
                # Create user
                create_user(payload)
                socket.redirect("/dashboard")
            else
                socket.assign("errors", errors)
            end
        end

        return socket
    end

    return {
        "state": state,
        "render": render,
        "handle_event": handle_event
    }
end)

fun validate_registration(data)
    let errors = {}

    if data["username"].len() < 3
        errors["username"] = "Must be at least 3 characters"
    end

    if not data["email"].contains("@")
        errors["email"] = "Invalid email"
    end

    if data["password"].len() < 8
        errors["password"] = "Must be at least 8 characters"
    end

    return errors
end
```

**Features demonstrated:**
- `phx-change` - Triggers event on input change
- `phx-debounce` - Delays events (avoid spam)
- `phx-submit` - Form submission
- Live validation
- Conditional rendering (`<% if ... %>`)
- Server-side redirects

### LiveView with Live Data

```quest
use "std/web/liveview" as lv
use "std/db/postgres" as db

let DashboardView = lv.component(fun ()
    let conn = db.connect("postgres://localhost/metrics")

    let state = {
        "metrics": fetch_metrics(conn),
        "last_updated": time.now()
    }

    fun render(assigns)
        lv.template("""
            <div class="dashboard">
                <h1>System Dashboard</h1>
                <p>Last updated: <%= last_updated.format("%H:%M:%S") %></p>

                <div class="metrics">
                    <% for metric in metrics %>
                        <div class="metric">
                            <h3><%= metric.name %></h3>
                            <p class="value"><%= metric.value %></p>
                            <span class="trend <%= metric.trend %>">
                                <%= metric.change %>%
                            </span>
                        </div>
                    <% end %>
                </div>
            </div>
        """, assigns)
    end

    # Lifecycle hooks
    fun mount(params, session, socket)
        # Schedule periodic update
        lv.schedule(socket, "refresh", 5000)  # Every 5 seconds
        return socket
    end

    fun handle_info(msg, socket)
        if msg == "refresh"
            # Fetch fresh data
            socket.assign("metrics", fetch_metrics(conn))
            socket.assign("last_updated", time.now())

            # Schedule next update
            lv.schedule(socket, "refresh", 5000)
        end

        return socket
    end

    return {
        "state": state,
        "render": render,
        "mount": mount,
        "handle_info": handle_info
    }
end)

fun fetch_metrics(conn)
    let cursor = conn.cursor()
    cursor.execute("SELECT name, value, trend, change FROM metrics")
    return cursor.fetch_all()
end
```

**Key features:**
- `mount` - Lifecycle hook on connection
- `handle_info` - Process messages (timers, broadcasts)
- `lv.schedule` - Periodic updates
- Automatic re-rendering on state change

### LiveView with Pub/Sub

```quest
use "std/web/liveview" as lv
use "std/web/pubsub" as pubsub

let ChatView = lv.component(fun ()
    let state = {
        "messages": [],
        "users": [],
        "current_message": ""
    }

    fun mount(params, session, socket)
        let room_id = params["room_id"]
        let user_id = session["user_id"]

        # Subscribe to room updates
        pubsub.subscribe(socket, "room:" .. room_id)

        # Load initial data
        socket.assign("messages", load_messages(room_id))
        socket.assign("room_id", room_id)
        socket.assign("user_id", user_id)

        return socket
    end

    fun render(assigns)
        lv.template("""
            <div class="chat">
                <div class="messages">
                    <% for msg in messages %>
                        <div class="message">
                            <strong><%= msg.username %>:</strong>
                            <%= msg.text %>
                        </div>
                    <% end %>
                </div>

                <form phx-submit="send_message">
                    <input
                        type="text"
                        name="message"
                        value="<%= current_message %>"
                        phx-change="update_message"
                        autocomplete="off" />
                    <button type="submit">Send</button>
                </form>
            </div>
        """, assigns)
    end

    fun handle_event(event, payload, socket)
        if event == "update_message"
            socket.assign("current_message", payload["message"])

        elif event == "send_message"
            let room_id = socket.get("room_id")
            let user_id = socket.get("user_id")
            let message = socket.get("current_message")

            # Save message
            save_message(room_id, user_id, message)

            # Broadcast to all viewers of this room
            pubsub.broadcast("room:" .. room_id, "new_message", {
                "user_id": user_id,
                "username": get_username(user_id),
                "text": message
            })

            # Clear input
            socket.assign("current_message", "")
        end

        return socket
    end

    fun handle_info(msg, socket)
        # Receive broadcasts from pubsub
        if msg["event"] == "new_message"
            let messages = socket.get("messages")
            messages.push(msg["payload"])
            socket.assign("messages", messages)
        end

        return socket
    end

    return {
        "state": state,
        "mount": mount,
        "render": render,
        "handle_event": handle_event,
        "handle_info": handle_info
    }
end)
```

**Pub/Sub features:**
- `pubsub.subscribe` - Listen to topic
- `pubsub.broadcast` - Send to all subscribers
- Automatic delivery to `handle_info`
- Multiple LiveViews can share state

### LiveView Component Composition

```quest
use "std/web/liveview" as lv

# Reusable search component
let SearchComponent = lv.component(fun ()
    let state = {
        "query": "",
        "results": [],
        "loading": false
    }

    fun render(assigns)
        lv.template("""
            <div class="search">
                <input
                    type="text"
                    value="<%= query %>"
                    phx-change="search"
                    phx-debounce="500"
                    placeholder="Search..." />

                <% if loading %>
                    <div class="spinner">Searching...</div>
                <% end %>

                <ul class="results">
                    <% for result in results %>
                        <li phx-click="select" phx-value-id="<%= result.id %>">
                            <%= result.title %>
                        </li>
                    <% end %>
                </ul>
            </div>
        """, assigns)
    end

    fun handle_event(event, payload, socket)
        if event == "search"
            socket.assign("query", payload["value"])
            socket.assign("loading", true)

            # Perform search (async in real impl)
            let results = search_database(payload["value"])
            socket.assign("results", results)
            socket.assign("loading", false)

        elif event == "select"
            # Notify parent component
            lv.send(socket.parent(), "item_selected", {
                "id": payload["id"]
            })
        end

        return socket
    end

    return {
        "state": state,
        "render": render,
        "handle_event": handle_event
    }
end)

# Parent component using SearchComponent
let ProductBrowserView = lv.component(fun ()
    let state = {
        "selected_product": nil,
        "details": nil
    }

    fun render(assigns)
        lv.template("""
            <div class="browser">
                <h1>Product Browser</h1>

                <%= lv.live_component(SearchComponent, id: "search") %>

                <% if selected_product %>
                    <div class="details">
                        <h2><%= details.name %></h2>
                        <p><%= details.description %></p>
                        <p class="price">$<%= details.price %></p>
                    </div>
                <% end %>
            </div>
        """, assigns)
    end

    fun handle_info(msg, socket)
        if msg["event"] == "item_selected"
            let product_id = msg["payload"]["id"]
            let details = load_product_details(product_id)

            socket.assign("selected_product", product_id)
            socket.assign("details", details)
        end

        return socket
    end

    return {
        "state": state,
        "render": render,
        "handle_info": handle_info
    }
end)
```

**Component features:**
- `lv.live_component` - Embed child component
- `lv.send` - Parent-child communication
- Isolated state per component
- Reusable across views

## Implementation Details

### Rust Implementation

#### WebSocket Integration

```rust
// src/server.rs additions

use axum::extract::ws::{WebSocket, Message, WebSocketUpgrade};
use std::sync::Arc;
use tokio::sync::{mpsc, RwLock};

#[derive(Clone)]
pub struct WebSocketManager {
    connections: Arc<RwLock<HashMap<String, WebSocketConnection>>>,
}

struct WebSocketConnection {
    id: String,
    path: String,
    sender: mpsc::UnboundedSender<Message>,
    metadata: Arc<RwLock<HashMap<String, QValue>>>,
}

impl WebSocketManager {
    pub fn new() -> Self {
        Self {
            connections: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn handle_socket(
        &self,
        ws: WebSocket,
        path: String,
        handler: QValue,
        scope: &mut Scope,
    ) {
        let conn_id = uuid::Uuid::new_v4().to_string();
        let (tx, mut rx) = mpsc::unbounded_channel();

        // Register connection
        {
            let mut conns = self.connections.write().await;
            conns.insert(conn_id.clone(), WebSocketConnection {
                id: conn_id.clone(),
                path: path.clone(),
                sender: tx.clone(),
                metadata: Arc::new(RwLock::new(HashMap::new())),
            });
        }

        // Split WebSocket
        let (mut ws_tx, mut ws_rx) = ws.split();

        // Call on_open handler
        self.call_handler(handler.clone(), "on_open", vec![], scope);

        // Spawn sender task
        let sender_task = tokio::spawn(async move {
            while let Some(msg) = rx.recv().await {
                if ws_tx.send(msg).await.is_err() {
                    break;
                }
            }
        });

        // Receiver loop
        while let Some(Ok(msg)) = ws_rx.next().await {
            match msg {
                Message::Text(text) => {
                    let args = vec![QValue::Str(QString::new(text))];
                    self.call_handler(handler.clone(), "on_message", args, scope);
                }
                Message::Binary(data) => {
                    let args = vec![QValue::Bytes(QBytes::new(data.to_vec()))];
                    self.call_handler(handler.clone(), "on_message", args, scope);
                }
                Message::Close(frame) => {
                    let code = frame.as_ref().map(|f| f.code).unwrap_or(1000);
                    let reason = frame.as_ref()
                        .and_then(|f| f.reason.as_ref())
                        .map(|r| r.to_string())
                        .unwrap_or_default();

                    let args = vec![
                        QValue::Int(QInt::new(code as i64)),
                        QValue::Str(QString::new(reason)),
                    ];
                    self.call_handler(handler.clone(), "on_close", args, scope);
                    break;
                }
                _ => {}
            }
        }

        // Cleanup
        sender_task.abort();
        let mut conns = self.connections.write().await;
        conns.remove(&conn_id);
    }

    fn call_handler(
        &self,
        handler: QValue,
        method: &str,
        args: Vec<QValue>,
        scope: &mut Scope,
    ) {
        // Call Quest function handler[method](args...)
        // Implementation uses existing call_method_on_value infrastructure
    }

    pub async fn broadcast(&self, path: &str, message: String) {
        let conns = self.connections.read().await;
        for conn in conns.values() {
            if conn.path == path {
                let _ = conn.sender.send(Message::Text(message.clone()));
            }
        }
    }
}
```

#### LiveView State Management

```rust
// src/liveview.rs (new file)

use morphdom::Diff;  // HTML diffing library
use serde_json::Value as JsonValue;

pub struct LiveViewSocket {
    id: String,
    assigns: HashMap<String, QValue>,
    connected: bool,
    changed: HashSet<String>,
}

impl LiveViewSocket {
    pub fn assign(&mut self, key: &str, value: QValue) {
        self.assigns.insert(key.to_string(), value);
        self.changed.insert(key.to_string());
    }

    pub fn get(&self, key: &str) -> Option<&QValue> {
        self.assigns.get(key)
    }

    pub fn render(&self, component: &QValue, scope: &mut Scope) -> String {
        // Call component's render function with current assigns
        let render_fn = component.get_field("render").unwrap();
        let result = call_function(render_fn, vec![assigns_to_dict(&self.assigns)], scope);
        result.as_str().unwrap()
    }

    pub fn diff(&self, old_html: &str, new_html: &str) -> Vec<Patch> {
        // Use morphdom-like algorithm to generate minimal patches
        morphdom::diff(old_html, new_html)
    }
}

pub struct LiveViewManager {
    views: Arc<RwLock<HashMap<String, LiveViewSocket>>>,
}

impl LiveViewManager {
    pub async fn mount(&self, path: &str, component: QValue, scope: &mut Scope) {
        // Initial HTTP request renders full page
        let socket = LiveViewSocket::new();
        let html = socket.render(&component, scope);

        // Return HTML with LiveView JS client embedded
        let full_page = format!(r#"
            <!DOCTYPE html>
            <html>
            <head>
                <script src="/assets/liveview.js"></script>
            </head>
            <body>
                <div id="liveview" data-phx-main="true">
                    {}
                </div>
                <script>
                    const liveSocket = new LiveSocket('/live/websocket');
                    liveSocket.connect();
                </script>
            </body>
            </html>
        "#, html);

        // Store socket for WebSocket upgrade
        self.views.write().await.insert(socket.id.clone(), socket);
    }

    pub async fn handle_event(
        &self,
        socket_id: &str,
        event: &str,
        payload: JsonValue,
        scope: &mut Scope,
    ) -> Vec<Patch> {
        let mut views = self.views.write().await;
        let socket = views.get_mut(socket_id).unwrap();

        // Save old HTML
        let old_html = socket.render(&component, scope);

        // Call event handler
        let handler = component.get_field("handle_event").unwrap();
        call_function(handler, vec![
            QValue::Str(QString::new(event)),
            json_to_qvalue(payload),
            socket_ref,
        ], scope);

        // Render new HTML
        let new_html = socket.render(&component, scope);

        // Generate diff
        socket.diff(&old_html, &new_html)
    }
}
```

### Quest Module Structure

```
lib/std/web/
├── ws.q              # Layer 1: Low-level WebSocket API
├── channels.q        # Layer 2: Pub/sub channels
├── presence.q        # Presence tracking
├── pubsub.q          # Publish/subscribe
└── liveview.q        # Layer 3: Reactive UI framework
```

### Client-Side JavaScript

**Minimal JavaScript library** (`lib/std/web/assets/liveview.js`):

```javascript
class LiveSocket {
    constructor(endpoint) {
        this.endpoint = endpoint;
        this.socket = null;
        this.viewId = null;
    }

    connect() {
        this.socket = new WebSocket(this.endpoint);

        this.socket.onopen = () => {
            console.log('LiveView connected');
            this.joinView();
        };

        this.socket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            this.handleMessage(data);
        };

        this.socket.onclose = () => {
            console.log('LiveView disconnected, reconnecting...');
            setTimeout(() => this.connect(), 1000);
        };

        // Bind event listeners
        document.addEventListener('click', (e) => {
            const target = e.target.closest('[phx-click]');
            if (target) {
                e.preventDefault();
                const event = target.getAttribute('phx-click');
                const value = this.extractValue(target);
                this.pushEvent(event, value);
            }
        });

        document.addEventListener('submit', (e) => {
            const target = e.target.closest('[phx-submit]');
            if (target) {
                e.preventDefault();
                const event = target.getAttribute('phx-submit');
                const formData = new FormData(target);
                const data = Object.fromEntries(formData);
                this.pushEvent(event, data);
            }
        });

        document.addEventListener('input', (e) => {
            const target = e.target.closest('[phx-change]');
            if (target) {
                const event = target.getAttribute('phx-change');
                const debounce = target.getAttribute('phx-debounce') || 0;

                clearTimeout(target._debounce);
                target._debounce = setTimeout(() => {
                    const formData = new FormData(target.form || target);
                    const data = Object.fromEntries(formData);
                    this.pushEvent(event, data);
                }, debounce);
            }
        });
    }

    joinView() {
        const msg = {
            type: 'join',
            view_id: document.getElementById('liveview').dataset.phxMain
        };
        this.socket.send(JSON.stringify(msg));
    }

    pushEvent(event, payload) {
        const msg = {
            type: 'event',
            event: event,
            payload: payload
        };
        this.socket.send(JSON.stringify(msg));
    }

    handleMessage(data) {
        if (data.type === 'diff') {
            this.applyDiff(data.diff);
        } else if (data.type === 'redirect') {
            window.location.href = data.to;
        }
    }

    applyDiff(patches) {
        // Apply HTML patches using morphdom
        patches.forEach(patch => {
            const element = document.querySelector(`[phx-id="${patch.id}"]`);
            if (element) {
                morphdom(element, patch.html);
            }
        });
    }

    extractValue(element) {
        const data = {};
        for (const attr of element.attributes) {
            if (attr.name.startsWith('phx-value-')) {
                const key = attr.name.replace('phx-value-', '');
                data[key] = attr.value;
            }
        }
        return data;
    }
}
```

## Use Case Examples

### Use Case 1: Live Dashboard

```quest
use "std/web/liveview" as lv
use "std/db/postgres" as db

let DashboardView = lv.component(fun ()
    let conn = db.connect("postgres://localhost/monitoring")

    let state = {
        "cpu": 0,
        "memory": 0,
        "requests_per_sec": 0,
        "active_users": 0,
        "alerts": []
    }

    fun mount(params, session, socket)
        # Initial data load
        refresh_metrics(socket, conn)

        # Update every 2 seconds
        lv.schedule(socket, "refresh", 2000)

        return socket
    end

    fun render(assigns)
        lv.template("""
            <div class="dashboard">
                <h1>System Dashboard</h1>

                <div class="metrics">
                    <div class="metric <%= cpu_class(cpu) %>">
                        <h3>CPU</h3>
                        <div class="value"><%= cpu %>%</div>
                    </div>

                    <div class="metric">
                        <h3>Memory</h3>
                        <div class="value"><%= memory %>%</div>
                    </div>

                    <div class="metric">
                        <h3>Requests/sec</h3>
                        <div class="value"><%= requests_per_sec %></div>
                    </div>

                    <div class="metric">
                        <h3>Active Users</h3>
                        <div class="value"><%= active_users %></div>
                    </div>
                </div>

                <div class="alerts">
                    <h2>Alerts</h2>
                    <% if alerts.empty() %>
                        <p class="success">All systems operational</p>
                    <% else %>
                        <% for alert in alerts %>
                            <div class="alert <%= alert.severity %>">
                                <strong><%= alert.title %></strong>
                                <p><%= alert.message %></p>
                                <button phx-click="dismiss_alert" phx-value-id="<%= alert.id %>">
                                    Dismiss
                                </button>
                            </div>
                        <% end %>
                    <% end %>
                </div>
            </div>
        """, assigns)
    end

    fun handle_info(msg, socket)
        if msg == "refresh"
            refresh_metrics(socket, conn)
            lv.schedule(socket, "refresh", 2000)
        end
        return socket
    end

    fun handle_event(event, payload, socket)
        if event == "dismiss_alert"
            let alerts = socket.get("alerts")
            alerts = alerts.filter(fun (a) a["id"] != payload["id"] end)
            socket.assign("alerts", alerts)
        end
        return socket
    end

    fun refresh_metrics(socket, conn)
        let cursor = conn.cursor()
        cursor.execute("SELECT * FROM metrics WHERE timestamp > NOW() - INTERVAL '1 minute'")
        let metrics = cursor.fetch_one()

        socket.assign("cpu", metrics["cpu"])
        socket.assign("memory", metrics["memory"])
        socket.assign("requests_per_sec", metrics["requests_per_sec"])
        socket.assign("active_users", metrics["active_users"])

        # Fetch alerts
        cursor.execute("SELECT * FROM alerts WHERE dismissed = false ORDER BY created_at DESC")
        socket.assign("alerts", cursor.fetch_all())
    end

    fun cpu_class(cpu)
        if cpu > 90
            "critical"
        elif cpu > 70
            "warning"
        else
            "normal"
        end
    end

    return {
        "state": state,
        "mount": mount,
        "render": render,
        "handle_info": handle_info,
        "handle_event": handle_event
    }
end)

lv.mount("/dashboard", DashboardView)
```

### Use Case 2: Collaborative Text Editor

```quest
use "std/web/liveview" as lv
use "std/web/pubsub" as pubsub

let EditorView = lv.component(fun ()
    let state = {
        "content": "",
        "cursors": {},
        "doc_id": nil,
        "user_id": nil
    }

    fun mount(params, session, socket)
        let doc_id = params["doc_id"]
        let user_id = session["user_id"]

        # Load document
        let doc = load_document(doc_id)
        socket.assign("content", doc["content"])
        socket.assign("doc_id", doc_id)
        socket.assign("user_id", user_id)

        # Subscribe to document updates
        pubsub.subscribe(socket, "doc:" .. doc_id)

        # Announce presence
        pubsub.broadcast("doc:" .. doc_id, "user_joined", {
            "user_id": user_id,
            "username": session["username"]
        })

        return socket
    end

    fun render(assigns)
        lv.template("""
            <div class="editor">
                <div class="toolbar">
                    <h2>Document <%= doc_id %></h2>
                    <div class="users">
                        <% for user_id, cursor in cursors %>
                            <span class="user" style="color: <%= cursor.color %>">
                                <%= cursor.username %>
                            </span>
                        <% end %>
                    </div>
                </div>

                <div class="editor-area">
                    <textarea
                        phx-change="update_content"
                        phx-hook="Editor"
                        phx-debounce="100"
                    ><%= content %></textarea>
                </div>
            </div>
        """, assigns)
    end

    fun handle_event(event, payload, socket)
        if event == "update_content"
            let content = payload["value"]
            let cursor = payload["cursor"]

            # Save to DB (debounced in real impl)
            save_document(socket.get("doc_id"), content)

            # Broadcast change to other users
            pubsub.broadcast("doc:" .. socket.get("doc_id"), "content_updated", {
                "user_id": socket.get("user_id"),
                "content": content,
                "cursor": cursor
            })

            socket.assign("content", content)
        end

        return socket
    end

    fun handle_info(msg, socket)
        let event = msg["event"]

        if event == "content_updated"
            let payload = msg["payload"]

            # Don't update if it's our own change
            if payload["user_id"] != socket.get("user_id")
                socket.assign("content", payload["content"])

                # Update cursor position
                let cursors = socket.get("cursors")
                cursors[payload["user_id"]] = payload["cursor"]
                socket.assign("cursors", cursors)
            end

        elif event == "user_joined"
            let payload = msg["payload"]
            let cursors = socket.get("cursors")
            cursors[payload["user_id"]] = {
                "username": payload["username"],
                "color": generate_color(payload["user_id"])
            }
            socket.assign("cursors", cursors)

        elif event == "user_left"
            let payload = msg["payload"]
            let cursors = socket.get("cursors")
            cursors = cursors.remove(payload["user_id"])
            socket.assign("cursors", cursors)
        end

        return socket
    end

    return {
        "state": state,
        "mount": mount,
        "render": render,
        "handle_event": handle_event,
        "handle_info": handle_info
    }
end)

lv.mount("/editor/:doc_id", EditorView)
```

### Use Case 3: Real-Time Notifications

```quest
use "std/web/liveview" as lv
use "std/web/pubsub" as pubsub

let NotificationComponent = lv.component(fun ()
    let state = {
        "notifications": [],
        "unread_count": 0
    }

    fun mount(params, session, socket)
        let user_id = session["user_id"]

        # Subscribe to user's notification channel
        pubsub.subscribe(socket, "user:" .. user_id .. ":notifications")

        # Load recent notifications
        let notifs = load_notifications(user_id)
        socket.assign("notifications", notifs)
        socket.assign("unread_count", count_unread(notifs))

        return socket
    end

    fun render(assigns)
        lv.template("""
            <div class="notifications">
                <button phx-click="toggle" class="notification-bell">
                    🔔
                    <% if unread_count > 0 %>
                        <span class="badge"><%= unread_count %></span>
                    <% end %>
                </button>

                <div class="notification-dropdown" style="display: <%= open ? 'block' : 'none' %>">
                    <% if notifications.empty() %>
                        <p>No notifications</p>
                    <% else %>
                        <% for notif in notifications %>
                            <div class="notification <%= notif.read ? '' : 'unread' %>">
                                <p><%= notif.message %></p>
                                <span class="time"><%= format_time(notif.created_at) %></span>
                                <button phx-click="mark_read" phx-value-id="<%= notif.id %>">
                                    Mark read
                                </button>
                            </div>
                        <% end %>
                    <% end %>
                </div>
            </div>
        """, assigns)
    end

    fun handle_event(event, payload, socket)
        if event == "toggle"
            socket.assign("open", not socket.get("open"))

        elif event == "mark_read"
            let notif_id = payload["id"]
            mark_notification_read(notif_id)

            let notifs = socket.get("notifications")
            notifs = notifs.map(fun (n)
                if n["id"] == notif_id
                    n["read"] = true
                end
                n
            end)

            socket.assign("notifications", notifs)
            socket.assign("unread_count", count_unread(notifs))
        end

        return socket
    end

    fun handle_info(msg, socket)
        if msg["event"] == "new_notification"
            let notif = msg["payload"]
            let notifs = socket.get("notifications")
            notifs = [notif] .. notifs  # Prepend
            socket.assign("notifications", notifs)
            socket.assign("unread_count", socket.get("unread_count") + 1)
        end

        return socket
    end

    return {
        "state": state,
        "mount": mount,
        "render": render,
        "handle_event": handle_event,
        "handle_info": handle_info
    }
end)

# Can be embedded in any LiveView
# <%= lv.live_component(NotificationComponent, id: "notifications") %>
```

## Security Considerations

### WebSocket Authentication

```quest
use "std/web" as web
use "std/web/ws" as ws

web.websocket("/ws/secure", fun (socket)
    # Verify token from headers
    let token = socket.headers()["authorization"]

    if not verify_token(token)
        socket.close(4401, "Unauthorized")
        return
    end

    let user_id = extract_user_id(token)
    socket.set("user_id", user_id)
    socket.set("authenticated", true)

    socket.on_message(fun (data)
        # All messages have auth context
        let user_id = socket.get("user_id")
        process_authenticated_message(user_id, data)
    end)
end)
```

### LiveView CSRF Protection

```quest
# Automatic CSRF token validation
# LiveView includes CSRF token in WebSocket connection

fun mount(params, session, socket)
    # Session is validated by LiveView framework
    # Only authenticated users reach this point
    let user_id = session["user_id"]

    # Verify user has access to resource
    if not can_access?(user_id, params["doc_id"])
        socket.redirect("/unauthorized")
        return socket
    end

    # Safe to proceed
    return socket
end
```

### Input Validation

```quest
fun handle_event(event, payload, socket)
    if event == "submit_form"
        # Always validate server-side
        let errors = validate_input(payload)

        if not errors.empty()
            socket.assign("errors", errors)
            return socket
        end

        # Safe to process
        process_form(payload)
    end

    return socket
end
```

### Rate Limiting

```quest
use "std/web/liveview" as lv

fun handle_event(event, payload, socket)
    # Check rate limit
    let user_id = socket.get("user_id")
    if exceeded_rate_limit?(user_id, event)
        socket.push_event("rate_limited", {
            "message": "Too many requests, please slow down"
        })
        return socket
    end

    # Process event
    # ...
end
```

## Performance Considerations

### Diffing Strategy

- **Full diff** on initial render
- **Targeted diff** for subsequent updates (only changed assigns)
- **Keyed elements** for efficient list rendering

### Connection Pooling

```quest
# Reuse database connections across LiveView instances
# Don't create new connection per socket

let conn_pool = db.create_pool("postgres://localhost/app", {
    "max_connections": 20,
    "min_connections": 5
})

let MyView = lv.component(fun ()
    # Use pool instead of individual connection
    fun mount(params, session, socket)
        let conn = conn_pool.acquire()
        socket.set("conn", conn)
        return socket
    end

    fun terminate(reason, socket)
        let conn = socket.get("conn")
        conn_pool.release(conn)
    end
end)
```

### Broadcast Optimization

```quest
# Don't send diffs to sender
pubsub.broadcast_from(socket, topic, event, payload)

# Batch updates
pubsub.broadcast_batch(topic, events)

# Selective delivery
pubsub.broadcast_if(topic, fun (socket)
    socket.get("subscribed_to_alerts")
end, event, payload)
```

## Testing Strategy

### WebSocket Tests

```quest
use "std/test" as test
use "std/web/ws" as ws

test.describe("WebSocket", fun ()
    test.it("accepts connection and echoes messages", fun ()
        # Start test server with WebSocket handler
        let server = start_test_server()

        # Connect client
        let client = ws.test_client("ws://localhost:#{server.port}/ws")
        client.connect()

        # Send message
        client.send("Hello")

        # Verify response
        let msg = client.receive()
        test.assert_eq(msg, "Echo: Hello")

        client.close()
        server.stop()
    end)
end)
```

### LiveView Tests

```quest
use "std/test" as test
use "std/web/liveview" as lv

test.describe("CounterView", fun ()
    test.it("increments count on button click", fun ()
        # Mount view
        let view = lv.test_mount(CounterView)

        # Initial render
        let html = view.render()
        test.assert(html.contains("Count: 0"))

        # Trigger event
        view.click("increment")

        # Verify updated state
        let html = view.render()
        test.assert(html.contains("Count: 1"))
    end)

    test.it("receives broadcasts", fun ()
        let view = lv.test_mount(ChatView, {"room_id": "test"})

        # Simulate broadcast
        pubsub.test_broadcast("room:test", "new_message", {
            "user_id": 123,
            "text": "Hello"
        })

        # Verify message appears
        let html = view.render()
        test.assert(html.contains("Hello"))
    end)
end)
```

## Documentation Plan

### Add to docs/docs/

1. **websockets.md** - Complete WebSocket API reference
2. **channels.md** - Channels and pub/sub guide
3. **liveview.md** - LiveView framework guide
4. **realtime-examples.md** - Cookbook of common patterns

### Update CLAUDE.md

```markdown
## Real-Time Web Applications

Quest provides three layers for building real-time features:

**Layer 1: WebSockets** - Low-level bidirectional communication
```quest
use "std/web" as web
web.websocket("/ws", fun (socket)
    socket.on_message(fun (data)
        socket.send("Echo: " .. data)
    end)
end)
```

**Layer 2: Channels** - Pub/sub messaging with rooms
```quest
use "std/web/channels" as channels
channels.channel("room:*", fun (socket, topic, params)
    socket.on_join(fun (payload)
        channels.broadcast(topic, "user_joined", payload)
    end)
end)
```

**Layer 3: LiveView** - Reactive UI framework (Phoenix LiveView-inspired)
```quest
use "std/web/liveview" as lv
let CounterView = lv.component(fun ()
    # Server-rendered reactive UI with zero JavaScript required
end)
lv.mount("/counter", CounterView)
```

See [Real-Time Web Guide](docs/docs/realtime.md) for details.
```

## Implementation Timeline

### Phase 1: WebSocket Foundation (2-3 weeks)

- **Week 1**: Core WebSocket infrastructure in Rust
  - WebSocketManager implementation
  - Connection registry and lifecycle
  - Message routing
  - Rust-Quest bridge for handlers

- **Week 2**: Quest WebSocket API (`std/web/ws`)
  - Socket object with methods (send, close, etc.)
  - Event handlers (on_open, on_message, etc.)
  - Broadcasting utilities
  - Unit tests

- **Week 3**: Integration testing and examples
  - Echo server example
  - Chat server example
  - Documentation (websockets.md)

### Phase 2: Channels API (2 weeks)

- **Week 4**: Channels infrastructure
  - Topic-based routing
  - Join/leave semantics
  - Custom event handlers

- **Week 5**: Presence and pub/sub
  - Presence tracking implementation
  - Broadcast utilities
  - Examples and tests

### Phase 3: LiveView Framework (3-4 weeks)

- **Week 6**: LiveView core
  - LiveViewSocket implementation
  - Component lifecycle (mount, render, terminate)
  - State management and assigns

- **Week 7**: HTML diffing and patching
  - Morphdom integration
  - Patch generation
  - Efficient re-rendering

- **Week 8**: Event handling
  - phx-click, phx-submit, phx-change
  - Debouncing and throttling
  - Form handling

- **Week 9**: Advanced features
  - Component composition (live_component)
  - Pub/sub integration
  - Scheduled updates
  - Client JavaScript library

### Phase 4: Polish and Documentation (1-2 weeks)

- **Week 10**: Examples and testing
  - Dashboard example
  - Chat example
  - Collaborative editor example
  - Comprehensive test suite

- **Week 11**: Documentation and guides
  - API reference docs
  - Tutorial guides
  - Best practices
  - Migration examples

## Success Criteria

### Layer 1: WebSocket API
- ✅ Can establish WebSocket connections
- ✅ Can send/receive text and binary messages
- ✅ Can broadcast to multiple clients
- ✅ Connection lifecycle events work
- ✅ Metadata storage per connection

### Layer 2: Channels
- ✅ Can join/leave topics
- ✅ Custom events work correctly
- ✅ Presence tracking works
- ✅ Broadcasting to topic subscribers

### Layer 3: LiveView
- ✅ Server-side rendering works
- ✅ WebSocket upgrade succeeds
- ✅ Events trigger server handlers
- ✅ State updates cause re-renders
- ✅ Minimal HTML diffs sent to client
- ✅ DOM patches applied correctly
- ✅ Forms and validation work
- ✅ Component composition works
- ✅ Pub/sub integration works

### Overall
- ✅ All tests pass
- ✅ Documentation complete
- ✅ Example applications work
- ✅ Performance is acceptable
- ✅ No breaking changes to existing code

## Future Enhancements (Beyond This QEP)

### File Uploads in LiveView

```quest
# Chunked file upload with progress
socket.allow_upload("photo",
    accept: [".jpg", ".png"],
    max_size: 10 * 1024 * 1024,
    auto_upload: true
)

fun handle_event(event, payload, socket)
    if event == "upload"
        let uploaded_files = socket.consume_upload("photo", fun (meta, entry)
            let path = "/uploads/" .. uuid.v4().str()
            io.write(path, entry["data"])
            path
        end)

        socket.assign("photos", socket.get("photos") .. uploaded_files)
    end
end
```

### LiveView Streams (Infinite Scroll)

```quest
# Efficiently render large lists with virtual scrolling
fun mount(params, session, socket)
    socket.stream("messages", load_initial_messages(), limit: 50)
end

fun handle_info(msg, socket)
    if msg["event"] == "new_message"
        socket.stream_insert("messages", msg["payload"], at: 0)
    end
end
```

### Multi-Node Broadcasting

```quest
# Broadcast across multiple Quest servers using Redis
use "std/web/pubsub/redis" as redis_pubsub

pubsub.configure(adapter: redis_pubsub, url: "redis://localhost")

# Now broadcasts work across all connected servers
pubsub.broadcast("room:lobby", "message", payload)
```

## References

- [Phoenix LiveView Documentation](https://hexdocs.pm/phoenix_live_view/)
- [WebSocket RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455)
- [morphdom - DOM diffing library](https://github.com/patrick-steele-idem/morphdom)
- [QEP-051: Web Server Configuration](qep-051-web-server-configuration.md)
- [QEP-028: Serve Command](qep-028-serve-command.md)
- [Phoenix Channels Guide](https://hexdocs.pm/phoenix/channels.html)
- [LiveView JavaScript Client](https://github.com/phoenixframework/phoenix_live_view/blob/main/assets/js/phoenix_live_view.js)

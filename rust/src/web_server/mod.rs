use axum::{
    Router,
    routing::{get, post, put, delete},
    extract::{State, Json, Path},
    response::IntoResponse,
    http::{StatusCode, HeaderMap},
    middleware::{self, Next},
};
use tower_http::cors::{CorsLayer, AllowOrigin};
use std::sync::Arc;
use std::net::SocketAddr;
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

use crate::storage::{Database, Account, AppSettings};

#[derive(Clone)]
pub struct AppState {
    pub db: Arc<Database>,
    pub is_running: Arc<RwLock<bool>>,
    pub access_token: Arc<RwLock<String>>,
}

#[derive(Serialize, Deserialize)]
pub struct ApiResponse<T: Serialize> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
}

impl<T: Serialize> ApiResponse<T> {
    pub fn ok(data: T) -> Self {
        Self { success: true, data: Some(data), error: None }
    }
    pub fn err(msg: &str) -> Self {
        Self { success: false, data: None, error: Some(msg.to_string()) }
    }
}

/// Generate a random access token for web server authentication.
fn generate_token() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    format!("zwa_{:x}", timestamp)
}

/// Middleware to verify Bearer token authentication on API endpoints.
async fn auth_middleware(
    State(state): State<AppState>,
    headers: HeaderMap,
    request: axum::extract::Request,
    next: Next,
) -> impl IntoResponse {
    let path = request.uri().path();

    // Skip auth for root/index page
    if path == "/" || path == "" || path == "/index.html" {
        return next.run(request).await;
    }

    let token = state.access_token.read().await;

    // Verify Authorization header
    let authorized = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .map(|auth| auth == format!("Bearer {}", *token))
        .unwrap_or(false);

    if !authorized {
        return (StatusCode::UNAUTHORIZED, Json(ApiResponse::<String>::err("Unauthorized"))).into_response();
    }

    next.run(request).await
}

pub async fn start_web_server(db: Arc<Database>, port: u16) -> anyhow::Result<()> {
    let access_token = generate_token();
    tracing::info!("Web server access token: {}", access_token);

    let state = AppState {
        db,
        is_running: Arc::new(RwLock::new(true)),
        access_token: Arc::new(RwLock::new(access_token)),
    };

    // CORS: allow only localhost origins
    let cors = CorsLayer::new()
        .allow_origin(AllowOrigin::exact(format!("http://127.0.0.1:{}", port).parse().unwrap()))
        .allow_methods([
            axum::http::Method::GET,
            axum::http::Method::POST,
            axum::http::Method::PUT,
            axum::http::Method::DELETE,
            axum::http::Method::OPTIONS,
        ])
        .allow_headers([
            axum::http::header::CONTENT_TYPE,
            axum::http::header::AUTHORIZATION,
        ]);

    let app = Router::new()
        .route("/api/accounts", get(list_accounts).post(create_account))
        .route("/api/accounts/:id", get(get_account).put(update_account).delete(delete_account))
        .route("/api/settings", get(get_settings).put(update_settings))
        .route("/api/status", get(get_status))
        .route("/api/export", get(export_data))
        .route("/api/import", post(import_data))
        .layer(middleware::from_fn_with_state(state.clone(), auth_middleware))
        .layer(cors)
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    tracing::info!("Web server starting on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn list_accounts(State(state): State<AppState>) -> impl IntoResponse {
    match state.db.get_accounts() {
        Ok(accounts) => Json(ApiResponse::ok(accounts)),
        Err(e) => Json(ApiResponse::<Vec<Account>>::err(&e.to_string())),
    }
}

async fn get_account(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.db.get_account(&id) {
        Ok(Some(account)) => Json(ApiResponse::ok(account)),
        Ok(None) => Json(ApiResponse::<Account>::err("账号不存在")),
        Err(e) => Json(ApiResponse::<Account>::err(&e.to_string())),
    }
}

async fn create_account(
    State(state): State<AppState>,
    Json(account): Json<Account>,
) -> impl IntoResponse {
    match state.db.insert_account(&account) {
        Ok(_) => (StatusCode::CREATED, Json(ApiResponse::ok(account))),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, Json(ApiResponse::<Account>::err(&e.to_string()))),
    }
}

async fn update_account(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(mut account): Json<Account>,
) -> impl IntoResponse {
    account.id = id;
    match state.db.update_account(&account) {
        Ok(_) => Json(ApiResponse::ok(account)),
        Err(e) => Json(ApiResponse::<Account>::err(&e.to_string())),
    }
}

async fn delete_account(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.db.delete_account(&id) {
        Ok(_) => Json(ApiResponse::ok("删除成功")),
        Err(e) => Json(ApiResponse::<String>::err(&e.to_string())),
    }
}

async fn get_settings(State(state): State<AppState>) -> impl IntoResponse {
    match state.db.load_settings() {
        Ok(settings) => Json(ApiResponse::ok(settings)),
        Err(e) => Json(ApiResponse::<AppSettings>::err(&e.to_string())),
    }
}

async fn update_settings(
    State(state): State<AppState>,
    Json(settings): Json<AppSettings>,
) -> impl IntoResponse {
    match state.db.save_settings(&settings) {
        Ok(_) => Json(ApiResponse::ok(settings)),
        Err(e) => Json(ApiResponse::<AppSettings>::err(&e.to_string())),
    }
}

async fn get_status(State(state): State<AppState>) -> impl IntoResponse {
    let accounts = state.db.get_accounts().unwrap_or_default();
    let total = accounts.len();
    let completed = accounts.iter().filter(|a| a.status == crate::storage::AccountStatus::Completed).count();
    let error = accounts.iter().filter(|a| a.status == crate::storage::AccountStatus::Error).count();

    Json(ApiResponse::ok(serde_json::json!({
        "total_accounts": total,
        "completed": completed,
        "error": error,
        "incomplete": total - completed - error,
        "is_running": *state.is_running.read().await,
    })))
}

async fn export_data(State(state): State<AppState>) -> impl IntoResponse {
    match state.db.export_data() {
        Ok(data) => Json(ApiResponse::ok(data)),
        Err(e) => Json(ApiResponse::<serde_json::Value>::err(&e.to_string())),
    }
}

async fn import_data(
    State(state): State<AppState>,
    Json(data): Json<serde_json::Value>,
) -> impl IntoResponse {
    match state.db.import_data(&data) {
        Ok(_) => Json(ApiResponse::ok("导入成功")),
        Err(e) => Json(ApiResponse::<String>::err(&e.to_string())),
    }
}

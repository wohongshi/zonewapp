use std::sync::Arc;
use std::path::PathBuf;
use tokio::sync::Mutex;

use crate::ai::{AiEngine, AiMode, AiResponse, ApiConfig, WebConfig};
use crate::automation::{AutomationEngine, AutomationConfig, FillTask, TaskProgress};
use crate::storage::{Database, Account, AppSettings, ProjectItem};
use crate::web_server;

pub struct AppState {
    pub db: Arc<Database>,
    pub ai_engine: Arc<Mutex<AiEngine>>,
    pub automation_engine: Arc<Mutex<AutomationEngine>>,
}

static mut APP_STATE: Option<AppState> = None;

pub fn init_app(db_path: String) -> bool {
    let path = PathBuf::from(&db_path);
    match Database::new(&path) {
        Ok(db) => {
            let db = Arc::new(db);
            let ai_engine = Arc::new(Mutex::new(AiEngine::new()));
            let automation_engine = Arc::new(Mutex::new(AutomationEngine::new()));

            unsafe {
                APP_STATE = Some(AppState {
                    db,
                    ai_engine,
                    automation_engine,
                });
            }
            true
        }
        Err(e) => {
            tracing::error!("Failed to initialize database: {}", e);
            false
        }
    }
}

fn get_state() -> &'static AppState {
    unsafe { APP_STATE.as_ref().expect("App not initialized") }
}

// AI Functions
pub async fn set_ai_mode(mode_json: String) -> bool {
    let mode: AiMode = match serde_json::from_str(&mode_json) {
        Ok(m) => m,
        Err(_) => return false,
    };
    let mut engine = get_state().ai_engine.lock().await;
    engine.set_mode(mode);
    true
}

pub async fn test_ai() -> String {
    let engine = get_state().ai_engine.lock().await;
    match engine.test_connection().await {
        Ok(resp) => serde_json::to_string(&resp).unwrap_or_default(),
        Err(e) => serde_json::to_string(&AiResponse {
            content: String::new(),
            success: false,
            error: Some(e.to_string()),
        }).unwrap_or_default(),
    }
}

pub async fn send_ai_message(prompt: String) -> String {
    let engine = get_state().ai_engine.lock().await;
    match engine.send_message(&prompt).await {
        Ok(resp) => serde_json::to_string(&resp).unwrap_or_default(),
        Err(e) => serde_json::to_string(&AiResponse {
            content: String::new(),
            success: false,
            error: Some(e.to_string()),
        }).unwrap_or_default(),
    }
}

// Account Functions
pub fn get_accounts() -> String {
    let state = get_state();
    match state.db.get_accounts() {
        Ok(accounts) => serde_json::to_string(&accounts).unwrap_or_default(),
        Err(_) => "[]".to_string(),
    }
}

pub fn add_account(account_json: String) -> bool {
    let state = get_state();
    let account: Account = match serde_json::from_str(&account_json) {
        Ok(a) => a,
        Err(_) => return false,
    };
    state.db.insert_account(&account).is_ok()
}

pub fn update_account(account_json: String) -> bool {
    let state = get_state();
    let account: Account = match serde_json::from_str(&account_json) {
        Ok(a) => a,
        Err(_) => return false,
    };
    state.db.update_account(&account).is_ok()
}

pub fn delete_account(id: String) -> bool {
    let state = get_state();
    state.db.delete_account(&id).is_ok()
}

pub fn get_next_incomplete_account() -> String {
    let state = get_state();
    match state.db.get_next_incomplete_account() {
        Ok(Some(account)) => serde_json::to_string(&account).unwrap_or_default(),
        _ => "{}".to_string(),
    }
}

// Settings Functions
pub fn get_settings() -> String {
    let state = get_state();
    match state.db.load_settings() {
        Ok(settings) => serde_json::to_string(&settings).unwrap_or_default(),
        Err(_) => serde_json::to_string(&AppSettings::default()).unwrap_or_default(),
    }
}

pub fn save_settings(settings_json: String) -> bool {
    let state = get_state();
    let settings: AppSettings = match serde_json::from_str(&settings_json) {
        Ok(s) => s,
        Err(_) => return false,
    };
    state.db.save_settings(&settings).is_ok()
}

// Automation Functions
pub async fn create_automation_tasks(config_json: String) -> String {
    let config: AutomationConfig = match serde_json::from_str(&config_json) {
        Ok(c) => c,
        Err(_) => return "[]".to_string(),
    };
    let mut engine = get_state().automation_engine.lock().await;
    let tasks = engine.create_tasks(&config);
    serde_json::to_string(&tasks).unwrap_or_default()
}

pub async fn get_automation_progress() -> String {
    let engine = get_state().automation_engine.lock().await;
    let progress = engine.get_progress();
    serde_json::to_string(&progress).unwrap_or_default()
}

pub async fn update_task_status(task_id: String, status: String, error: Option<String>) -> bool {
    let status = match status.as_str() {
        "completed" => crate::automation::TaskStatus::Completed,
        "failed" => crate::automation::TaskStatus::Failed,
        "running" => crate::automation::TaskStatus::Running,
        _ => crate::automation::TaskStatus::Pending,
    };
    let mut engine = get_state().automation_engine.lock().await;
    engine.update_task_status(&task_id, status, error);
    true
}

// Project Items
pub fn save_project_items(account_id: String, items_json: String) -> bool {
    let state = get_state();
    let items: Vec<ProjectItem> = match serde_json::from_str(&items_json) {
        Ok(i) => i,
        Err(_) => return false,
    };
    state.db.save_project_items(&account_id, &items).is_ok()
}

pub fn get_project_items(account_id: String) -> String {
    let state = get_state();
    match state.db.get_project_items(&account_id) {
        Ok(items) => serde_json::to_string(&items).unwrap_or_default(),
        Err(_) => "[]".to_string(),
    }
}

// Backup & Restore
pub fn export_data() -> String {
    let state = get_state();
    match state.db.export_data() {
        Ok(data) => serde_json::to_string(&data).unwrap_or_default(),
        Err(_) => "{}".to_string(),
    }
}

pub fn import_data(data_json: String) -> bool {
    let state = get_state();
    let data: serde_json::Value = match serde_json::from_str(&data_json) {
        Ok(d) => d,
        Err(_) => return false,
    };
    state.db.import_data(&data).is_ok()
}

// Web Server
pub async fn start_web_server(port: u16) -> bool {
    let state = get_state();
    let db = state.db.clone();
    tokio::spawn(async move {
        if let Err(e) = web_server::start_web_server(db, port).await {
            tracing::error!("Web server error: {}", e);
        }
    });
    true
}

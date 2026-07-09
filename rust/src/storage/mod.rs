use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use anyhow::Result;
use std::path::PathBuf;
use std::sync::Mutex;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    pub id: String,
    pub username: String,
    pub password: String,
    pub subjects: Vec<String>,
    pub teacher_name: String,
    pub positions: Vec<PositionEntry>,
    pub rewards: Vec<RewardEntry>,
    pub status: AccountStatus,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PositionEntry {
    pub id: String,
    pub title: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RewardEntry {
    pub id: String,
    pub title: String,
    pub level: String,
    pub department: String,
    pub image_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum AccountStatus {
    Incomplete,
    Completed,
    Error,
}

impl AccountStatus {
    pub fn as_str(&self) -> &str {
        match self {
            AccountStatus::Incomplete => "未完成",
            AccountStatus::Completed => "已完成",
            AccountStatus::Error => "状态异常",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "已完成" => AccountStatus::Completed,
            "状态异常" => AccountStatus::Error,
            _ => AccountStatus::Incomplete,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectItem {
    pub id: String,
    pub name: String,
    pub status: ProjectStatus,
    pub ai_content: Option<String>,
    pub screenshot_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ProjectStatus {
    NotStarted,
    InProgress,
    Completed,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub theme_mode: String,
    pub ai_mode: Option<String>,
    pub ai_config: Option<serde_json::Value>,
    pub subject_contents: std::collections::HashMap<String, String>,
    pub notification_enabled: bool,
    pub web_service_enabled: bool,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            theme_mode: "system".to_string(),
            ai_mode: None,
            ai_config: None,
            subject_contents: std::collections::HashMap::new(),
            notification_enabled: true,
            web_service_enabled: false,
        }
    }
}

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn new(db_path: &PathBuf) -> Result<Self> {
        let conn = Connection::open(db_path)?;
        
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY,
                username TEXT NOT NULL,
                password TEXT NOT NULL,
                subjects TEXT NOT NULL,
                teacher_name TEXT NOT NULL,
                positions TEXT NOT NULL,
                rewards TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT '未完成',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS project_items (
                id TEXT PRIMARY KEY,
                account_id TEXT NOT NULL,
                name TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT '未开始',
                ai_content TEXT,
                screenshot_path TEXT,
                FOREIGN KEY(account_id) REFERENCES accounts(id)
            );
            CREATE TABLE IF NOT EXISTS task_logs (
                id TEXT PRIMARY KEY,
                account_id TEXT NOT NULL,
                task_type TEXT NOT NULL,
                status TEXT NOT NULL,
                message TEXT,
                created_at TEXT NOT NULL
            );"
        )?;

        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn insert_account(&self, account: &Account) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO accounts (id, username, password, subjects, teacher_name, positions, rewards, status, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![
                account.id,
                account.username,
                account.password,
                serde_json::to_string(&account.subjects)?,
                account.teacher_name,
                serde_json::to_string(&account.positions)?,
                serde_json::to_string(&account.rewards)?,
                account.status.as_str(),
                account.created_at,
                account.updated_at,
            ],
        )?;
        Ok(())
    }

    pub fn update_account(&self, account: &Account) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE accounts SET username=?2, password=?3, subjects=?4, teacher_name=?5, positions=?6, rewards=?7, status=?8, updated_at=?9 WHERE id=?1",
            params![
                account.id,
                account.username,
                account.password,
                serde_json::to_string(&account.subjects)?,
                account.teacher_name,
                serde_json::to_string(&account.positions)?,
                serde_json::to_string(&account.rewards)?,
                account.status.as_str(),
                account.updated_at,
            ],
        )?;
        Ok(())
    }

    pub fn delete_account(&self, id: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM accounts WHERE id=?1", params![id])?;
        conn.execute("DELETE FROM project_items WHERE account_id=?1", params![id])?;
        Ok(())
    }

    pub fn get_accounts(&self) -> Result<Vec<Account>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT id, username, password, subjects, teacher_name, positions, rewards, status, created_at, updated_at FROM accounts ORDER BY created_at")?;
        let accounts = stmt.query_map([], |row| {
            Ok(Account {
                id: row.get(0)?,
                username: row.get(1)?,
                password: row.get(2)?,
                subjects: serde_json::from_str(&row.get::<_, String>(3)?).unwrap_or_default(),
                teacher_name: row.get(4)?,
                positions: serde_json::from_str(&row.get::<_, String>(5)?).unwrap_or_default(),
                rewards: serde_json::from_str(&row.get::<_, String>(6)?).unwrap_or_default(),
                status: AccountStatus::from_str(&row.get::<_, String>(7)?),
                created_at: row.get(8)?,
                updated_at: row.get(9)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(accounts)
    }

    pub fn get_account(&self, id: &str) -> Result<Option<Account>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, username, password, subjects, teacher_name, positions, rewards, status, created_at, updated_at FROM accounts WHERE id=?1"
        )?;
        let mut accounts = stmt.query_map(params![id], |row| {
            Ok(Account {
                id: row.get(0)?,
                username: row.get(1)?,
                password: row.get(2)?,
                subjects: serde_json::from_str(&row.get::<_, String>(3)?).unwrap_or_default(),
                teacher_name: row.get(4)?,
                positions: serde_json::from_str(&row.get::<_, String>(5)?).unwrap_or_default(),
                rewards: serde_json::from_str(&row.get::<_, String>(6)?).unwrap_or_default(),
                status: AccountStatus::from_str(&row.get::<_, String>(7)?),
                created_at: row.get(8)?,
                updated_at: row.get(9)?,
            })
        })?;
        Ok(accounts.next().transpose()?)
    }

    pub fn get_next_incomplete_account(&self) -> Result<Option<Account>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, username, password, subjects, teacher_name, positions, rewards, status, created_at, updated_at FROM accounts WHERE status='未完成' ORDER BY created_at ASC LIMIT 1"
        )?;
        let mut accounts = stmt.query_map([], |row| {
            Ok(Account {
                id: row.get(0)?,
                username: row.get(1)?,
                password: row.get(2)?,
                subjects: serde_json::from_str(&row.get::<_, String>(3)?).unwrap_or_default(),
                teacher_name: row.get(4)?,
                positions: serde_json::from_str(&row.get::<_, String>(5)?).unwrap_or_default(),
                rewards: serde_json::from_str(&row.get::<_, String>(6)?).unwrap_or_default(),
                status: AccountStatus::from_str(&row.get::<_, String>(7)?),
                created_at: row.get(8)?,
                updated_at: row.get(9)?,
            })
        })?;
        Ok(accounts.next().transpose()?)
    }

    pub fn save_settings(&self, settings: &AppSettings) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let value = serde_json::to_string(settings)?;
        conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES ('app_settings', ?1)",
            params![value],
        )?;
        Ok(())
    }

    pub fn load_settings(&self) -> Result<AppSettings> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT value FROM settings WHERE key='app_settings'")?;
        let mut rows = stmt.query_map([], |row| {
            row.get::<_, String>(0)
        })?;
        
        if let Some(row) = rows.next() {
            let value = row?;
            Ok(serde_json::from_str(&value)?)
        } else {
            Ok(AppSettings::default())
        }
    }

    pub fn save_project_items(&self, account_id: &str, items: &[ProjectItem]) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        for item in items {
            conn.execute(
                "INSERT OR REPLACE INTO project_items (id, account_id, name, status, ai_content, screenshot_path)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                params![
                    item.id,
                    account_id,
                    item.name,
                    match item.status {
                        ProjectStatus::NotStarted => "未开始",
                        ProjectStatus::InProgress => "进行中",
                        ProjectStatus::Completed => "已完成",
                    },
                    item.ai_content,
                    item.screenshot_path,
                ],
            )?;
        }
        Ok(())
    }

    pub fn get_project_items(&self, account_id: &str) -> Result<Vec<ProjectItem>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, name, status, ai_content, screenshot_path FROM project_items WHERE account_id=?1"
        )?;
        let items = stmt.query_map(params![account_id], |row| {
            Ok(ProjectItem {
                id: row.get(0)?,
                name: row.get(1)?,
                status: match row.get::<_, String>(2)?.as_str() {
                    "已完成" => ProjectStatus::Completed,
                    "进行中" => ProjectStatus::InProgress,
                    _ => ProjectStatus::NotStarted,
                },
                ai_content: row.get(3)?,
                screenshot_path: row.get(4)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(items)
    }

    pub fn export_data(&self) -> Result<serde_json::Value> {
        let accounts = self.get_accounts()?;
        let settings = self.load_settings()?;
        
        Ok(serde_json::json!({
            "accounts": accounts,
            "settings": settings,
            "exported_at": chrono::Utc::now().to_rfc3339(),
        }))
    }

    pub fn import_data(&self, data: &serde_json::Value) -> Result<()> {
        if let Some(accounts) = data["accounts"].as_array() {
            for account_json in accounts {
                if let Ok(account) = serde_json::from_value::<Account>(account_json.clone()) {
                    self.insert_account(&account)?;
                }
            }
        }
        if let Ok(settings) = serde_json::from_value::<AppSettings>(data["settings"].clone()) {
            self.save_settings(&settings)?;
        }
        Ok(())
    }
}

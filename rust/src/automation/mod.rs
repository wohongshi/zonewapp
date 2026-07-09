use serde::{Deserialize, Serialize};
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FillTask {
    pub id: String,
    pub account_id: String,
    pub task_type: String,
    pub status: TaskStatus,
    pub url: String,
    pub ai_prompt: String,
    pub fill_data: Option<String>,
    pub screenshot_path: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TaskStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Skipped,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AutomationConfig {
    pub login_url: String,
    pub index_url: String,
    pub account: String,
    pub password: String,
    pub subjects: Vec<String>,
    pub teacher_name: String,
    pub positions: Vec<Position>,
    pub rewards: Vec<Reward>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Position {
    pub title: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Reward {
    pub title: String,
    pub level: String,
    pub department: String,
    pub image_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskProgress {
    pub total: u32,
    pub completed: u32,
    pub running: u32,
    pub failed: u32,
    pub current_task: Option<String>,
    pub percentage: f32,
}

pub struct AutomationEngine {
    tasks: Vec<FillTask>,
    is_running: bool,
}

impl AutomationEngine {
    pub fn new() -> Self {
        Self {
            tasks: Vec::new(),
            is_running: false,
        }
    }

    pub fn create_tasks(&mut self, config: &AutomationConfig) -> Vec<FillTask> {
        let base_url = "https://szpj.sdei.edu.cn/zhszpj/web";
        let mut tasks = Vec::new();

        // Task 1: 材料排序
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "material_sort".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/index/xsCltbIndex.htm", base_url.replace("/web", "")),
            ai_prompt: String::new(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        // Task 2: 任职情况
        if !config.positions.is_empty() {
            tasks.push(FillTask {
                id: uuid::Uuid::new_v4().to_string(),
                account_id: config.account.clone(),
                task_type: "position".to_string(),
                status: TaskStatus::Pending,
                url: format!("{}/jbqk/xsRzqk.htm", base_url),
                ai_prompt: "帮我生成担任职务描述，文字最少25个，最多200个".to_string(),
                fill_data: Some(serde_json::to_string(&config.positions).unwrap_or_default()),
                screenshot_path: None,
                error: None,
            });
        }

        // Task 3: 奖惩情况
        if !config.rewards.is_empty() {
            tasks.push(FillTask {
                id: uuid::Uuid::new_v4().to_string(),
                account_id: config.account.clone(),
                task_type: "reward".to_string(),
                status: TaskStatus::Pending,
                url: format!("{}/jbqk/xsJcxx.htm", base_url),
                ai_prompt: "帮我生成奖惩情况描述".to_string(),
                fill_data: Some(serde_json::to_string(&config.rewards).unwrap_or_default()),
                screenshot_path: None,
                error: None,
            });
        }

        // Task 4: 日常体育锻炼
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "physical_education".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/sxjk/xsTydl.htm", base_url),
            ai_prompt: String::new(),
            fill_data: Some(r#"{"attendance_rate":"100","exercise_rate":"100"}"#.to_string()),
            screenshot_path: None,
            error: None,
        });

        // Task 5: 心理素质展示
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "psychology".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/sxjk/xsSxjk.htm", base_url),
            ai_prompt: "本学期心理素质展示\n请描述你在高中阶段克服遇到的困难或应对挫折的典型事件，也可描述在人际交往、情绪调节等方面的事件，并简要说明你是如何应对的。（25~200字）".to_string(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        // Task 6: 陈述报告
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "statement".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/csbg/xsCsbg.htm", base_url),
            ai_prompt: "本学期陈述报告\n用自己的成长事实，来说明自己的个性、兴趣、特长、发展潜能、生涯规划（愿望），语言简明扼要。（25~200字）".to_string(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        // Task 7: 党团活动
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "party_activity".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/sxpd/xsDxsl.htm", base_url),
            ai_prompt: "活动主题：*\n活动类型：党团活动\n开始时间：*\n结束时间：*\n活动地点：*\n典型事例描述：描述参加的典型事例活动中你承担的任务，完成情况，获得的荣誉等。（25~200字）".to_string(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        // Task 8: 志愿服务
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "volunteer".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/sxpd/xsDxsl.htm", base_url),
            ai_prompt: "活动主题：*\n活动类型：志愿服务\n开始时间：*\n结束时间：*\n活动地点：*\n典型事例描述：描述参加的典型事例活动中你承担的任务，完成情况，获得的荣誉等。（25~200字）".to_string(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        // Task 9: 艺术素养
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "art".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/yssy/xsYssy.htm", base_url),
            ai_prompt: "年级：高中二年级 学年：2025-2026\n学期：下学期 项目：音乐\n高中阶段参加的社团及活动的情况：\n文字最少25个，最多200个\n高中阶段取得的校级（含校级）以上主要成绩（作品、成果、荣誉等）：\n文字最少25个，最多200个".to_string(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        // Task 10: 劳动与实践
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "labor".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/shsj/xsShsj.htm", base_url),
            ai_prompt: "学年：2025-2026 学期：下学期\n类别：职业体验活动\n实践形式：\n内容：从事劳动与实践的工作内容描述。（25~200字）\n承担任务：在劳动与实践过程中，主要承担的实践任务。（25~200字）\n实践成果：实践任务完成后获得的奖励、证书，形成的作品等。（25~200字）".to_string(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        // Task 11: 课题研究
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "research".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/xysp/xsYjxxxjcxcg.htm", base_url),
            ai_prompt: "学年：2025-2026 学期：下学期\n类型：课题研究\n课题名称：*\n理论学习情况：\n学时总数：*\n指导老师：*\n研究内容：*\n成果概述：".to_string(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        // Task 12: 项目设计
        tasks.push(FillTask {
            id: uuid::Uuid::new_v4().to_string(),
            account_id: config.account.clone(),
            task_type: "project_design".to_string(),
            status: TaskStatus::Pending,
            url: format!("{}/xysp/xsYjxxxjcxcg.htm", base_url),
            ai_prompt: "学年：2025-2026 学期：下学期\n类型：项目（活动）设计\n课题名称：*\n理论学习情况：\n学时总数：*\n指导老师：*\n研究内容：*\n成果概述：".to_string(),
            fill_data: None,
            screenshot_path: None,
            error: None,
        });

        self.tasks = tasks.clone();
        tasks
    }

    pub fn get_progress(&self) -> TaskProgress {
        let total = self.tasks.len() as u32;
        let completed = self.tasks.iter().filter(|t| t.status == TaskStatus::Completed).count() as u32;
        let running = self.tasks.iter().filter(|t| t.status == TaskStatus::Running).count() as u32;
        let failed = self.tasks.iter().filter(|t| t.status == TaskStatus::Failed).count() as u32;
        let current = self.tasks.iter().find(|t| t.status == TaskStatus::Running).map(|t| t.task_type.clone());

        TaskProgress {
            total,
            completed,
            running,
            failed,
            current_task: current,
            percentage: if total > 0 { (completed as f32 / total as f32) * 100.0 } else { 0.0 },
        }
    }

    pub fn get_tasks(&self) -> &Vec<FillTask> {
        &self.tasks
    }

    pub fn update_task_status(&mut self, task_id: &str, status: TaskStatus, error: Option<String>) {
        if let Some(task) = self.tasks.iter_mut().find(|t| t.id == task_id) {
            task.status = status;
            task.error = error;
        }
    }

    pub fn set_running(&mut self, running: bool) {
        self.is_running = running;
    }

    pub fn is_running(&self) -> bool {
        self.is_running
    }
}

use serde::{Deserialize, Serialize};
use reqwest::Client;
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AiMode {
    Api(ApiConfig),
    Web(WebConfig),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiConfig {
    pub name: String,
    pub api_url: String,
    pub api_key: String,
    pub model: String,
    pub temperature: f32,
    pub max_tokens: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebConfig {
    pub platform: String,
    pub login_url: String,
    pub cookies: String,
    pub session_data: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiResponse {
    pub content: String,
    pub success: bool,
    pub error: Option<String>,
}

pub struct AiEngine {
    client: Client,
    mode: Option<AiMode>,
}

impl AiEngine {
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .timeout(std::time::Duration::from_secs(120))
                .build()
                .unwrap(),
            mode: None,
        }
    }

    pub fn set_mode(&mut self, mode: AiMode) {
        self.mode = Some(mode);
    }

    pub async fn test_connection(&self) -> Result<AiResponse> {
        self.send_message("你好").await
    }

    pub async fn send_message(&self, prompt: &str) -> Result<AiResponse> {
        match &self.mode {
            Some(AiMode::Api(config)) => self.send_api_request(config, prompt).await,
            Some(AiMode::Web(config)) => self.send_web_request(config, prompt).await,
            None => Ok(AiResponse {
                content: String::new(),
                success: false,
                error: Some("请配置相应AI".to_string()),
            }),
        }
    }

    async fn send_api_request(&self, config: &ApiConfig, prompt: &str) -> Result<AiResponse> {
        let body = serde_json::json!({
            "model": config.model,
            "messages": [
                {
                    "role": "system",
                    "content": "你是一个帮助高中生填写山东省综合评价平台的AI助手。请根据要求生成简洁、真实、符合学生身份的内容。字数严格控制在25-200字之间。不要包含标题、序号或多余的格式符号。"
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": config.temperature,
            "max_tokens": config.max_tokens,
            "stream": false
        });

        let response = self.client
            .post(&config.api_url)
            .header("Authorization", format!("Bearer {}", config.api_key))
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await?;
            let content = json["choices"][0]["message"]["content"]
                .as_str()
                .unwrap_or("")
                .to_string();
            Ok(AiResponse {
                content,
                success: true,
                error: None,
            })
        } else {
            let error_text = response.text().await.unwrap_or_default();
            Ok(AiResponse {
                content: String::new(),
                success: false,
                error: Some(format!("API请求失败: {}", error_text)),
            })
        }
    }

    async fn send_web_request(&self, config: &WebConfig, prompt: &str) -> Result<AiResponse> {
        // Web mode: replay captured request from browser automation.
        // The actual web automation is handled by Flutter's WebView layer;
        // this Rust-side fallback uses the DeepSeek API directly.
        let api_url = match config.platform.as_str() {
            "deepseek" => "https://api.deepseek.com/v1/chat/completions",
            _ => return Ok(AiResponse {
                content: String::new(),
                success: false,
                error: Some("不支持的AI平台".to_string()),
            }),
        };

        let body = serde_json::json!({
            "model": "deepseek-chat",
            "messages": [
                {
                    "role": "system",
                    "content": "你是一个帮助高中生填写山东省综合评价平台的AI助手。请根据要求生成简洁、真实、符合学生身份的内容。字数严格控制在25-200字之间。不要包含标题、序号或多余的格式符号。"
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.7,
            "max_tokens": 500,
            "stream": false
        });

        let mut request = self.client
            .post(api_url)
            .header("Content-Type", "application/json");

        if !config.session_data.is_empty() {
            request = request.header("Authorization", format!("Bearer {}", config.session_data));
        }

        let response = request.json(&body).send().await?;

        if response.status().is_success() {
            let json: serde_json::Value = response.json().await?;
            let content = json["choices"][0]["message"]["content"]
                .as_str()
                .unwrap_or("")
                .to_string();
            Ok(AiResponse {
                content,
                success: true,
                error: None,
            })
        } else {
            Ok(AiResponse {
                content: String::new(),
                success: false,
                error: Some("网页模式AI请求失败".to_string()),
            })
        }
    }

    pub async fn generate_content(&self, task_type: &str, params: &str) -> Result<AiResponse> {
        let prompt = match task_type {
            "position" => format!(
                "帮我生成担任职务：{}\n职务描述：\n文字最少25个，最多200个",
                params
            ),
            "reward" => format!(
                "帮我生成奖惩情况：{}\n描述文字最少25个，最多200个",
                params
            ),
            "psychology" => "本学期心理素质展示\n请描述你在高中阶段克服遇到的困难或应对挫折的典型事件，也可描述在人际交往、情绪调节等方面的事件，并简要说明你是如何应对的。（25~200字）".to_string(),
            "statement" => "本学期陈述报告\n用自己的成长事实，来说明自己的个性、兴趣、特长、发展潜能、生涯规划（愿望），语言简明扼要。（25~200字）".to_string(),
            "party_activity" => format!(
                "活动主题：*\n活动类型：党团活动\n开始时间：*\n结束时间：*\n活动地点：*\n典型事例描述：描述参加的典型事例活动中你承担的任务，完成情况，获得的荣誉等。（25~200字）\n{}",
                params
            ),
            "volunteer" => format!(
                "活动主题：*\n活动类型：志愿服务\n开始时间：*\n结束时间：*\n活动地点：*\n典型事例描述：描述参加的典型事例活动中你承担的任务，完成情况，获得的荣誉等。（25~200字）\n{}",
                params
            ),
            "art" => format!(
                "年级：高中二年级 学年：2025-2026\n学期：下学期 项目：音乐\n高中阶段参加的社团及活动的情况：\n文字最少25个，最多200个\n高中阶段取得的校级（含校级）以上主要成绩（作品、成果、荣誉等）：\n文字最少25个，最多200个\n{}",
                params
            ),
            "labor" => format!(
                "学年：2025-2026 学期：下学期\n类别：职业体验活动\n实践形式：\n内容：从事劳动与实践的工作内容描述。（25~200字）\n承担任务：在劳动与实践过程中，主要承担的实践任务。（25~200字）\n实践成果：实践任务完成后获得的奖励、证书，形成的作品等。（25~200字）\n{}",
                params
            ),
            "research" => format!(
                "学年：2025-2026 学期：下学期\n类型：课题研究\n课题名称：{}\n理论学习情况：\n学时总数：*\n指导老师：*\n研究内容：*\n成果概述：",
                params
            ),
            "project_design" => format!(
                "学年：2025-2026 学期：下学期\n类型：项目（活动）设计\n课题名称：{}\n理论学习情况：\n学时总数：*\n指导老师：*\n研究内容：*\n成果概述：",
                params
            ),
            _ => params.to_string(),
        };

        self.send_message(&prompt).await
    }
}

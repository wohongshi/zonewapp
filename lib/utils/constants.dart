class AppConstants {
  // URLs
  static const String loginUrl = 'https://szpj.sdei.edu.cn/zhszpj/uc/login.htm';
  static const String indexUrl = 'https://szpj.sdei.edu.cn/zhszpj/web/index/xsCltbIndex.htm';
  static const String baseUrl = 'https://szpj.sdei.edu.cn/zhszpj/web';
  
  // Task URLs
  static const String materialSortUrl = '$indexUrl';
  static const String positionUrl = '$baseUrl/jbqk/xsRzqk.htm';
  static const String rewardUrl = '$baseUrl/jbqk/xsJcxx.htm';
  static const String physicalEducationUrl = '$baseUrl/sxjk/xsTydl.htm';
  static const String psychologyUrl = '$baseUrl/sxjk/xsSxjk.htm';
  static const String statementUrl = '$baseUrl/csbg/xsCsbg.htm';
  static const String partyActivityUrl = '$baseUrl/sxpd/xsDxsl.htm';
  static const String volunteerUrl = '$baseUrl/sxpd/xsDxsl.htm';
  static const String artUrl = '$baseUrl/yssy/xsYssy.htm';
  static const String laborUrl = '$baseUrl/shsj/xsShsj.htm';
  static const String researchUrl = '$baseUrl/xysp/xsYjxxxjcxcg.htm';
  static const String projectDesignUrl = '$baseUrl/xysp/xsYjxxxjcxcg.htm';
  
  // Web Server
  static const int webServerPort = 35535;
  
  // Task Names
  static const List<String> taskNames = [
    '材料排序',
    '任职情况',
    '奖惩情况',
    '日常体育锻炼',
    '心理素质展示',
    '陈述报告',
    '党团活动',
    '志愿服务',
    '艺术素养',
    '劳动与实践',
    '课题研究',
    '项目设计',
  ];
  
  // Subjects
  static const List<String> availableSubjects = [
    '物理', '化学', '生物', '政治', '历史', '地理',
  ];
  
  // Reward Levels
  static const List<String> rewardLevels = [
    '校级_学校',
    '县级_行政部门',
    '市级_行政部门',
    '省级_行政部门',
    '国家级_行政部门',
  ];
  
  // Dates
  static const String defaultStartDate = '2026-02-01';
  static const String defaultEndDate = '2026-07-09';
  static const String laborEndDate = '2026-09-01';
  static const int defaultStudyHours = 54;
}

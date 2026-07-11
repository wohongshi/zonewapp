import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../services/storage_service.dart';
import '../models/account.dart';

class WebServerService {
  static final WebServerService instance = WebServerService._();
  WebServerService._();

  HttpServer? _server;
  bool _isRunning = false;
  String? _accessToken;
  bool _lanAccess = false;
  int _port = 35535;

  bool get isRunning => _isRunning;
  String? get accessToken => _accessToken;
  int get port => _port;
  bool get lanAccess => _lanAccess;

  /// Generate a new cryptographically random access token.
  /// Returns the token that clients must provide as Bearer auth.
  String generateToken() {
    _accessToken = const Uuid().v4();
    return _accessToken!;
  }

  /// Clear the access token (disables auth until a new one is generated).
  void clearToken() {
    _accessToken = null;
  }

  Future<void> start({bool lanAccess = false, int port = 35535}) async {
    if (_isRunning) return;

    _lanAccess = lanAccess;
    _port = port;

    // Generate a token if one doesn't exist
    _accessToken ??= generateToken();

    if (_lanAccess) {
      // Bind to all interfaces for LAN access
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv6, port, v6Only: false);
      } catch (e) {
        debugPrint('IPv6 bind failed, falling back to IPv4: $e');
        _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      }
      debugPrint('Web server running on http://0.0.0.0:$port (LAN access enabled)');
    } else {
      // Localhost only
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      debugPrint('Web server running on http://127.0.0.1:$port (localhost only)');
    }
    _isRunning = true;

    _server!.listen((HttpRequest request) async {
      final origin = request.headers.value('Origin');

      // CORS headers - restrict based on LAN access setting
      if (_lanAccess) {
        // LAN mode: allow same-origin and localhost origins
        if (origin != null && _isAllowedOrigin(origin)) {
          request.response.headers.set('Access-Control-Allow-Origin', origin);
        }
      } else {
        // Localhost only: allow localhost origins
        if (origin != null && _isLocalhostOrigin(origin)) {
          request.response.headers.set('Access-Control-Allow-Origin', origin);
        }
      }
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      // Skip auth for the index page and OPTIONS
      final path = request.uri.path;
      final isPublicPage = path == '/' || path == '' || path == '/index.html';

      if (!isPublicPage) {
        // Verify Bearer token for API endpoints
        if (!_verifyAuth(request)) {
          request.response.statusCode = 401;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'Unauthorized'}));
          await request.response.close();
          return;
        }
      }

      try {
        await _handleRequest(request);
      } catch (e) {
        request.response.statusCode = 500;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      }
    });
  }

  bool _isLocalhostOrigin(String origin) {
    return origin.startsWith('http://127.0.0.1') ||
        origin.startsWith('http://localhost') ||
        origin.startsWith('https://127.0.0.1') ||
        origin.startsWith('https://localhost');
  }

  bool _isAllowedOrigin(String origin) {
    // In LAN mode, allow localhost + any origin on the same network
    if (_isLocalhostOrigin(origin)) return true;
    // Allow any HTTP origin (LAN access is explicitly enabled by user)
    return origin.startsWith('http://') || origin.startsWith('https://');
  }

  bool _verifyAuth(HttpRequest request) {
    final authHeader = request.headers.value('Authorization');
    if (authHeader == null || _accessToken == null) return false;
    return authHeader == 'Bearer $_accessToken';
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    switch (path) {
      case '':
      case '/':
      case '/index.html':
        await _serveIndex(request);
        break;
      case '/api/accounts':
        await _handleAccounts(request);
        break;
      case '/api/status':
        await _handleStatus(request);
        break;
      case '/api/settings':
        await _handleSettings(request);
        break;
      default:
        if (path.startsWith('/api/accounts/')) {
          final id = path.replaceFirst('/api/accounts/', '');
          await _handleAccountById(request, id);
        } else {
          request.response.statusCode = 404;
          request.response.write('Not found');
          await request.response.close();
        }
    }
  }

  Future<void> _serveIndex(HttpRequest request) async {
    // Token is NOT embedded in HTML; client must obtain it via a secure flow.
    // For now, the page fetches /api/status without auth (public page)
    // and shows a login prompt for API operations.
    final html = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZonewApp Web Control</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; }
        .header { background: #1976d2; color: white; padding: 16px; display: flex; align-items: center; gap: 16px; }
        .header h1 { font-size: 20px; }
        .nav { display: flex; background: white; border-bottom: 1px solid #e0e0e0; }
        .nav button { padding: 12px 24px; border: none; background: none; cursor: pointer; font-size: 14px; }
        .nav button.active { border-bottom: 2px solid #1976d2; color: #1976d2; }
        .container { max-width: 1200px; margin: 0 auto; padding: 16px; }
        .card { background: white; border-radius: 12px; padding: 16px; margin-bottom: 16px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px; }
        .status-item { text-align: center; padding: 20px; }
        .status-item .number { font-size: 36px; font-weight: bold; }
        .status-item .label { color: #666; margin-top: 8px; }
        .progress-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
        .progress-item { padding: 16px; border-radius: 8px; text-align: center; font-size: 14px; }
        .progress-item.green { background: #e8f5e9; color: #2e7d32; }
        .progress-item.blue { background: #e3f2fd; color: #1565c0; }
        .progress-item.red { background: #ffebee; color: #c62828; }
        .account-list { list-style: none; }
        .account-item { display: flex; align-items: center; padding: 12px; border-bottom: 1px solid #f0f0f0; }
        .account-info { flex: 1; }
        .account-info .name { font-weight: 500; }
        .account-info .status { font-size: 12px; color: #666; }
        .badge { padding: 4px 8px; border-radius: 12px; font-size: 12px; }
        .badge.completed { background: #e8f5e9; color: #2e7d32; }
        .badge.error { background: #ffebee; color: #c62828; }
        .badge.incomplete { background: #fff3e0; color: #e65100; }
        .btn { padding: 8px 16px; border: none; border-radius: 8px; cursor: pointer; font-size: 14px; }
        .btn-primary { background: #1976d2; color: white; }
        .form-group { margin-bottom: 16px; }
        .form-group label { display: block; margin-bottom: 4px; font-weight: 500; }
        .form-group input { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        .modal { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 100; }
        .modal.active { display: flex; align-items: center; justify-content: center; }
        .modal-content { background: white; border-radius: 12px; padding: 24px; width: 90%; max-width: 500px; }
        .login-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.7); z-index: 200; display: flex; align-items: center; justify-content: center; }
        .login-box { background: white; border-radius: 12px; padding: 32px; width: 90%; max-width: 360px; text-align: center; }
        .login-box h2 { margin-bottom: 8px; }
        .login-box p { color: #666; font-size: 13px; margin-bottom: 20px; }
        .login-box input { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 8px; margin-bottom: 12px; font-size: 14px; }
        .login-error { color: #c62828; font-size: 12px; margin-bottom: 8px; display: none; }
    </style>
</head>
<body>
    <div class="login-overlay" id="login-overlay">
        <div class="login-box">
            <h2>ZonewApp</h2>
            <p>请输入访问令牌以继续<br>（在 App 设置 → Web 服务中查看）</p>
            <div class="login-error" id="login-error">令牌无效，请重试</div>
            <input type="password" id="token-input" placeholder="访问令牌" onkeydown="if(event.key==='Enter')doLogin()">
            <button class="btn btn-primary" style="width:100%;padding:12px" onclick="doLogin()">登录</button>
        </div>
    </div>
    <div class="header">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="white"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
        <h1>ZonewApp Web Control</h1>
    </div>
    <div class="nav">
        <button class="active" onclick="showPage('home',this)">主页</button>
        <button onclick="showPage('account',this)">账号</button>
    </div>
    <div class="container">
        <div id="home-page">
            <div class="status-grid">
                <div class="card status-item"><div class="number" id="total">0</div><div class="label">总账号</div></div>
                <div class="card status-item"><div class="number" id="completed" style="color:#2e7d32">0</div><div class="label">已完成</div></div>
                <div class="card status-item"><div class="number" id="incomplete" style="color:#e65100">0</div><div class="label">未完成</div></div>
                <div class="card status-item"><div class="number" id="error" style="color:#c62828">0</div><div class="label">状态异常</div></div>
            </div>
            <div class="card"><h3 style="margin-bottom:16px">项目进度</h3><div class="progress-grid" id="progress"></div></div>
        </div>
        <div id="account-page" style="display:none">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px">
                <h2>账号管理</h2>
                <button class="btn btn-primary" onclick="showAdd()">+ 添加账号</button>
            </div>
            <div class="card"><ul class="account-list" id="accounts"></ul></div>
        </div>
    </div>
    <div class="modal" id="modal">
        <div class="modal-content" style="max-height:90vh;overflow-y:auto">
            <h3 style="margin-bottom:16px">添加账号</h3>
            <div class="form-group"><label>账号</label><input type="text" id="u" placeholder="请输入账号"></div>
            <div class="form-group"><label>密码</label><input type="password" id="p" placeholder="请输入密码"></div>
            <div class="form-group"><label>班主任姓名</label><input type="text" id="t" placeholder="请输入班主任姓名"></div>
            <div class="form-group">
                <label>选科（选择3项）</label>
                <div id="subjects-wrap" style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px"></div>
                <div id="subjects-error" style="color:#c62828;font-size:12px;margin-top:4px;display:none">请选择3个科目</div>
            </div>
            <div class="form-group">
                <label style="display:flex;justify-content:space-between;align-items:center">任职情况 <button class="btn" style="padding:4px 12px;font-size:12px" onclick="addPosition()">+ 添加</button></label>
                <ul id="positions-list" style="list-style:none;padding:0;margin-top:8px"></ul>
            </div>
            <div class="form-group">
                <label style="display:flex;justify-content:space-between;align-items:center">奖惩情况 <button class="btn" style="padding:4px 12px;font-size:12px" onclick="addReward()">+ 添加</button></label>
                <ul id="rewards-list" style="list-style:none;padding:0;margin-top:8px"></ul>
            </div>
            <div style="display:flex;gap:8px;justify-content:flex-end;margin-top:16px">
                <button class="btn" onclick="closeModal()">取消</button>
                <button class="btn btn-primary" onclick="addAcc()">添加</button>
            </div>
        </div>
    </div>
    <div class="modal" id="pos-modal">
        <div class="modal-content">
            <h3 style="margin-bottom:16px">添加任职</h3>
            <div class="form-group"><label>职务</label><input type="text" id="pos-title" placeholder="如：班长、课代表"></div>
            <div class="form-group"><label>职务描述</label><textarea id="pos-desc" rows="3" style="width:100%;padding:8px;border:1px solid #ddd;border-radius:4px" placeholder="描述你的职责"></textarea></div>
            <div style="display:flex;gap:8px;justify-content:flex-end">
                <button class="btn" onclick="closePosModal()">取消</button>
                <button class="btn btn-primary" onclick="confirmPos()">添加</button>
            </div>
        </div>
    </div>
    <div class="modal" id="rew-modal">
        <div class="modal-content">
            <h3 style="margin-bottom:16px">添加奖惩</h3>
            <div class="form-group"><label>奖惩名称</label><input type="text" id="rew-title" placeholder="如：三好学生"></div>
            <div class="form-group">
                <label>奖励等级</label>
                <select id="rew-level" style="width:100%;padding:8px;border:1px solid #ddd;border-radius:4px">
                    <option value="校级_学校">校级_学校</option>
                    <option value="县级_行政部门">县级_行政部门</option>
                    <option value="市级_行政部门">市级_行政部门</option>
                    <option value="省级_行政部门">省级_行政部门</option>
                    <option value="国家级_行政部门">国家级_行政部门</option>
                </select>
            </div>
            <div style="display:flex;gap:8px;justify-content:flex-end">
                <button class="btn" onclick="closeRewModal()">取消</button>
                <button class="btn btn-primary" onclick="confirmRew()">添加</button>
            </div>
        </div>
    </div>
    <script>
        var TOKEN = '';
        var selectedSubjects = [];
        var positions = [];
        var rewards = [];
        var SUBJECTS = ['物理','化学','生物','政治','历史','地理'];
        function authHeaders(){
            return TOKEN ? {'Authorization': 'Bearer ' + TOKEN, 'Content-Type': 'application/json'} : {'Content-Type': 'application/json'};
        }
        function doLogin(){
            var input = document.getElementById('token-input').value.trim();
            if(!input) return;
            TOKEN = input;
            // Test the token by fetching status
            fetch('/api/status', {headers: authHeaders()}).then(function(r){
                if(r.ok){
                    document.getElementById('login-overlay').style.display = 'none';
                    sessionStorage.setItem('zwa_token', TOKEN);
                    load();
                } else {
                    document.getElementById('login-error').style.display = 'block';
                    TOKEN = '';
                }
            }).catch(function(){
                document.getElementById('login-error').style.display = 'block';
                TOKEN = '';
            });
        }
        // Auto-login from session storage
        (function(){
            var saved = sessionStorage.getItem('zwa_token');
            if(saved){ TOKEN = saved; doLogin(); }
        })();
        function showPage(p,btn){
            document.getElementById('home-page').style.display=p==='home'?'block':'none';
            document.getElementById('account-page').style.display=p==='account'?'block':'none';
            document.querySelectorAll('.nav button').forEach(function(b){b.classList.remove('active')});
            btn.classList.add('active');load();
        }
        async function load(){
            try{
                var s=await(await fetch('/api/status',{headers:authHeaders()})).json();
                if(s.success){var d=s.data;
                    document.getElementById('total').textContent=d.total_accounts;
                    document.getElementById('completed').textContent=d.completed;
                    document.getElementById('incomplete').textContent=d.incomplete;
                    document.getElementById('error').textContent=d.error;
                }
                var a=await(await fetch('/api/accounts',{headers:authHeaders()})).json();
                if(a.success)render(a.data);
            }catch(e){console.error(e)}
        }
        function render(accs){
            var list=document.getElementById('accounts');
            list.innerHTML=accs.map(function(a){
                var c=a.status==='已完成'?'completed':a.status==='状态异常'?'error':'incomplete';
                return '<li class="account-item"><div class="account-info"><div class="name">'+a.username+'</div><div class="status">班主任: '+a.teacher_name+' | 选科: '+(a.subjects||[]).join('/')+'</div></div><span class="badge '+c+'">'+a.status+'</span></li>';
            }).join('');
            var items=['材料排序','任职情况','奖惩情况','体育锻炼','心理素质','陈述报告','党团活动','志愿服务','艺术素养','劳动实践','课题研究','项目设计'];
            document.getElementById('progress').innerHTML=items.map(function(n,i){
                var s=accs.length>0?(i<4?'green':i<8?'blue':'red'):'red';
                return '<div class="progress-item '+s+'">'+n+'</div>';
            }).join('');
        }
        function renderSubjects(){
            var wrap=document.getElementById('subjects-wrap');
            wrap.innerHTML=SUBJECTS.map(function(s){
                var sel=selectedSubjects.indexOf(s)>=0;
                return '<label style="display:inline-flex;align-items:center;gap:4px;padding:6px 12px;border:1px solid '+(sel?'#1976d2':'#ddd')+';border-radius:16px;cursor:pointer;background:'+(sel?'#e3f2fd':'white')+';color:'+(sel?'#1976d2':'#333')+';font-size:13px"><input type="checkbox" value="'+s+'" '+(sel?'checked':'')+' onchange="toggleSubject(this)" style="display:none">'+s+'</label>';
            }).join('');
        }
        function toggleSubject(cb){
            var v=cb.value;
            var i=selectedSubjects.indexOf(v);
            if(i>=0){selectedSubjects.splice(i,1)}
            else if(selectedSubjects.length<3){selectedSubjects.push(v)}
            renderSubjects();
        }
        function renderPositions(){
            document.getElementById('positions-list').innerHTML=positions.map(function(p,i){
                return '<li style="padding:8px;border-bottom:1px solid #f0f0f0;display:flex;justify-content:space-between;align-items:center"><div><b>'+p.title+'</b><br><span style="font-size:12px;color:#666">'+p.description+'</span></div><button class="btn" style="padding:2px 8px;font-size:12px;color:#c62828" onclick="positions.splice('+i+',1);renderPositions()">删除</button></li>';
            }).join('');
        }
        function renderRewards(){
            document.getElementById('rewards-list').innerHTML=rewards.map(function(r,i){
                return '<li style="padding:8px;border-bottom:1px solid #f0f0f0;display:flex;justify-content:space-between;align-items:center"><div><b>'+r.title+'</b><br><span style="font-size:12px;color:#666">'+r.level+'</span></div><button class="btn" style="padding:2px 8px;font-size:12px;color:#c62828" onclick="rewards.splice('+i+',1);renderRewards()">删除</button></li>';
            }).join('');
        }
        function addPosition(){document.getElementById('pos-modal').classList.add('active')}
        function closePosModal(){document.getElementById('pos-modal').classList.remove('active')}
        function confirmPos(){
            var t=document.getElementById('pos-title').value;
            var d=document.getElementById('pos-desc').value;
            if(t){positions.push({id:crypto.randomUUID(),title:t,description:d});renderPositions()}
            document.getElementById('pos-title').value='';document.getElementById('pos-desc').value='';
            closePosModal();
        }
        function addReward(){document.getElementById('rew-modal').classList.add('active')}
        function closeRewModal(){document.getElementById('rew-modal').classList.remove('active')}
        function confirmRew(){
            var t=document.getElementById('rew-title').value;
            var l=document.getElementById('rew-level').value;
            if(t){rewards.push({id:crypto.randomUUID(),title:t,level:l,department:l,imagePath:null});renderRewards()}
            document.getElementById('rew-title').value='';
            closeRewModal();
        }
        function showAdd(){
            selectedSubjects=[];positions=[];rewards=[];
            document.getElementById('u').value='';document.getElementById('p').value='';document.getElementById('t').value='';
            renderSubjects();renderPositions();renderRewards();
            document.getElementById('subjects-error').style.display='none';
            document.getElementById('modal').classList.add('active');
        }
        function closeModal(){document.getElementById('modal').classList.remove('active')}
        async function addAcc(){
            if(selectedSubjects.length!==3){document.getElementById('subjects-error').style.display='block';return}
            var a={id:crypto.randomUUID(),username:document.getElementById('u').value,password:document.getElementById('p').value,teacher_name:document.getElementById('t').value,subjects:selectedSubjects,positions:positions,rewards:rewards,status:'未完成',created_at:new Date().toISOString(),updated_at:new Date().toISOString()};
            await fetch('/api/accounts',{method:'POST',headers:authHeaders(),body:JSON.stringify(a)});
            closeModal();load();
        }
    </script>
</body>
</html>
''';
    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  Future<void> _handleAccounts(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    if (request.method == 'GET') {
      final accounts = await StorageService.instance.loadAccounts();
      request.response.write(jsonEncode({
        'success': true,
        'data': accounts.map((a) => a.toJson()).toList(),
      }));
    } else if (request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body);
      final account = Account.fromJson(data);
      await StorageService.instance.addAccount(account);
      request.response.write(jsonEncode({'success': true}));
    } else {
      request.response.statusCode = 405;
    }
    await request.response.close();
  }

  Future<void> _handleAccountById(HttpRequest request, String id) async {
    request.response.headers.contentType = ContentType.json;
    if (request.method == 'DELETE') {
      await StorageService.instance.deleteAccount(id);
      request.response.write(jsonEncode({'success': true}));
    } else {
      request.response.statusCode = 405;
    }
    await request.response.close();
  }

  Future<void> _handleStatus(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    final accounts = await StorageService.instance.loadAccounts();
    final total = accounts.length;
    final completed = accounts.where((a) => a.status == '已完成').length;
    final err = accounts.where((a) => a.status == '状态异常').length;
    request.response.write(jsonEncode({
      'success': true,
      'data': {
        'total_accounts': total,
        'completed': completed,
        'incomplete': total - completed - err,
        'error': err,
      },
    }));
    await request.response.close();
  }

  Future<void> _handleSettings(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    if (request.method == 'GET') {
      final settings = await StorageService.instance.loadSettings();
      request.response.write(jsonEncode({
        'success': true,
        'data': settings.toJson(),
      }));
    } else {
      request.response.statusCode = 405;
    }
    await request.response.close();
  }
}

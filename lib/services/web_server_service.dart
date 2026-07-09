import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../services/storage_service.dart';
import '../models/account.dart';

class _WsClient {
  final Socket socket;
  _WsClient(this.socket);
}

class WebServerService {
  static final WebServerService instance = WebServerService._();
  WebServerService._();

  HttpServer? _server;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start({int port = 35535}) async {
    if (_isRunning) return;

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _isRunning = true;

    debugPrint('Web server running on http://…:$port');
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          });
        }

        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
        });
      };
    };
  }

  Future<Response> _handleRequest(Request request) async {
    final path = request.url.path;

    switch (path) {
      case '':
      case 'index.html':
        return _serveIndex();
      case 'api/accounts':
        return await _handleAccounts(request);
      case 'api/status':
        return await _handleStatus();
      case 'api/settings':
        return await _handleSettings(request);
      case 'api/poll':
        return await _handleStatus(); // Simple polling endpoint
      default:
        if (path.startsWith('api/accounts/')) {
          final id = path.replaceFirst('api/accounts/', '');
          return await _handleAccountById(request, id);
        }
        return Response.notFound('Not found');
    }
  }

  Response _serveIndex() {
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
        .account-item:last-child { border-bottom: none; }
        .account-info { flex: 1; }
        .account-info .name { font-weight: 500; }
        .account-info .status { font-size: 12px; color: #666; }
        .badge { padding: 4px 8px; border-radius: 12px; font-size: 12px; }
        .badge.incomplete { background: #fff3e0; color: #e65100; }
        .badge.completed { background: #e8f5e9; color: #2e7d32; }
        .badge.error { background: #ffebee; color: #c62828; }
        .btn { padding: 8px 16px; border: none; border-radius: 8px; cursor: pointer; font-size: 14px; }
        .btn-primary { background: #1976d2; color: white; }
        .form-group { margin-bottom: 16px; }
        .form-group label { display: block; margin-bottom: 4px; font-weight: 500; }
        .form-group input { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        .modal { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 100; }
        .modal.active { display: flex; align-items: center; justify-content: center; }
        .modal-content { background: white; border-radius: 12px; padding: 24px; width: 90%; max-width: 500px; max-height: 80vh; overflow-y: auto; }
    </style>
</head>
<body>
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
                <div class="card status-item">
                    <div class="number" id="total-accounts">0</div>
                    <div class="label">总账号</div>
                </div>
                <div class="card status-item">
                    <div class="number" id="completed-accounts" style="color:#2e7d32">0</div>
                    <div class="label">已完成</div>
                </div>
                <div class="card status-item">
                    <div class="number" id="incomplete-accounts" style="color:#e65100">0</div>
                    <div class="label">未完成</div>
                </div>
                <div class="card status-item">
                    <div class="number" id="error-accounts" style="color:#c62828">0</div>
                    <div class="label">状态异常</div>
                </div>
            </div>
            <div class="card">
                <h3 style="margin-bottom:16px">完成进度</h3>
                <div class="progress-grid" id="progress-grid"></div>
            </div>
        </div>
        <div id="account-page" style="display:none">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px">
                <h2>账号管理</h2>
                <button class="btn btn-primary" onclick="showAddAccount()">+ 添加账号</button>
            </div>
            <div class="card">
                <ul class="account-list" id="account-list"></ul>
            </div>
        </div>
    </div>
    <div class="modal" id="add-modal">
        <div class="modal-content">
            <h3 style="margin-bottom:16px">添加账号</h3>
            <div class="form-group">
                <label>账号</label>
                <input type="text" id="input-username" placeholder="请输入账号">
            </div>
            <div class="form-group">
                <label>密码</label>
                <input type="password" id="input-password" placeholder="请输入密码">
            </div>
            <div class="form-group">
                <label>班主任姓名</label>
                <input type="text" id="input-teacher" placeholder="请输入班主任姓名">
            </div>
            <div style="display:flex;gap:8px;justify-content:flex-end">
                <button class="btn" onclick="closeModal()">取消</button>
                <button class="btn btn-primary" onclick="addAccount()">添加</button>
            </div>
        </div>
    </div>
    <script>
        function showPage(page, btn) {
            document.getElementById('home-page').style.display = page === 'home' ? 'block' : 'none';
            document.getElementById('account-page').style.display = page === 'account' ? 'block' : 'none';
            document.querySelectorAll('.nav button').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            loadData();
        }

        async function loadData() {
            try {
                const status = await (await fetch('/api/status')).json();
                if (status.success) {
                    const d = status.data;
                    document.getElementById('total-accounts').textContent = d.total_accounts;
                    document.getElementById('completed-accounts').textContent = d.completed;
                    document.getElementById('incomplete-accounts').textContent = d.incomplete;
                    document.getElementById('error-accounts').textContent = d.error;
                }

                const accounts = await (await fetch('/api/accounts')).json();
                if (accounts.success) renderAccounts(accounts.data);
            } catch(e) { console.error(e); }
        }

        function renderAccounts(accounts) {
            const list = document.getElementById('account-list');
            list.innerHTML = accounts.map(function(a) {
                var cls = a.status === '已完成' ? 'completed' : a.status === '状态异常' ? 'error' : 'incomplete';
                return '<li class="account-item"><div class="account-info"><div class="name">' + a.username + '</div><div class="status">班主任: ' + a.teacher_name + ' | 创建: ' + a.created_at.split('T')[0] + '</div></div><span class="badge ' + cls + '">' + a.status + '</span></li>';
            }).join('');

            var grid = document.getElementById('progress-grid');
            var items = ['材料排序','任职情况','奖惩情况','体育锻炼','心理素质','陈述报告','党团活动','志愿服务','艺术素养','劳动实践','课题研究','项目设计'];
            grid.innerHTML = items.map(function(name, i) {
                var s = accounts.length > 0 ? (i < 4 ? 'green' : i < 8 ? 'blue' : 'red') : 'red';
                return '<div class="progress-item ' + s + '">' + name + '</div>';
            }).join('');
        }

        function showAddAccount() { document.getElementById('add-modal').classList.add('active'); }
        function closeModal() { document.getElementById('add-modal').classList.remove('active'); }

        async function addAccount() {
            var account = {
                id: crypto.randomUUID(),
                username: document.getElementById('input-username').value,
                password: document.getElementById('input-password').value,
                teacher_name: document.getElementById('input-teacher').value,
                subjects: [], positions: [], rewards: [],
                status: '未完成',
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            };
            await fetch('/api/accounts', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(account) });
            closeModal();
            loadData();
        }

        loadData();
        setInterval(loadData, 30000);
    </script>
</body>
</html>
''';
    return Response.ok(html, headers: {'content-type': 'text/html; charset=utf-8'});
  }

  Future<Response> _handleAccounts(Request request) async {
    if (request.method == 'GET') {
      final accounts = await StorageService.instance.loadAccounts();
      return Response.ok(
        jsonEncode({'success': true, 'data': accounts.map((a) => a.toJson()).toList()}),
        headers: {'content-type': 'application/json'},
      );
    } else if (request.method == 'POST') {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final account = Account.fromJson(data);
      await StorageService.instance.addAccount(account);
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.badRequest();
  }

  Future<Response> _handleAccountById(Request request, String id) async {
    if (request.method == 'DELETE') {
      await StorageService.instance.deleteAccount(id);
      return Response.ok(jsonEncode({'success': true}), headers: {'content-type': 'application/json'});
    }
    return Response.badRequest();
  }

  Future<Response> _handleStatus() async {
    final accounts = await StorageService.instance.loadAccounts();
    final total = accounts.length;
    final completed = accounts.where((a) => a.status == '已完成').length;
    final error = accounts.where((a) => a.status == '状态异常').length;
    final incomplete = total - completed - error;

    return Response.ok(
      jsonEncode({
        'success': true,
        'data': {
          'total_accounts': total,
          'completed': completed,
          'incomplete': incomplete,
          'error': error,
        },
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleSettings(Request request) async {
    if (request.method == 'GET') {
      final settings = await StorageService.instance.loadSettings();
      return Response.ok(
        jsonEncode({'success': true, 'data': settings.toJson()}),
        headers: {'content-type': 'application/json'},
      );
    }
    return Response.badRequest();
  }
}

<?php
session_start();
$valid_password = "首次登录需要密码，在双引号中修改成自己喜欢的";
$storageFile = 'cron_jobs.txt';

// 处理AJAX请求
if (isset($_GET['ajax'])) {
    if (!isset($_SESSION['authenticated']) || !$_SESSION['authenticated']) {
        die('请重新登录');
    }
    $systemJobs = getCronJobs();
    echo '<div id="systemJobsContainer">';
    renderJobTable($systemJobs, 'system');
    echo '</div>';
    exit;
}

// 处理登录
if (isset($_POST['login'])) {
    if ($_POST['password'] === $valid_password) {
        $_SESSION['authenticated'] = true;
    } else {
        $error = "密码错误，请重新输入！";
    }
}

// 检查认证状态
if (!isset($_SESSION['authenticated']) || !$_SESSION['authenticated']) {
    showLoginForm();
    exit;
}

// 处理Cron操作
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    handleCronOperations();
    header("Location: ".$_SERVER['PHP_SELF']);
    exit;
}

showManagementInterface();

// 功能函数
function showLoginForm() {
    global $error;
?>
<!DOCTYPE html>
<html>
<head>
<title>Cron管理登录</title>
<style>
body {font-family: Arial, sans-serif; background: #f0f2f5; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0;}
.login-box {background: white; padding: 2rem; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); width: 300px;}
.form-group {margin-bottom: 1rem;}
input[type="password"] {width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;}
button {background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer;}
.error {color: red; margin-bottom: 1rem;}
</style>
</head>
<body>
<div class="login-box">
<?php if (isset($error)) echo "<div class='error'>$error</div>"; ?>
<form method="post">
<div class="form-group">
<input type="password" name="password" placeholder="请输入管理密码" required>
</div>
<button type="submit" name="login">登录</button>
</form>
</div>
</body>
</html>
<?php
}

function handleCronOperations() {
    global $error;
    if (isset($_POST['add_cron'])) {
        $cronCommand = trim($_POST['cronCommand']);
        $timeInterval = (int)$_POST['timeInterval'];
        if (!empty($cronCommand)) {
            addCronJob($timeInterval, $cronCommand);
        }
    }
    elseif (isset($_POST['add_full_cron'])) {
        $fullCommand = trim($_POST['full_cron_command']);
        if (validateCronCommand($fullCommand)) {
            addFullCronJob($fullCommand);
        } else {
            $error = "Cron命令格式无效，请检查时间格式！";
        }
    }
    elseif (isset($_POST['delete_system'])) {
        $cronLine = urldecode($_POST['cron_line']);
        deleteCronJob($cronLine);
    }
    elseif (isset($_POST['delete_pending'])) {
        $cronLine = urldecode($_POST['pending_line']);
        deletePendingJob($cronLine);
    }
    elseif (isset($_POST['force_sync'])) {
        syncCronJobs();
    }
}

function syncCronJobs() {
    global $storageFile;
    if (!file_exists($storageFile)) return;
    
    exec("crontab -l", $currentCronJobs);
    $currentCronJobs = array_filter($currentCronJobs, function($line) {
        return trim($line) !== '' && !str_starts_with($line, '#');
    });
    
    $storedJobs = file($storageFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    $newJobs = array_diff($storedJobs, $currentCronJobs);
    
    if (!empty($newJobs)) {
        $merged = array_merge($currentCronJobs, $newJobs);
        $tempFile = tempnam(sys_get_temp_dir(), 'cron');
        file_put_contents($tempFile, implode("\n", $merged) . "\n");
        exec("crontab $tempFile", $output, $result);
        unlink($tempFile);
    }
}

function addCronJob($interval, $command) {
    global $storageFile;
    $cronLine = "*/$interval * * * * bash " . escapeshellcmd($command) . " > /dev/null 2>&1";
    
    // 直接写入系统
    exec("(crontab -l; echo " . escapeshellarg($cronLine) . ") | crontab -", $output, $result);
    
    // 记录到存储文件
    $existing = file_exists($storageFile) ? file($storageFile, FILE_IGNORE_NEW_LINES) : [];
    if (!in_array($cronLine, $existing)) {
        file_put_contents($storageFile, $cronLine . PHP_EOL, FILE_APPEND);
    }
}

function addFullCronJob($command) {
    global $storageFile;
    $command = trim($command);
    
    // 直接写入系统
    exec("(crontab -l; echo " . escapeshellarg($command) . ") | crontab -", $output, $result);
    
    // 记录到存储文件
    $existing = file_exists($storageFile) ? file($storageFile, FILE_IGNORE_NEW_LINES) : [];
    if (!in_array($command, $existing)) {
        file_put_contents($storageFile, $command . PHP_EOL, FILE_APPEND);
    }
}

function deleteCronJob($cronLine) {
    exec("crontab -l | grep -v -F " . escapeshellarg($cronLine) . " | crontab -", $output, $result);
    return $result === 0;
}

function deletePendingJob($cronLine) {
    global $storageFile;
    $existing = file_exists($storageFile) ? file($storageFile, FILE_IGNORE_NEW_LINES) : [];
    $existing = array_filter($existing, function($line) use ($cronLine) {
        return trim($line) !== trim($cronLine);
    });
    file_put_contents($storageFile, implode(PHP_EOL, $existing) . PHP_EOL);
}

function getCronJobs() {
    exec("crontab -l", $output);
    return array_filter($output, function($line) {
        return trim($line) !== '' && !str_starts_with($line, '#');
    });
}

function getPendingJobs() {
    global $storageFile;
    if (!file_exists($storageFile)) return [];
    return file($storageFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
}

function validateCronCommand($command) {
    $pattern = '/^((\*(\/\d+)?|\d+([\-\/]\d+)*(,\d+([\-\/]\d+)*)*)\s+){5}(.*)$/';
    return preg_match($pattern, trim($command));
}

function renderJobTable($jobs, $type) {
    if (!empty($jobs)) {
        echo '<table><tbody>';
        foreach ($jobs as $job) {
            $encodedJob = urlencode($job);
            echo "<tr>
                    <td style='font-family: monospace'>".htmlspecialchars($job)."</td>
                    <td>
                        <form method='post' onsubmit='return confirm(\"".($type === 'system' ? '此操作仅删除系统任务' : '确定要移除此任务')."\");'>
                            <input type='hidden' name='".($type === 'system' ? 'cron_line' : 'pending_line')."' value='$encodedJob'>
                            <button type='submit' name='delete_$type' class='delete'>".($type === 'system' ? '删除' : '移除')."</button>
                        </form>
                    </td>
                  </tr>";
        }
        echo '</tbody></table>';
    } else {
        echo '<p>'.($type === 'system' ? '系统当前没有定时任务' : '持久化列表中没有挂起任务').'</p>';
    }
}

function showManagementInterface() {
    global $error, $storageFile;
    $systemJobs = getCronJobs();
    $pendingJobs = getPendingJobs();
    $defaultCommand = '* * * * * /usr/home/yourname/domains/yourdomains/public_html/restart.sh';
?>
<!DOCTYPE html>
<html>
<head>
<title>Cron任务管理</title>
<style>
body {font-family: Arial, sans-serif; background: #f0f2f5; margin: 2rem;}
.container {max-width: 800px; margin: 0 auto;}
.card {background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); margin-bottom: 1.5rem;}
table {width: 100%; border-collapse: collapse; margin-top: 1rem;}
th, td {padding: 12px; text-align: left; border-bottom: 1px solid #ddd;}
.form-group {margin-bottom: 1rem;}
input[type="text"], input[type="number"] {width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;}
button {background: #007bff; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer;}
button.delete {background: #dc3545;}
.command-type-toggle { margin: 15px 0; }
.command-type-btn {
    background: #e9ecef;
    border: 1px solid #dee2e6;
    padding: 8px 15px;
    cursor: pointer;
    transition: all 0.3s;
}
.command-type-btn.active {
    background: #007bff;
    color: white;
    border-color: #007bff;
}
.command-form { display: none; }
.command-form.active { display: block; }
.error-card {
    color: red;
    padding: 15px;
    border: 1px solid #ffcccc;
    border-radius: 4px;
    background: #fff0f0;
}
.list-tabs { margin: 20px 0; }
.tab-btn {
    background: #e9ecef;
    border: 1px solid #dee2e6;
    padding: 10px 20px;
    cursor: pointer;
    transition: all 0.3s;
}
.tab-btn.active {
    background: #28a745;
    color: white;
    border-color: #28a745;
}
.task-list { display: none; }
.task-list.active { display: block; }
.pending-actions, .system-actions {
    margin-top: 15px;
    padding-top: 10px;
    border-top: 1px solid #eee;
}
.refresh-btn {
    background: #28a745;
    color: white;
    padding: 8px 16px;
}
</style>
</head>
<body>
<div class="container">
    <?php if (isset($error)) echo "<div class='card error-card'>$error</div>"; ?>
    <h1>Cron任务管理</h1>
    
    <div class="card">
        <div class="command-type-toggle">
            <button type="button" class="command-type-btn active" onclick="toggleCommandType('basic')">基本模式</button>
            <button type="button" class="command-type-btn" onclick="toggleCommandType('advanced')">专家模式</button>
        </div>

        <form method="post" class="command-form active" id="basicForm">
            <h2>添加新任务</h2>
            <div class="form-group">
                <label>脚本路径：</label>
                <input type="text" name="cronCommand"
                       placeholder="/path/to/your/script.sh"
                       required>
            </div>
            <div class="form-group">
                <label>执行间隔（分钟）：</label>
                <input type="number" name="timeInterval"
                       min="1" max="59" value="15" required>
            </div>
            <button type="submit" name="add_cron">添加任务</button>
        </form>

        <form method="post" class="command-form" id="advancedForm">
            <h2>添加新任务</h2>
            <div class="form-group">
                <label>完整Cron命令：</label>
                <input type="text" name="full_cron_command"
                       value="<?= htmlspecialchars($defaultCommand) ?>"
                       placeholder="*/5 * * * * bash /path/to/script.sh > /dev/null 2>&1"
                       required
                       style="font-family: monospace; width: 100%">
                <small style="color:#666">示例格式：*/间隔 * * * * 命令（间隔范围1-59）</small>
            </div>
            <button type="submit" name="add_full_cron">添加完整命令</button>
        </form>
    </div>

    <div class="card">
        <div class="list-tabs">
            <button type="button" class="tab-btn active" data-tab="system">系统任务列表</button>
            <button type="button" class="tab-btn" data-tab="pending">挂起任务列表</button>
        </div>

        <div class="task-list active" id="systemList">
            <div id="systemJobsContainer">
                <?php renderJobTable($systemJobs, 'system'); ?>
            </div>
            <div class="system-actions">
                <button onclick="refreshSystemJobs()" class="refresh-btn">↻ 刷新列表</button>
            </div>
        </div>

        <div class="task-list" id="pendingList">
            <?php renderJobTable($pendingJobs, 'pending'); ?>
            <div class="pending-actions">
                <form method="post" onsubmit="return confirm('将强制同步所有挂起任务到系统！');">
                    <button type="submit" name="force_sync" style="background: #17a2b8">立即同步到系统</button>
                </form>
            </div>
        </div>
    </div>
</div>

<script>
    // 标签页切换
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            
            const tabId = this.getAttribute('data-tab');
            document.querySelectorAll('.task-list').forEach(list => {
                list.classList.remove('active');
            });
            document.getElementById(tabId + 'List').classList.add('active');
        });
    });

    // 命令类型切换
    function toggleCommandType(type) {
        document.querySelectorAll('.command-form').forEach(form => {
            form.classList.remove('active');
        });
        document.querySelectorAll('.command-type-btn').forEach(btn => {
            btn.classList.remove('active');
        });

        const activeForm = document.getElementById(type === 'basic' ? 'basicForm' : 'advancedForm');
        const activeBtn = document.querySelector(`[onclick="toggleCommandType('${type}')"]`);

        activeForm.classList.add('active');
        activeBtn.classList.add('active');
    }

    // 异步刷新系统任务
    function refreshSystemJobs() {
        const container = document.getElementById('systemJobsContainer');
        container.innerHTML = '<p>正在加载...</p>';
        
        fetch(window.location.href + '?ajax=1')
            .then(response => response.text())
            .then(data => {
                const parser = new DOMParser();
                const doc = parser.parseFromString(data, 'text/html');
                const newContent = doc.getElementById('systemJobsContainer').innerHTML;
                container.innerHTML = newContent;
            })
            .catch(error => {
                container.innerHTML = '<p style="color:red">刷新失败</p>';
            });
    }
</script>
</body>
</html>
<?php
}
?>

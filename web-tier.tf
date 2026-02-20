# =============================================================================
# WEB TIER (Nginx Presentation Layer)
# =============================================================================
# Launch Template + Auto Scaling Group for Nginx web servers.
#
# Notice how ${aws_lb.internal.dns_name} automatically injects the
# Internal ALB DNS into the Nginx config. No more copy-pasting DNS names!
# Terraform resolves dependencies and fills in values at deploy time.
# =============================================================================

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1

    echo "WEB TIER: Starting bootstrap..."

    yum update -y
    yum install -y nginx python3

    cat <<'HTMLEOF' > /usr/share/nginx/html/index.html
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Task Manager | Three-Tier App</title>
        <style>
            *{margin:0;padding:0;box-sizing:border-box}
            body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f0f2f5;min-height:100vh;padding:40px 20px}
            .container{max-width:700px;margin:0 auto}
            .header{background:linear-gradient(135deg,#232f3e,#37475a);color:#fff;padding:30px;border-radius:12px 12px 0 0}
            .header h1{font-size:28px;margin-bottom:8px}
            .header .subtitle{color:#ff9900;font-size:14px;font-weight:600}
            .header .arch{color:#aab7c4;font-size:11px;margin-top:4px}
            .instance-info{background:#37475a;color:#aab7c4;padding:10px 30px;font-size:12px;font-family:monospace;display:flex;gap:24px;flex-wrap:wrap}
            .add-section{background:#fff;padding:20px 30px;display:flex;gap:12px;border-bottom:1px solid #e8e8e8}
            .add-section input{flex:1;padding:12px 16px;border:2px solid #e0e0e0;border-radius:8px;font-size:16px;transition:border-color .2s}
            .add-section input:focus{outline:none;border-color:#ff9900}
            .add-section button{padding:12px 24px;background:#ff9900;color:#fff;border:none;border-radius:8px;font-size:16px;font-weight:600;cursor:pointer;transition:background .2s;white-space:nowrap}
            .add-section button:hover{background:#e68a00}
            .task-list{background:#fff;border-radius:0 0 12px 12px;overflow:hidden}
            .task{padding:16px 30px;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #f0f0f0;transition:background .2s}
            .task:hover{background:#fafafa}
            .task:last-child{border-bottom:none}
            .task.done .task-title{text-decoration:line-through;color:#999}
            .task-left{display:flex;align-items:center;gap:12px}
            .task-status{font-size:20px}
            .task-title{font-size:16px;color:#333}
            .task-time{font-size:12px;color:#aaa;margin-top:2px}
            .task-actions{display:flex;gap:8px}
            .btn{padding:6px 14px;border:none;border-radius:6px;font-size:13px;font-weight:600;cursor:pointer;transition:opacity .2s}
            .btn:hover{opacity:.85}
            .btn-done{background:#d4edda;color:#155724}
            .btn-delete{background:#f8d7da;color:#721c24}
            .empty{text-align:center;padding:60px 20px;color:#999}
            .empty .emoji{font-size:48px;margin-bottom:12px}
            .loading{text-align:center;padding:40px;color:#999}
            .stats{background:#fff;padding:12px 30px;font-size:13px;color:#888;border-bottom:1px solid #f0f0f0}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Task Manager</h1>
                <div class="subtitle">THREE-TIER WEB APPLICATION ON AWS</div>
                <div class="arch">Web Tier (Nginx) → Internal ALB → App Tier (Flask) → RDS MySQL</div>
                <div class="arch" style="margin-top:2px">Deployed with Terraform</div>
            </div>
            <div class="instance-info" id="instanceInfo"><span>Loading instance info...</span></div>
            <div class="add-section">
                <input type="text" id="taskInput" placeholder="What needs to be done?" onkeypress="if(event.key==='Enter')addTask()">
                <button onclick="addTask()">Add Task</button>
            </div>
            <div class="stats" id="stats"></div>
            <div class="task-list" id="taskList"><div class="loading">Loading tasks...</div></div>
        </div>
        <script>
            async function loadInstanceInfo(){
                try{
                    const res=await fetch('/web-info');
                    const d=await res.json();
                    document.getElementById('instanceInfo').innerHTML='<span>Web Instance: '+d.instance_id+'</span><span>Web AZ: '+d.az+'</span>';
                }catch(e){document.getElementById('instanceInfo').innerHTML='<span>Instance info unavailable</span>'}
            }
            async function loadTasks(){
                try{
                    const res=await fetch('/api/tasks');
                    const tasks=await res.json();
                    const el=document.getElementById('taskList');
                    const statsEl=document.getElementById('stats');
                    const pending=tasks.filter(t=>t.status==='pending').length;
                    const done=tasks.filter(t=>t.status==='done').length;
                    statsEl.textContent=tasks.length+' total | '+pending+' pending | '+done+' completed';
                    if(tasks.length===0){el.innerHTML='<div class="empty"><div class="emoji">📋</div><div>No tasks yet!</div></div>';return}
                    el.innerHTML=tasks.map(t=>'<div class="task '+(t.status==='done'?'done':'')+'"><div class="task-left"><span class="task-status">'+(t.status==='done'?'✅':'⏳')+'</span><div><div class="task-title">'+escapeHtml(t.title)+'</div><div class="task-time">'+formatDate(t.created_at)+'</div></div></div><div class="task-actions">'+(t.status!=='done'?'<button class="btn btn-done" onclick="markDone('+t.id+')">Complete</button>':'')+'<button class="btn btn-delete" onclick="deleteTask('+t.id+')">Delete</button></div></div>').join('')
                }catch(e){document.getElementById('taskList').innerHTML='<div class="empty"><div class="emoji">⚠️</div><div>Failed to load tasks. Backend may be starting up.</div></div>'}
            }
            async function addTask(){const i=document.getElementById('taskInput');const t=i.value.trim();if(!t)return;await fetch('/api/tasks',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({title:t})});i.value='';loadTasks()}
            async function markDone(id){await fetch('/api/tasks/'+id,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({status:'done'})});loadTasks()}
            async function deleteTask(id){await fetch('/api/tasks/'+id,{method:'DELETE'});loadTasks()}
            function escapeHtml(t){const d=document.createElement('div');d.textContent=t;return d.innerHTML}
            function formatDate(s){if(!s)return'';const d=new Date(s);return d.toLocaleDateString('en-US',{month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'})}
            loadInstanceInfo();
            loadTasks();
        </script>
    </body>
    </html>
    HTMLEOF

    cat <<NGINXEOF > /etc/nginx/conf.d/app.conf
    server {
        listen 80;
        server_name _;

        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files \$uri \$uri/ /index.html;
        }

        location /web-info {
            proxy_pass http://127.0.0.1:8080/info;
        }

        location /api/ {
            proxy_pass http://${aws_lb.internal.dns_name}/api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_connect_timeout 5s;
            proxy_read_timeout 30s;
        }

        location /health {
            access_log off;
            default_type application/json;
            return 200 '{"status":"healthy","tier":"web"}';
        }
    }
    NGINXEOF

    rm -f /etc/nginx/conf.d/default.conf

    cat <<'PYEOF' > /opt/info-server.py
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import subprocess, json

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            try:
                token = subprocess.check_output(["curl","-s","-X","PUT","http://169.254.169.254/latest/api/token","-H","X-aws-ec2-metadata-token-ttl-seconds: 21600"]).decode().strip()
                iid = subprocess.check_output(["curl","-s","-H","X-aws-ec2-metadata-token: "+token,"http://169.254.169.254/latest/meta-data/instance-id"]).decode().strip()
                az = subprocess.check_output(["curl","-s","-H","X-aws-ec2-metadata-token: "+token,"http://169.254.169.254/latest/meta-data/placement/availability-zone"]).decode().strip()
            except:
                iid, az = "unknown", "unknown"
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"instance_id": iid, "az": az}).encode())
        def log_message(self, format, *args):
            pass

    HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
    PYEOF

    nohup python3 /opt/info-server.py > /dev/null 2>&1 &

    systemctl start nginx
    systemctl enable nginx

    echo "WEB TIER: Bootstrap complete!"
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-web" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for Web Tier
resource "aws_autoscaling_group" "web" {
  name                      = "${var.project_name}-web-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 4
  vpc_zone_identifier       = aws_subnet.web[*].id          # Web private subnets
  target_group_arns         = [aws_lb_target_group.web.arn] # Auto-registers!
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy — scale based on CPU
resource "aws_autoscaling_policy" "web_cpu" {
  name                   = "${var.project_name}-web-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

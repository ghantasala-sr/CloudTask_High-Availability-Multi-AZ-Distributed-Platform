# =============================================================================
# APP TIER (Flask Backend)
# =============================================================================
# Launch Template + Auto Scaling Group for the Flask API servers.
#
# The user_data uses templatefile() — this is Terraform's way of injecting
# variables into a script. The ${db_host} and ${db_pass} placeholders
# get replaced with actual RDS values at deploy time.
#
# This is MUCH better than the manual approach where we had to copy-paste
# the RDS endpoint into sed commands!
# =============================================================================

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # User Data — the bootstrap script that runs on first boot
  # base64encode is required by AWS for launch template user data
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1

    echo "APP TIER: Starting bootstrap..."

    yum update -y
    yum install -y python3 python3-pip gcc mariadb-connector-c-devel python3-devel

    pip3 install flask pymysql gunicorn

    mkdir -p /opt/app

    cat <<'APPEOF' > /opt/app/app.py
    import os
    import pymysql
    from flask import Flask, request, jsonify

    DB_HOST = "${aws_db_instance.main.address}"
    DB_USER = "${var.db_username}"
    DB_PASS = "${var.db_password}"
    DB_NAME = "${var.db_name}"
    DB_PORT = 3306

    app = Flask(__name__)

    def get_db():
        return pymysql.connect(
            host=DB_HOST, user=DB_USER, password=DB_PASS,
            database=DB_NAME, port=DB_PORT,
            cursorclass=pymysql.cursors.DictCursor, connect_timeout=5
        )

    def init_db():
        conn = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASS, port=DB_PORT, connect_timeout=10)
        with conn.cursor() as cur:
            cur.execute("CREATE DATABASE IF NOT EXISTS taskdb")
        conn.close()
        conn = get_db()
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    status VARCHAR(50) DEFAULT 'pending',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
        conn.commit()
        conn.close()

    @app.route("/api/tasks", methods=["GET"])
    def get_tasks():
        conn = get_db()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM tasks ORDER BY created_at DESC")
                tasks = cur.fetchall()
            for t in tasks:
                if t.get("created_at"):
                    t["created_at"] = t["created_at"].strftime("%Y-%m-%d %H:%M:%S")
            return jsonify(tasks)
        except Exception as e:
            return jsonify({"error": str(e)}), 500
        finally:
            conn.close()

    @app.route("/api/tasks", methods=["POST"])
    def create_task():
        data = request.json
        if not data or not data.get("title", "").strip():
            return jsonify({"error": "Title required"}), 400
        title = data["title"].strip()
        conn = get_db()
        try:
            with conn.cursor() as cur:
                cur.execute("INSERT INTO tasks (title) VALUES (%s)", (title,))
                nid = cur.lastrowid
            conn.commit()
            return jsonify({"message": "created", "id": nid}), 201
        except Exception as e:
            conn.rollback()
            return jsonify({"error": str(e)}), 500
        finally:
            conn.close()

    @app.route("/api/tasks/<int:tid>", methods=["PUT"])
    def update_task(tid):
        data = request.json
        if not data or "status" not in data:
            return jsonify({"error": "Status required"}), 400
        conn = get_db()
        try:
            with conn.cursor() as cur:
                cur.execute("UPDATE tasks SET status=%s WHERE id=%s", (data["status"], tid))
                if cur.rowcount == 0:
                    return jsonify({"error": "Not found"}), 404
            conn.commit()
            return jsonify({"message": "updated"})
        except Exception as e:
            conn.rollback()
            return jsonify({"error": str(e)}), 500
        finally:
            conn.close()

    @app.route("/api/tasks/<int:tid>", methods=["DELETE"])
    def delete_task(tid):
        conn = get_db()
        try:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM tasks WHERE id=%s", (tid,))
                if cur.rowcount == 0:
                    return jsonify({"error": "Not found"}), 404
            conn.commit()
            return jsonify({"message": "deleted"})
        except Exception as e:
            conn.rollback()
            return jsonify({"error": str(e)}), 500
        finally:
            conn.close()

    @app.route("/health")
    def health():
        try:
            conn = get_db()
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
            conn.close()
            return jsonify({"status": "healthy", "database": "connected"}), 200
        except Exception as e:
            return jsonify({"status": "unhealthy", "error": str(e)}), 500

    if __name__ == "__main__":
        init_db()
        app.run(host="0.0.0.0", port=5000, debug=True)
    APPEOF

    cd /opt/app
    python3 -c "from app import init_db; init_db()"
    touch /var/log/app.log && chmod 777 /var/log/app.log
    gunicorn -w 2 -b 0.0.0.0:5000 app:app --daemon --log-file /var/log/app.log

    echo "APP TIER: Bootstrap complete!"
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-app" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for App Tier
resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-app-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 4
  vpc_zone_identifier       = aws_subnet.app[*].id          # App private subnets
  target_group_arns         = [aws_lb_target_group.app.arn] # Auto-registers with TG!
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy — scale based on CPU
resource "aws_autoscaling_policy" "app_cpu" {
  name                   = "${var.project_name}-app-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

"""
Agentic SDLC Orchestrator - CLI entry point
"""

import subprocess
import sys
import os
import argparse


def run_spawn(args):
    """Spawn a K8s pod for async task execution."""
    # Find the scripts directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    k8s_scripts_dir = os.path.join(os.path.dirname(script_dir), "k8s")
    spawn_script = os.path.join(k8s_scripts_dir, "spawn-pod.sh")

    if not os.path.exists(spawn_script):
        print(f"Error: spawn-pod.sh not found at {spawn_script}")
        return 1

    # Build command
    cmd = ["bash", spawn_script, args.task_id, args.branch, args.repo, args.context_dir or "."]

    # Add SSH secret if provided
    if args.ssh_secret:
        env = os.environ.copy()
        env["SSH_SECRET_NAME"] = args.ssh_secret
        result = subprocess.run(cmd, env=env)
    else:
        result = subprocess.run(cmd)

    return result.returncode


def run_status(args):
    """Check status of a task pod."""
    cmd = ["kubectl", "get", f"agent-{args.task_id}", "-o", "wide"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout or result.stderr)
    return result.returncode


def run_logs(args):
    """Stream logs from a task pod."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    k8s_scripts_dir = os.path.join(os.path.dirname(script_dir), "k8s")
    tail_script = os.path.join(k8s_scripts_dir, "tail-logs.sh")

    if os.path.exists(tail_script):
        cmd = ["bash", tail_script, f"agent-{args.task_id}"]
    else:
        cmd = ["kubectl", "logs", "-f", f"agent-{args.task_id}"]

    result = subprocess.run(cmd)
    return result.returncode


def run_list(args):
    """List all running agent pods."""
    cmd = ["kubectl", "get", "pods", "-l", "app=agent-orchestrator", "-o", "wide"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout or result.stderr)
    return result.returncode


def main():
    parser = argparse.ArgumentParser(
        description="Agentic SDLC Orchestrator - K8s-based async task execution"
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Spawn command
    spawn_parser = subparsers.add_parser("spawn", help="Spawn a K8s pod for async task")
    spawn_parser.add_argument("--task-id", required=True, help="Task ID")
    spawn_parser.add_argument("--branch", required=True, help="Git branch")
    spawn_parser.add_argument("--repo", required=True, help="Git repository URL")
    spawn_parser.add_argument("--context-dir", help="Context directory")
    spawn_parser.add_argument("--ssh-secret", help="SSH secret name for git auth")

    # Status command
    status_parser = subparsers.add_parser("status", help="Check task status")
    status_parser.add_argument("--task-id", required=True, help="Task ID")

    # Logs command
    logs_parser = subparsers.add_parser("logs", help="Stream task logs")
    logs_parser.add_argument("--task-id", required=True, help="Task ID")

    # List command
    subparsers.add_parser("list", help="List all running pods")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    if args.command == "spawn":
        return run_spawn(args)
    elif args.command == "status":
        return run_status(args)
    elif args.command == "logs":
        return run_logs(args)
    elif args.command == "list":
        return run_list(args)

    return 0


if __name__ == "__main__":
    sys.exit(main())

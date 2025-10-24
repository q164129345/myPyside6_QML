"""
简单的自动重启脚本 - 不需要任何第三方库
定时检查文件修改时间,如有变化则重启程序
"""
import subprocess
import sys
import time
import os
from pathlib import Path


def get_qml_files(directory="."):
    """获取所有 QML 文件"""
    files = {}
    for path in Path(directory).rglob("*.qml"):
        try:
            files[str(path)] = path.stat().st_mtime
        except:
            pass
    return files


def main():
    if len(sys.argv) < 2:
        print("用法: python simple_watch.py <脚本文件>")
        print("例如: python simple_watch.py main.py")
        sys.exit(1)
    
    script = sys.argv[1]
    if not Path(script).exists():
        print(f"❌ 文件不存在: {script}")
        sys.exit(1)
    
    print("╔" + "═"*58 + "╗")
    print("║" + " "*12 + "🔥 简易 QML 自动重载监听器" + " "*13 + "║")
    print("╚" + "═"*58 + "╝")
    print(f"\n📁 监听目录: {Path.cwd()}")
    print(f"🎯 运行脚本: {script}")
    print(f"⏱️  检查间隔: 每 0.5 秒")
    print(f"💡 提示: 修改 QML 文件后程序会自动重启")
    print(f"🛑 停止: 按 Ctrl+C\n")
    
    process = None
    file_times = get_qml_files()
    reload_count = 0
    
    # 首次启动
    print("="*60)
    print(f"🚀 启动程序: {script}")
    print("="*60 + "\n")
    process = subprocess.Popen([sys.executable, script])
    
    try:
        while True:
            time.sleep(0.5)  # 每 0.5 秒检查一次
            
            # 获取当前文件时间
            current_times = get_qml_files()
            
            # 检查是否有文件变化
            changed_files = []
            for file_path, mtime in current_times.items():
                if file_path not in file_times or mtime > file_times[file_path]:
                    changed_files.append(Path(file_path).name)
            
            if changed_files:
                reload_count += 1
                print(f"\n📝 检测到文件变化: {', '.join(changed_files)}")
                
                # 终止旧进程
                if process:
                    print("🛑 停止旧进程...")
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except:
                        process.kill()
                
                # 等待一下确保文件保存完成
                time.sleep(0.3)
                
                # 启动新进程
                print("="*60)
                print(f"🔄 重启程序 (第 {reload_count} 次)")
                print("="*60 + "\n")
                process = subprocess.Popen([sys.executable, script])
                
                # 更新文件时间
                file_times = current_times
    
    except KeyboardInterrupt:
        print("\n\n🛑 正在停止...")
        if process:
            process.terminate()
        print("✅ 已停止")


if __name__ == "__main__":
    main()

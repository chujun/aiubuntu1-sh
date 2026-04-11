#!/usr/bin/env python3
"""
MiniMax 视频生成工具
支持 T2V（图生视频）生成，含任务提交和轮询获取结果
"""

import requests
import time
import json
import os
from pathlib import Path

# ============ 配置区域 ============
API_KEY = os.getenv("MINIMAX_API_KEY", "YOUR_API_KEY_HERE")
API_URL = "https://api.minimaxi.com/v1/video_generation"
STATUS_URL = "https://api.minimaxi.com/v1/video_generation_query"
POLL_INTERVAL = 5  # 轮询间隔（秒）
MAX_POLL_COUNT = 120  # 最大轮询次数（10分钟）


# ============ 核心函数 ============

def generate_video(
    prompt: str,
    model: str = "MiniMax-Hailuo-2.3",
    duration: int = 6,
    resolution: str = "1080P",
    prompt_optimizer: bool = True,
    callback_url: str = None,
) -> dict:
    """
    提交视频生成任务

    Args:
        prompt: 视频描述文本
        model: 模型名称
        duration: 视频时长（6或10秒）
        resolution: 分辨率
        prompt_optimizer: 是否优化提示词
        callback_url: 回调URL（可选）

    Returns:
        包含 task_id 的响应字典
    """
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": model,
        "prompt": prompt,
        "duration": duration,
        "resolution": resolution,
        "prompt_optimizer": prompt_optimizer,
    }

    if callback_url:
        payload["callback_url"] = callback_url

    response = requests.post(API_URL, headers=headers, json=payload, timeout=30)
    response.raise_for_status()
    return response.json()


def query_video_status(task_id: str) -> dict:
    """
    查询视频生成状态

    Args:
        task_id: 任务ID

    Returns:
        状态信息字典
    """
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "task_id": task_id
    }

    response = requests.post(STATUS_URL, headers=headers, json=payload, timeout=30)
    response.raise_for_status()
    return response.json()


def poll_video_result(task_id: str, interval: int = POLL_INTERVAL, max_count: int = MAX_POLL_COUNT) -> dict:
    """
    轮询等待视频生成完成

    Args:
        task_id: 任务ID
        interval: 轮询间隔（秒）
        max_count: 最大轮询次数

    Returns:
        最终状态信息字典
    """
    print(f"[+] 开始轮询任务 {task_id}，间隔 {interval} 秒")

    for i in range(max_count):
        result = query_video_status(task_id)
        status = result.get("status", "")

        print(f"  [{i+1}/{max_count}] 状态: {status}")

        if status == "success":
            print("[+] 视频生成成功!")
            return result
        elif status == "fail":
            print("[!] 视频生成失败!")
            return result
        elif status == "queue":
            print(f"    排队中...")
        elif status == "processing":
            print(f"    生成中...")
        else:
            print(f"    未知状态: {status}")

        time.sleep(interval)

    print("[!] 轮询超时")
    return {"status": "timeout", "task_id": task_id}


def download_video(url: str, output_path: str) -> str:
    """
    下载生成的视频

    Args:
        url: 视频URL
        output_path: 保存路径

    Returns:
        保存后的文件路径
    """
    print(f"[+] 下载视频: {url}")

    response = requests.get(url, stream=True, timeout=300)
    response.raise_for_status()

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "wb") as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

    print(f"[+] 视频已保存: {output_path}")
    return output_path


def generate_video_with_poll(
    prompt: str,
    model: str = "MiniMax-Hailuo-2.3",
    duration: int = 6,
    resolution: str = "1080P",
    output_path: str = "output.mp4",
) -> dict:
    """
    完整流程：提交任务 -> 轮询等待 -> 下载视频

    Args:
        prompt: 视频描述
        model: 模型名称
        duration: 时长
        resolution: 分辨率
        output_path: 输出路径

    Returns:
        最终结果
    """
    # 1. 提交任务
    print("[*] 提交视频生成任务...")
    submit_result = generate_video(prompt, model, duration, resolution)
    print(f"[+] 任务已提交: {json.dumps(submit_result, indent=2, ensure_ascii=False)}")

    task_id = submit_result.get("task_id")
    if not task_id:
        print("[!] 获取 task_id 失败")
        return submit_result

    # 2. 轮询结果
    final_result = poll_video_result(task_id)

    # 3. 下载视频
    if final_result.get("status") == "success":
        video_url = final_result.get("video", {}).get("url")
        if video_url:
            download_video(video_url, output_path)
            final_result["output_path"] = output_path

    return final_result


# ============ 主程序 ============

if __name__ == "__main__":
    # 检查 API Key
    if not API_KEY or API_KEY == "YOUR_API_KEY_HERE":
        print("[!] 请设置 MINIMAX_API_KEY 环境变量或修改脚本中的 API_KEY")
        print("    export MINIMAX_API_KEY='your_api_key_here'")
        exit(1)

    # 你的提示词（中文）
    prompt = """
    一位身着白色唐代长袍的中年男子，束发高冠，腰佩长剑，手持酒壶，气质飘逸洒脱，
    站在黄山光明顶巨大的花岗岩峰顶之上。

    脚下翻涌着绵延的云海，远处奇松怪石若隐若现，金色阳光从云层缝隙中倾泻而下，
    照亮峰顶的岩石和男子飘动的衣袂。

    男子缓缓举起酒壶仰头畅饮，长袍衣袂随山风轻轻飘动，云海在脚下缓慢翻涌流动。

    镜头从男子身后低角度缓慢推进，逐渐上升至与人物平齐，
    最终呈现人物与壮阔云海山景的全景画面。

    中国古典水墨画风格，电影质感，暖金色调，逆光剪影效果，
    4K超高清，浅景深，胶片颗粒感。
    """.strip()

    print("=" * 60)
    print("MiniMax 视频生成工具")
    print("=" * 60)

    # 执行生成 - 尝试 T2V-01 模型（支持更多订阅计划）
    result = generate_video_with_poll(
        prompt=prompt,
        model="T2V-01",
        duration=6,
        resolution="720P",
        output_path="output/huangshan_tang_man.mp4"
    )

    print("\n" + "=" * 60)
    print("最终结果:")
    print(json.dumps(result, indent=2, ensure_ascii=False))

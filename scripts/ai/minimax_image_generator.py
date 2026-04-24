#!/usr/bin/env python3
"""
MiniMax 文生图工具
参考: https://platform.minimaxi.com/docs/api-reference/image-generation-t2i
"""

import requests
import json
import os
import base64
from pathlib import Path

API_KEY = os.getenv("MINIMAX_API_KEY")
API_URL = "https://api.minimaxi.com/v1/image_generation"

# 提示词（中文，1500字符内）
prompt = """身着白色唐代长袍的中年男子，束发高冠，腰佩长剑，手持酒壶，气质飘逸洒脱，站在黄山光明顶花岗岩峰顶。脚下云海翻涌，远处奇松怪石若隐若现，金色阳光从云层缝隙倾泻而下，照亮峰顶岩石和飘动的衣袂。男子缓缓举壶畅饮，长袍随山风轻飘，云海在脚下缓慢流动。中国古典水墨画风格，电影质感，暖金色调，逆光剪影效果，4K超高清。"""

# aspect_ratio 选项: 1:1, 16:9, 9:16, 4:3, 3:4, 21:9
aspect_ratio = "16:9"


def generate_image(prompt: str, model: str = "image-01", aspect_ratio: str = "16:9", n: int = 1) -> dict:
    """生成图片"""
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": model,
        "prompt": prompt,
        "aspect_ratio": aspect_ratio,
        "n": n,
        "prompt_optimizer": True,
        "response_format": "url"  # url 或 base64
    }

    response = requests.post(API_URL, headers=headers, json=payload, timeout=180)
    return response.json()


def save_image_from_url(url: str, output_path: str) -> str:
    """从URL下载并保存图片"""
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(response.content)
    print(f"[+] 图片已保存: {output_path}")
    return output_path


def save_image_from_base64(base64_str: str, output_path: str) -> str:
    """保存base64编码的图片"""
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    img_data = base64.b64decode(base64_str)
    with open(output_path, "wb") as f:
        f.write(img_data)
    print(f"[+] 图片已保存: {output_path}")
    return output_path


if __name__ == "__main__":
    if not API_KEY:
        print("[!] 请设置 MINIMAX_API_KEY 环境变量")
        print("    export MINIMAX_API_KEY='your_api_key_here'")
        exit(1)

    print("=" * 60)
    print("MiniMax 文生图工具")
    print("=" * 60)
    print(f"[*] 提示词: {prompt[:50]}...")
    print(f"[*] 比例: {aspect_ratio}")
    print()

    result = generate_image(prompt, aspect_ratio=aspect_ratio)
    print("[+] 响应:")
    print(json.dumps(result, indent=2, ensure_ascii=False))

    # 处理响应
    if "data" in result and result["data"]:
        image_urls = result["data"].get("image_urls", [])
        for i, url in enumerate(image_urls):
            output_path = f"output/image_{i+1}.png"
            save_image_from_url(url, output_path)
        if not image_urls:
            print("[!] 未找到图片URL")

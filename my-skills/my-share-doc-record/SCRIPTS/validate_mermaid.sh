#!/usr/bin/env python3
# Mermaid 语法验证脚本
# 优先使用 mermaid-cli 做真正语法解析，不可用时回退到 Python 静态检查
# 用法：bash SCRIPTS/validate_mermaid.sh <文件路径>

import re, sys, subprocess, tempfile, os

fpath = sys.argv[1]
with open(fpath) as f:
    content = f.read()

blocks = re.findall(r'\`\`\`mermaid\n(.*?)\n\`\`\`', content, re.DOTALL)
if not blocks:
    print('未找到 Mermaid 图表')
    sys.exit(1)

print(f'发现 {len(blocks)} 个 Mermaid 图表')

# 检测 mermaid-cli 是否可用
use_mmdc = False
try:
    r = subprocess.run(['npx', '--yes', '@mermaid-js/mermaid-cli', '--version'],
                       capture_output=True, text=True, timeout=120)
    if r.returncode == 0:
        use_mmdc = True
        print(f'✅ 使用 mermaid-cli ({r.stdout.strip()}) 进行语法验证')
except Exception as e:
    print(f'⚠️ mermaid-cli 检查失败: {e}')

# 浏览器可用性检测（创建测试图表）
if use_mmdc:
    test_mmd = "graph TD\n    A[Test] --> B[OK]"
    with tempfile.NamedTemporaryFile(mode='w', suffix='.mmd', delete=False) as tmp:
        tmp.write(test_mmd)
        test_path = tmp.name
    test_out = test_path + '.svg'
    try:
        r = subprocess.run(
            ['npx', '--yes', '@mermaid-js/mermaid-cli', '-i', test_path, '-o', test_out, '--quiet'],
            capture_output=True, text=True, timeout=60
        )
        if r.returncode != 0 and ('Failed to launch' in (r.stderr or '') or 'Failed to launch' in (r.stdout or '')):
            print('⚠️ mermaid-cli 浏览器环境不可用，切换到 Python 静态检查')
            use_mmdc = False
    except Exception:
        use_mmdc = False
    finally:
        os.unlink(test_path)
        if os.path.exists(test_out):
            os.unlink(test_out)

if not use_mmdc:
    print('ℹ️ mermaid-cli 不可用，使用 Python 静态检查（回退模式）')

errors = []
for idx, block in enumerate(blocks, 1):
    lines = block.strip().split('\n')
    first = lines[0]

    if use_mmdc:
        # mermaid-cli 真实语法验证
        with tempfile.NamedTemporaryFile(mode='w', suffix='.mmd', delete=False) as tmp:
            tmp.write(block)
            tmp_path = tmp.name
        out_path = tmp_path + '.svg'
        try:
            r = subprocess.run(
                ['npx', '--yes', '@mermaid-js/mermaid-cli', '-i', tmp_path, '-o', out_path, '--quiet'],
                capture_output=True, text=True, timeout=120
            )
            if r.returncode != 0:
                err_msg = (r.stderr or r.stdout or '').strip()
                # 检测浏览器启动失败，切换到 Python 静态检查
                if 'Failed to launch the browser process' in err_msg or 'Failed to launch' in err_msg:
                    print('⚠️ mermaid-cli 浏览器环境不可用，切换到 Python 静态检查')
                    use_mmdc = False
                    break
                err_lines = [l for l in err_msg.split('\n') if 'error' in l.lower() or 'parse' in l.lower()]
                short_err = err_lines[0][:120] if err_lines else err_msg[:120]
                errors.append(f'图表 #{idx}: {short_err}')
        except subprocess.TimeoutExpired:
            errors.append(f'图表 #{idx}: mermaid-cli 验证超时')
        finally:
            os.unlink(tmp_path)
            if os.path.exists(out_path):
                os.unlink(out_path)
    else:
        # Python 静态检查（回退模式）
        if '<br/>' in first:
            errors.append(f'图表 #{idx}: <br/> 在关键字行: {first[:60]}')
            continue
        if len(lines) == 1:
            errors.append(f'图表 #{idx}: 关键字行无后续内容')
            continue
        stripped = first.rstrip()
        if re.search(r'[A-Z]\[|[A-Z]\(|[A-Z]\{|\|[\-]>', stripped):
            errors.append(f'图表 #{idx}: 关键字与节点写在同一行: {stripped[:60]}')
        for line in lines:
            if re.search(r'\[.*\\[\'\"]\s*.*\]', line):
                errors.append(f'图表 #{idx}: 节点文本含转义字符: {line[:60]}')
        for line in lines:
            if line.strip().startswith('%%'):
                continue
            open_sq = line.count('[') - line.count(']')
            open_rd = line.count('(') - line.count(')')
            if abs(open_sq) > 1:
                errors.append(f'图表 #{idx}: 方括号可能未闭合: {line[:60]}')
            if abs(open_rd) > 1:
                errors.append(f'图表 #{idx}: 圆括号可能未闭合: {line[:60]}')

if errors:
    for e in errors:
        print(f'❌ {e}')
    sys.exit(1)
else:
    print(f'✅ 全部 {len(blocks)} 个图表语法正确')

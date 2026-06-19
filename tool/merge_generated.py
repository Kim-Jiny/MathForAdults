#!/usr/bin/env python3
"""워크플로우 결과(검증 통과 문제)를 기존 과목 JSON에 병합한다."""
import json, sys, os

OUT = sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/claude-501/-Users-jiny-Documents-Jiny-MathForAdults/d016703f-587b-4b4d-8996-db1585e39575/tasks/wannj8g86.output'
BASE = 'assets/problems'

data = json.loads(open(OUT).read())['result']['bySlug']

DIFFS = {'개념 확인','기본 유형','대표 유형','응용 유형','수능 기초','수능 실전'}

def norm(q): return ''.join(q.split())

for slug, gen in data.items():
    path = f'{BASE}/{slug}.json'
    existing = json.load(open(path)) if os.path.exists(path) else []
    existing_ids = {p['id'] for p in existing}
    seen_q = {norm(p['question']) for p in existing}

    added = []
    n = 0
    for p in gen:
        # 안전 검증
        ch = p.get('choices')
        if not isinstance(ch, list) or len(ch) != 4: continue
        ai = p.get('answerIndex')
        if not isinstance(ai, int) or ai < 0 or ai > 3: continue
        if p.get('difficulty') not in DIFFS: continue
        if not p.get('question','').strip() or not p.get('explanation','').strip(): continue
        qn = norm(p['question'])
        if qn in seen_q: continue  # 중복 문제 제거
        seen_q.add(qn)
        n += 1
        pid = f'gen_{slug}_{n}'
        while pid in existing_ids:
            n += 1; pid = f'gen_{slug}_{n}'
        existing_ids.add(pid)
        added.append({
            'id': pid,
            'subject': p['subject'], 'chapter': p['chapter'], 'lesson': p['lesson'],
            'difficulty': p['difficulty'], 'question': p['question'],
            'choices': ch, 'answerIndex': ai,
            'explanation': p['explanation'],
            'detailedExplanation': p.get('detailedExplanation'),
            'estimatedTime': p.get('estimatedTime') or '2분',
        })

    merged = existing + added
    with open(path, 'w') as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)
    print(f'{slug}: 기존 {len(existing)} + 추가 {len(added)} = {len(merged)}')

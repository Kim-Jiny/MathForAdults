#!/usr/bin/env python3
"""/tmp/mfa_gen/*.json (검증 통과 문제)을 과목 JSON에 병합한다. hints 포함."""
import json, glob, os

SRC = '/tmp/mfa_gen'
BASE = 'assets/problems'
DIFFS = {'개념 확인', '기본 유형', '대표 유형', '응용 유형', '수능 기초', '수능 실전'}


def norm(q):
    return ''.join(str(q).split())


# slug별로 모으기
by_slug = {}
for f in sorted(glob.glob(f'{SRC}/*.json')):
    for p in json.load(open(f)):
        by_slug.setdefault(p['slug'], []).append(p)

grand = 0
for slug, gen in by_slug.items():
    path = f'{BASE}/{slug}.json'
    existing = json.load(open(path)) if os.path.exists(path) else []
    existing_ids = {p['id'] for p in existing}
    seen_q = {norm(p['question']) for p in existing}

    added = []
    n = 0
    skipped = 0
    for p in gen:
        ch = p.get('choices')
        if not isinstance(ch, list) or len(ch) != 4:
            skipped += 1; continue
        if len({norm(c) for c in ch}) != 4:  # 보기 중복 금지
            skipped += 1; continue
        ai = p.get('answerIndex')
        if not isinstance(ai, int) or ai < 0 or ai > 3:
            skipped += 1; continue
        if p.get('difficulty') not in DIFFS:
            skipped += 1; continue
        if not str(p.get('question', '')).strip() or not str(p.get('explanation', '')).strip():
            skipped += 1; continue
        qn = norm(p['question'])
        if qn in seen_q:
            skipped += 1; continue
        seen_q.add(qn)
        n += 1
        pid = f'gen_{slug}_{n}'
        while pid in existing_ids:
            n += 1; pid = f'gen_{slug}_{n}'
        existing_ids.add(pid)
        rec = {
            'id': pid,
            'subject': p['subject'], 'chapter': p['chapter'], 'lesson': p['lesson'],
            'difficulty': p['difficulty'], 'question': p['question'],
            'choices': ch, 'answerIndex': ai,
            'explanation': p['explanation'],
            'detailedExplanation': p.get('detailedExplanation'),
            'estimatedTime': p.get('estimatedTime') or '2분',
        }
        hints = p.get('hints')
        if isinstance(hints, list) and hints:
            rec['hints'] = [str(h) for h in hints if str(h).strip()]
        added.append(rec)

    merged = existing + added
    with open(path, 'w') as fp:
        json.dump(merged, fp, ensure_ascii=False, indent=2)
    grand += len(added)
    print(f'{slug:10}: 기존 {len(existing):4} + 추가 {len(added):4} (스킵 {skipped}) = {len(merged)}')

print(f'\n총 추가: {grand}문제')
